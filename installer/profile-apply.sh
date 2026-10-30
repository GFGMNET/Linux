#!/usr/bin/env bash
# profile-apply.sh — installs the software defined by one or more profiles.
#
# Runs on the INSTALLED system (the installer calls it inside arch-chroot).
# After installation it is available as:   sudo profile-apply <profile>...
#
#   profile-apply ai games        install the AI and Games profiles (+ _base)
#   profile-apply --list          show available profiles
#   profile-apply --update        update everything (pacman, AUR, Flatpak)
#   profile-apply --pull          get the newest profiles from the Git repository
#   profile-apply --dry-run ai    show what would be installed, change nothing
#
# Per profile folder (all files optional, see profiles/_template):
#   profile.conf            NAME, DESCRIPTION, NEEDS_MULTILIB=yes|no
#   packages.txt            official Arch packages (pacman)
#   packages.nvidia.txt     extra packages only when an NVIDIA GPU is present
#   packages.amd.txt        ... AMD GPU
#   packages.intel.txt      ... Intel GPU
#   aur.txt                 AUR packages (built with paru)
#   flatpak.txt             Flathub app IDs
#   services.txt            systemd services to enable
#   setup.sh                your own commands, run last as root

set -uo pipefail

SELF=$(readlink -f "${BASH_SOURCE[0]}")
LIB_DIR=$(dirname "$SELF")
AP_ROOT=$(dirname "$LIB_DIR")
PROFILES_DIR=${AP_PROFILES_DIR:-$AP_ROOT/profiles}
STATE_DIR=/var/lib/archprofiles
LOG_DIR=/var/log/archprofiles
BUILD_USER=ap-aurbuild
FLATHUB_URL=https://dl.flathub.org/repo/flathub.flatpakrepo

# shellcheck source=common.sh
source "$LIB_DIR/common.sh"

DRY_RUN=0
IN_CHROOT=0
declare -a FAILED=()

run() {
  if (( DRY_RUN )); then printf '   [dry-run] %s\n' "$*"; return 0; fi
  "$@"
}

usage() { sed -n '2,25p' "$SELF" | sed 's/^# \{0,1\}//'; }

# ---------------------------------------------------------------- pacman ----
enable_multilib() {
  if grep -q '^\[multilib\]' /etc/pacman.conf 2>/dev/null; then return 0; fi
  ap_log "Enabling the [multilib] repository (32-bit libraries)"
  run sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
}

# Only keep names pacman actually knows, so one typo can't break the install.
filter_known_packages() {
  local pkg
  for pkg in "$@"; do
    if pacman -Si -- "$pkg" &>/dev/null || pacman -Sg -- "$pkg" &>/dev/null; then
      printf '%s\n' "$pkg"
    else
      ap_warn "Package '$pkg' not found in the Arch repositories — skipped (typo, or is it an AUR package?)"
      FAILED+=("pacman:$pkg (not found)")
    fi
  done
}

install_pacman() {
  local -a pkgs=("$@") known=()
  (( ${#pkgs[@]} )) || return 0
  ap_log "Installing ${#pkgs[@]} package(s) with pacman"
  if (( DRY_RUN )); then printf '   [dry-run] pacman -S --needed %s\n' "${pkgs[*]}"; return 0; fi
  mapfile -t known < <(filter_known_packages "${pkgs[@]}")
  (( ${#known[@]} )) || return 0
  if ! pacman -S --needed --noconfirm -- "${known[@]}"; then
    ap_warn "Batch install failed — retrying one by one to isolate the problem"
    local pkg
    for pkg in "${known[@]}"; do
      pacman -S --needed --noconfirm -- "$pkg" || FAILED+=("pacman:$pkg")
    done
  fi
}

# ------------------------------------------------------------------- AUR ----
aur_prepare() {
  id "$BUILD_USER" &>/dev/null || run useradd --system --create-home --home-dir "/var/lib/$BUILD_USER" "$BUILD_USER"
  run install -Dm440 /dev/stdin "/etc/sudoers.d/90-$BUILD_USER" <<<"$BUILD_USER ALL=(ALL) NOPASSWD: /usr/bin/pacman"
  if ! command -v paru &>/dev/null; then
    ap_log "Building the AUR helper 'paru'"
    run pacman -S --needed --noconfirm base-devel git
    run sudo -u "$BUILD_USER" bash -c '
      set -e
      rm -rf /tmp/paru-bin && git clone --depth 1 https://aur.archlinux.org/paru-bin.git /tmp/paru-bin
      cd /tmp/paru-bin && makepkg -si --noconfirm
      rm -rf /tmp/paru-bin' || { FAILED+=("aur:paru"); return 1; }
  fi
}

aur_cleanup() {
  run rm -f "/etc/sudoers.d/90-$BUILD_USER"
}

install_aur() {
  local -a pkgs=("$@")
  (( ${#pkgs[@]} )) || return 0
  ap_log "Installing ${#pkgs[@]} AUR package(s): ${pkgs[*]}"
  aur_prepare || { aur_cleanup; return 0; }
  local pkg
  for pkg in "${pkgs[@]}"; do
    run sudo -u "$BUILD_USER" paru -S --needed --noconfirm --skipreview -- "$pkg" || FAILED+=("aur:$pkg")
  done
  aur_cleanup
}

# --------------------------------------------------------------- Flatpak ----
install_flatpak() {
  local -a apps=("$@")
  (( ${#apps[@]} )) || return 0
  ap_log "Installing ${#apps[@]} Flatpak app(s) from Flathub"
  command -v flatpak &>/dev/null || run pacman -S --needed --noconfirm flatpak
  run flatpak remote-add --system --if-not-exists flathub "$FLATHUB_URL" || true
  local app
  local -a pending=()
  for app in "${apps[@]}"; do
    if ! run flatpak install --system --noninteractive -y flathub "$app"; then
      if (( IN_CHROOT )); then pending+=("$app"); else FAILED+=("flatpak:$app"); fi
    fi
  done
  # Some Flatpaks refuse to install inside a chroot. Those are retried
  # automatically in the background on the first real boot.
  if (( ${#pending[@]} )); then
    ap_warn "Will retry on first boot: ${pending[*]}"
    run mkdir -p "$STATE_DIR"
    (( DRY_RUN )) || printf '%s\n' "${pending[@]}" >> "$STATE_DIR/pending-flatpak.txt"
    run install -Dm644 "$LIB_DIR/archprofiles-firstboot.service" /etc/systemd/system/archprofiles-firstboot.service
    run systemctl enable archprofiles-firstboot.service
  fi
}

# --------------------------------------------------------------- services ---
enable_services() {
  local svc
  for svc in "$@"; do
    ap_log "Enabling service $svc"
    run systemctl enable "$svc" || FAILED+=("service:$svc")
  done
}

# ------------------------------------------------------------------ main ----
apply_profiles() {
  local -a profiles=("$@") pac=() aur=() flat=() svc=() vendors=()
  local p dir v multilib=0

  mapfile -t vendors < <(ap_gpu_vendors)
  ap_log "Detected GPU vendor(s): ${vendors[*]:-none}"

  for p in "${profiles[@]}"; do
    dir=$PROFILES_DIR/$p
    [[ -d $dir ]] || { ap_err "Profile '$p' not found in $PROFILES_DIR"; FAILED+=("profile:$p"); continue; }
    ap_log "Profile: $p — $(ap_conf_get "$dir/profile.conf" DESCRIPTION "")"
    ap_is_yes "$(ap_conf_get "$dir/profile.conf" NEEDS_MULTILIB no)" && multilib=1
    mapfile -t -O "${#pac[@]}"  pac  < <(ap_read_list "$dir/packages.txt")
    for v in "${vendors[@]}"; do
      mapfile -t -O "${#pac[@]}" pac < <(ap_read_list "$dir/packages.$v.txt")
    done
    mapfile -t -O "${#aur[@]}"  aur  < <(ap_read_list "$dir/aur.txt")
    mapfile -t -O "${#flat[@]}" flat < <(ap_read_list "$dir/flatpak.txt")
    mapfile -t -O "${#svc[@]}"  svc  < <(ap_read_list "$dir/services.txt")
  done

  # de-duplicate, keep order
  dedup() { awk '!seen[$0]++'; }
  mapfile -t pac  < <(printf '%s\n' "${pac[@]}"  | dedup | sed '/^$/d')
  mapfile -t aur  < <(printf '%s\n' "${aur[@]}"  | dedup | sed '/^$/d')
  mapfile -t flat < <(printf '%s\n' "${flat[@]}" | dedup | sed '/^$/d')
  mapfile -t svc  < <(printf '%s\n' "${svc[@]}"  | dedup | sed '/^$/d')

  (( multilib )) && enable_multilib
  ap_log "Refreshing package databases"
  run pacman -Syu --noconfirm || FAILED+=("pacman:-Syu")

  install_pacman  "${pac[@]}"
  install_aur     "${aur[@]}"
  install_flatpak "${flat[@]}"
  enable_services "${svc[@]}"

  for p in "${profiles[@]}"; do
    dir=$PROFILES_DIR/$p
    if [[ -f $dir/setup.sh ]]; then
      ap_log "Running $p/setup.sh"
      if (( DRY_RUN )); then echo "   [dry-run] bash $dir/setup.sh"
      else
        AP_PROFILE=$p AP_GPU_VENDORS="${vendors[*]}" AP_IN_CHROOT=$IN_CHROOT \
          bash "$dir/setup.sh" || FAILED+=("setup:$p")
      fi
    fi
  done

  if (( ! DRY_RUN )); then
    mkdir -p "$STATE_DIR"
    printf '%s\n' "${profiles[@]}" >> "$STATE_DIR/applied-profiles.txt"
    sort -u -o "$STATE_DIR/applied-profiles.txt" "$STATE_DIR/applied-profiles.txt"
  fi
}

do_update() {
  ap_log "Updating official packages"
  run pacman -Syu --noconfirm || FAILED+=("pacman:-Syu")
  if command -v paru &>/dev/null && id "$BUILD_USER" &>/dev/null; then
    ap_log "Updating AUR packages"
    run install -Dm440 /dev/stdin "/etc/sudoers.d/90-$BUILD_USER" <<<"$BUILD_USER ALL=(ALL) NOPASSWD: /usr/bin/pacman"
    run sudo -u "$BUILD_USER" paru -Sua --noconfirm --skipreview || FAILED+=("aur:update")
    aur_cleanup
  fi
  if command -v flatpak &>/dev/null; then
    ap_log "Updating Flatpak apps"
    run flatpak update --system -y --noninteractive || FAILED+=("flatpak:update")
  fi
}

do_pull() {
  [[ -d $AP_ROOT/.git ]] || { ap_err "$AP_ROOT is not a Git checkout."; FAILED+=("pull"); return; }
  ap_log "Getting the newest profiles from $(git -C "$AP_ROOT" remote get-url origin 2>/dev/null)"
  # shallow clone from the installer: fetch and hard-reset to the branch
  local branch
  branch=$(git -C "$AP_ROOT" rev-parse --abbrev-ref HEAD)
  if run git -C "$AP_ROOT" fetch --depth 1 origin "$branch" && run git -C "$AP_ROOT" reset --hard FETCH_HEAD; then
    chmod +x "$LIB_DIR"/*.sh
    ap_ok "Now at $(git -C "$AP_ROOT" rev-parse --short HEAD)"
  else
    ap_warn "Pull failed (private repository? then pull with your own credentials)."
    FAILED+=("pull")
  fi
}

do_firstboot() {
  local pending_file=$STATE_DIR/pending-flatpak.txt
  [[ -s $pending_file ]] || { systemctl disable archprofiles-firstboot.service; return 0; }
  for _ in $(seq 1 180); do                       # wait up to 30 min for network
    ping -c1 -W3 dl.flathub.org &>/dev/null && break
    sleep 10
  done
  local -a apps
  mapfile -t apps < <(ap_read_list "$pending_file")
  flatpak remote-add --system --if-not-exists flathub "$FLATHUB_URL" || true
  local app left=()
  for app in "${apps[@]}"; do
    flatpak install --system --noninteractive -y flathub "$app" || left+=("$app")
  done
  if (( ${#left[@]} )); then
    printf '%s\n' "${left[@]}" > "$pending_file"       # try again next boot
    ap_warn "Still pending: ${left[*]}"
  else
    rm -f "$pending_file"
    systemctl disable archprofiles-firstboot.service
  fi
}

main() {
  local -a orig_args=("$@") profiles=()
  local mode=apply with_base=1
  while (( $# )); do
    case $1 in
      --dry-run)   DRY_RUN=1 ;;
      --chroot)    IN_CHROOT=1 ;;
      --no-base)   with_base=0 ;;
      --list)      mode=list ;;
      --update)    mode=update ;;
      --pull)      mode=pull ;;
      --firstboot) mode=firstboot ;;
      -h|--help)   usage; exit 0 ;;
      -*)          ap_err "Unknown option $1"; usage; exit 2 ;;
      *)           profiles+=("${1//,/ }") ;;
    esac
    shift
  done
  # allow "ai,games" as well as "ai games"
  # shellcheck disable=SC2206
  profiles=(${profiles[*]-})

  if [[ $mode == list ]]; then
    local p
    for p in $(ap_list_profiles "$PROFILES_DIR"); do
      printf '  %-12s %s\n' "$p" "$(ap_conf_get "$PROFILES_DIR/$p/profile.conf" DESCRIPTION "")"
    done
    exit 0
  fi

  if (( ! DRY_RUN )) && [[ $EUID -ne 0 ]]; then
    exec sudo "$SELF" "${orig_args[@]}"
  fi

  if (( ! DRY_RUN )); then
    mkdir -p "$LOG_DIR"
    exec > >(tee -a "$LOG_DIR/profile-apply.log") 2>&1
  fi
  ap_log "profile-apply started $(date '+%F %T')"

  case $mode in
    update)    do_update ;;
    pull)      do_pull ;;
    firstboot) do_firstboot; exit 0 ;;
    apply)
      (( ${#profiles[@]} )) || { ap_err "No profile given."; usage; exit 2; }
      (( with_base )) && profiles=(_base "${profiles[@]/_base/}")
      # shellcheck disable=SC2206
      profiles=(${profiles[*]})
      apply_profiles "${profiles[@]}"
      ;;
  esac

  if (( ${#FAILED[@]} )); then
    ap_warn "Finished with ${#FAILED[@]} problem(s):"
    printf '     - %s\n' "${FAILED[@]}" >&2
    (( DRY_RUN )) || printf '%s\n' "${FAILED[@]}" > "$LOG_DIR/last-problems.txt"
  else
    ap_ok "All done without problems."
    (( DRY_RUN )) || rm -f "$LOG_DIR/last-problems.txt"
  fi
  exit 0     # never fail the whole install because of one package
}

main "$@"
