#!/usr/bin/env bash
# install.sh - fully unattended Arch Linux installation.
#
# Started by the starter script on the USB stick (autoinstall.sh), after it
# downloaded this repository. It:
#   1. shows the profile list (or uses PROFILE= from settings.conf)
#   2. picks the first internal disk and ERASES it
#   3. installs Arch + KDE Plasma + bootloader
#   4. installs the profile software (profile-apply.sh inside the new system)
#   5. reboots into the finished system (the stick is no longer needed)
#
# Settings: settings.conf on the stick (path in $AP_SETTINGS)
# Profiles: profiles/<name>/ in this repository

set -Eeuo pipefail

AP_SRC=${1:-$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")}
SETTINGS=${AP_SETTINGS:-/run/archiso/bootmnt/archprofiles/settings.conf}
PROFILES_DIR=$AP_SRC/profiles
LOG=/tmp/archprofiles-install.log
MNT=/mnt

# shellcheck source=common.sh
source "$AP_SRC/installer/common.sh"

exec > >(tee -a "$LOG") 2>&1

on_error() {
  local line=$1
  echo
  ap_err "Installation stopped (install.sh line $line)."
  ap_err "Full log: $LOG"
  echo "  The target disk may be partly written. Fix the problem (settings.conf,"
  echo "  network, profile files) and boot the stick again to start over."
  echo "  You are now in the live system shell."
  exit 1
}
trap 'on_error $LINENO' ERR

conf() { ap_conf_get "$SETTINGS" "$1" "${2-}"; }

# ------------------------------------------------------------- settings ----
TARGET_DISK=$(conf TARGET_DISK auto)
CONFIRM_SECONDS=$(conf CONFIRM_SECONDS 15)
USERNAME=$(conf USERNAME user)
FULLNAME=$(conf FULLNAME User)
PASSWORD=$(conf PASSWORD changeme)
AUTOLOGIN=$(conf AUTOLOGIN no)
LOCALE=$(conf LOCALE en_US.UTF-8)
KEYMAP=$(conf KEYMAP us)
TIMEZONE=$(conf TIMEZONE UTC)
MIRROR_COUNTRY=$(conf MIRROR_COUNTRY "")
HOSTNAME_T=$(conf HOSTNAME 'arch-{profile}')
PROFILE_SETTING=$(conf PROFILE "")
DESKTOP=$(conf DESKTOP kde)
KERNEL=$(conf KERNEL linux)
WIFI_SSID=$(conf WIFI_SSID "")
WIFI_PASSWORD=$(conf WIFI_PASSWORD "")
FINISH_ACTION=$(conf FINISH_ACTION reboot)

banner() {
  clear || true
  printf '\e[1;36m'
  echo '  =============================================='
  echo '     Arch Linux profile installer'
  echo '  =============================================='
  printf '\e[0m\n'
}

# ------------------------------------------------------------- profiles ----
profiles_from_cmdline() {
  local word
  for word in $(</proc/cmdline); do
    [[ $word == archprofile=* ]] && { printf '%s\n' "${word#archprofile=}" | tr ',+' '  '; return; }
  done
}

# Arrow-key menu on the console.  Up/Down move, Space marks several,
# Enter installs the marked profiles (or the highlighted one).
choose_profiles_menu() {
  local -a all desc marked
  mapfile -t all < <(ap_list_profiles "$PROFILES_DIR")
  (( ${#all[@]} )) || { ap_err "No profiles found in the repository (profiles/)."; return 1; }
  local i n=${#all[@]} cur=0 key rest
  for i in "${!all[@]}"; do
    desc[i]=$(ap_conf_get "$PROFILES_DIR/${all[$i]}/profile.conf" DESCRIPTION "")
    marked[i]=0
  done
  local tty=/dev/tty
  printf '\e[?25l' >"$tty"
  while true; do
    {
      printf '\e[H\e[2J'
      printf '\e[1;36m  Choose a profile\e[0m   (Up/Down move, Space mark several, Enter install)\n\n'
      for i in "${!all[@]}"; do
        local box="   "; (( marked[i] )) && box="[x]"
        if (( i == cur )); then printf '\e[7m'; fi
        printf '  %s %-12s %s\e[0m\n' "$box" "${all[$i]}" "${desc[$i]}"
      done
      printf '\n  Repository: %s (%s, %s)\n' "${AP_REPO_URL:-?}" "${AP_REPO_BRANCH:-?}" "${AP_REPO_COMMIT:-?}"
    } >"$tty"
    IFS= read -rsn1 key <"$tty"
    if [[ $key == $'\e' ]]; then
      read -rsn2 -t 0.1 rest <"$tty" || true
      case $rest in
        '[A') cur=$(( (cur - 1 + n) % n )) ;;
        '[B') cur=$(( (cur + 1) % n )) ;;
      esac
    elif [[ $key == ' ' ]]; then
      marked[cur]=$(( 1 - marked[cur] ))
    elif [[ -z $key ]]; then           # Enter
      break
    elif [[ $key == [kK] ]]; then cur=$(( (cur - 1 + n) % n ))
    elif [[ $key == [jJ] ]]; then cur=$(( (cur + 1) % n ))
    fi
  done
  printf '\e[?25h\e[H\e[2J' >"$tty"
  local any=0
  for i in "${!all[@]}"; do (( marked[i] )) && { printf '%s\n' "${all[$i]}"; any=1; }; done
  (( any )) || printf '%s\n' "${all[$cur]}"
}

# ----------------------------------------------------------------- disk ----
boot_disk() {
  local src
  src=$(findmnt -no SOURCE /run/archiso/bootmnt 2>/dev/null || true)
  [[ -n $src ]] && lsblk -npo PKNAME "$src" 2>/dev/null | head -n1
}

find_target_disk() {
  local bootdev line NAME TYPE RM TRAN SIZE MODEL rank
  bootdev=$(boot_disk)
  while IFS= read -r line; do
    NAME='' TYPE='' RM='' TRAN='' SIZE=0 MODEL=''
    eval "$line"
    [[ $TYPE == disk ]]                 || continue
    [[ $RM == 0 ]]                      || continue
    [[ $TRAN != usb ]]                  || continue
    [[ $NAME != "$bootdev" ]]           || continue
    [[ $NAME =~ /dev/(loop|zram|sr|ram) ]] && continue
    [[ $NAME =~ boot[0-9]+$|rpmb$ ]]    && continue
    (( SIZE >= 20000000000 ))           || continue      # >= 20 GB
    case $NAME in
      /dev/nvme*)   rank=1 ;;
      /dev/sd*|/dev/hd*) rank=2 ;;
      /dev/vd*)     rank=3 ;;
      *)            rank=4 ;;
    esac
    printf '%s %s %s\n' "$rank" "$NAME" "$((SIZE/1000000000))GB ${MODEL:-}"
  done < <(lsblk -dnbpP -o NAME,TYPE,RM,TRAN,SIZE,MODEL) | sort -k1,1n -k2,2V
}

part() {  # part /dev/nvme0n1 1 -> /dev/nvme0n1p1 ; part /dev/sda 1 -> /dev/sda1
  if [[ $1 =~ [0-9]$ ]]; then printf '%sp%s' "$1" "$2"; else printf '%s%s' "$1" "$2"; fi
}

countdown() {
  local secs=$1 key
  (( secs > 0 )) || return 0
  echo
  while (( secs > 0 )); do
    printf '\r\e[1;31m  Starting in %2d s - press any key to CANCEL \e[0m' "$secs"
    if read -rsn1 -t 1 key </dev/tty; then
      echo; ap_warn "Cancelled by keypress. Nothing was changed."; exit 1
    fi
    secs=$((secs-1))
  done
  printf '\r%60s\r' ''
}

# -------------------------------------------------------------- network ----
connect_network() {
  ap_log "Checking internet connection"
  local i
  for i in $(seq 1 30); do
    if ping -c1 -W2 archlinux.org &>/dev/null; then ap_ok "Online."; return 0; fi
    sleep 2
  done
  ap_err "No internet connection. Plug in a network cable, or set WIFI_SSID / WIFI_PASSWORD in settings.conf."
  return 1
}

# -------------------------------------------------------------- desktop ----
desktop_packages() {
  case ${1,,} in
    kde)   echo "plasma-meta sddm konsole dolphin kate ark spectacle gwenview okular" ;;
    gnome) echo "gnome gdm" ;;
    xfce)  echo "xfce4 xfce4-goodies lightdm lightdm-gtk-greeter network-manager-applet" ;;
    none|"") echo "" ;;
    *) ap_warn "Unknown DESKTOP '$1' - installing without desktop"; echo "" ;;
  esac
}
display_manager() {
  case ${1,,} in kde) echo sddm ;; gnome) echo gdm ;; xfce) echo lightdm ;; *) echo "" ;; esac
}

# ================================================================= main ====
banner
loadkeys "$KEYMAP" 2>/dev/null || true

[[ -d /sys/firmware/efi ]] || { ap_err "This PC was not started in UEFI mode. Enable UEFI (disable CSM/Legacy) in the firmware setup."; false; }

mapfile -t PROFILES < <(profiles_from_cmdline | tr ' ' '\n' | sed '/^$/d')
if (( ${#PROFILES[@]} == 0 )) && [[ -n $PROFILE_SETTING ]]; then
  mapfile -t PROFILES < <(printf '%s\n' "$PROFILE_SETTING" | tr ', ' '\n\n' | sed '/^$/d')
fi
if (( ${#PROFILES[@]} == 0 )) || [[ ${PROFILES[0]} == menu ]]; then
  mapfile -t PROFILES < <(choose_profiles_menu)
fi
for p in "${PROFILES[@]}"; do
  [[ -d $PROFILES_DIR/$p ]] || { ap_err "Profile '$p' does not exist on the stick."; false; }
  # a profile may pick its own desktop
  d=$(ap_conf_get "$PROFILES_DIR/$p/profile.conf" DESKTOP "")
  [[ -n $d ]] && DESKTOP=$d
done

# --- choose disk
CANDIDATES=()
if [[ $TARGET_DISK == auto ]]; then
  mapfile -t CANDIDATES < <(find_target_disk)
  (( ${#CANDIDATES[@]} )) || { ap_err "No internal disk (>= 20 GB) found."; false; }
  read -r _ DISK DISK_INFO <<<"${CANDIDATES[0]}"
else
  DISK=$TARGET_DISK
  [[ -b $DISK ]] || { ap_err "TARGET_DISK=$DISK does not exist."; false; }
  [[ $DISK != "$(boot_disk)" ]] || { ap_err "TARGET_DISK is the installer stick itself."; false; }
  DISK_INFO=$(lsblk -dno SIZE,MODEL "$DISK" | xargs)
fi

PROFILE_TAG=$(IFS=-; echo "${PROFILES[*]}")
HOSTNAME=${HOSTNAME_T//\{profile\}/$PROFILE_TAG}
# {mac} = last 4 characters of the network card address (same after a reinstall)
MAC4=$( (cat /sys/class/net/*/address 2>/dev/null || true) | grep -v '^00:00:00:00:00:00$' | head -n1 | tr -d ':\n' | tail -c 4 || true)
# {serial} = PC serial number (last 8 characters); falls back to {mac} if the PC has none
SERIAL=$( (cat /sys/class/dmi/id/product_serial 2>/dev/null || true) | tr -cd '[:alnum:]' | tr '[:upper:]' '[:lower:]' | tail -c 8 || true)
case $SERIAL in ''|*default*|*oem*|*filled*|0*) SERIAL=$MAC4 ;; esac
# {random} = 4 random characters, new on every install
RAND4=$(tr -dc 'a-z0-9' </dev/urandom | head -c 4 || true)
HOSTNAME=${HOSTNAME//\{mac\}/$MAC4}
HOSTNAME=${HOSTNAME//\{serial\}/$SERIAL}
HOSTNAME=${HOSTNAME//\{random\}/$RAND4}
# make it a valid hostname: lowercase, digits, '-', max 63 characters
HOSTNAME=$(printf '%s' "$HOSTNAME" | tr '[:upper:]_' '[:lower:]-' | tr -cd 'a-z0-9-' | cut -c1-63)

echo
printf '  Profile(s): \e[1m%s\e[0m\n' "${PROFILES[*]}"
printf '  Desktop:    %s    Kernel: %s\n' "$DESKTOP" "$KERNEL"
printf '  User:       %s    Hostname: %s\n' "$USERNAME" "$HOSTNAME"
printf '  Target:     \e[1;31m%s (%s) - ALL DATA ON IT WILL BE ERASED\e[0m\n' "$DISK" "$DISK_INFO"
if (( ${#CANDIDATES[@]} > 1 )); then
  echo "  (other internal disks are left untouched:"
  printf '     %s\n' "${CANDIDATES[@]:1}"
  echo "  )"
fi
countdown "$CONFIRM_SECONDS"

# --- prepare live system
ap_log "Waiting for the live system to finish starting"
systemctl is-system-running --wait &>/dev/null || true
connect_network
timedatectl set-ntp true || true
if [[ -n $MIRROR_COUNTRY ]]; then
  ap_log "Selecting fast mirrors in $MIRROR_COUNTRY"
  timeout 90 reflector --country "$MIRROR_COUNTRY" --protocol https --latest 10 \
    --sort rate --save /etc/pacman.d/mirrorlist || ap_warn "reflector failed - using default mirrors"
fi
ap_log "Updating the package signing keys"
pacman -Sy --noconfirm --needed archlinux-keyring

# --- partition + format
ap_log "Partitioning $DISK"
umount -R "$MNT" 2>/dev/null || true
swapoff -a || true
wipefs -af "$DISK"
sgdisk --zap-all "$DISK"
sgdisk -n1:0:+1G -t1:ef00 -c1:EFI \
       -n2:0:0   -t2:8304 -c2:archroot "$DISK"
partprobe "$DISK" || true
udevadm settle
ESP=$(part "$DISK" 1)
ROOT=$(part "$DISK" 2)
mkfs.fat -F32 -n EFI "$ESP"
mkfs.ext4 -F -L archroot "$ROOT"
mount "$ROOT" "$MNT"
mount --mkdir -o umask=0077 "$ESP" "$MNT/boot"

# --- base system
UCODE=""
grep -q GenuineIntel /proc/cpuinfo && UCODE=intel-ucode
grep -q AuthenticAMD /proc/cpuinfo && UCODE=amd-ucode
# shellcheck disable=SC2207,SC2206
BASE_PKGS=(base "$KERNEL" "${KERNEL}-headers" linux-firmware $UCODE
  sudo networkmanager efibootmgr zram-generator
  pipewire pipewire-pulse pipewire-alsa wireplumber
  nano vim man-db bash-completion git base-devel flatpak
  $(desktop_packages "$DESKTOP"))
ap_log "Installing the base system (${#BASE_PKGS[@]} packages) - this takes a while"
pacstrap -K "$MNT" "${BASE_PKGS[@]}"
genfstab -U "$MNT" >> "$MNT/etc/fstab"

# --- configure system
ROOT_UUID=$(blkid -s UUID -o value "$ROOT")
DM=$(display_manager "$DESKTOP")
XKB_LAYOUT=${KEYMAP%%-*}

ap_log "Configuring the new system"
{
  printf 'set -e\n'
  printf 'USERNAME=%q FULLNAME=%q PASSWORD=%q LOCALE=%q KEYMAP=%q TIMEZONE=%q\n' \
    "$USERNAME" "$FULLNAME" "$PASSWORD" "$LOCALE" "$KEYMAP" "$TIMEZONE"
  printf 'HOSTNAME=%q KERNEL=%q ROOT_UUID=%q DM=%q AUTOLOGIN=%q XKB_LAYOUT=%q DESKTOP=%q\n' \
    "$HOSTNAME" "$KERNEL" "$ROOT_UUID" "$DM" "$AUTOLOGIN" "$XKB_LAYOUT" "${DESKTOP,,}"
  printf 'WIFI_SSID=%q WIFI_PASSWORD=%q\n' "$WIFI_SSID" "$WIFI_PASSWORD"
  cat <<'CHROOT'
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
hwclock --systohc
sed -i "s/^#\(${LOCALE//./\\.} \)/\1/; s/^#\(en_US\.UTF-8 \)/\1/" /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf
mkdir -p /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/00-keyboard.conf <<EOF
Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "$XKB_LAYOUT"
EndSection
EOF
echo "$HOSTNAME" > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1 localhost
::1       localhost
127.0.1.1 $HOSTNAME
EOF

useradd -m -G wheel -c "$FULLNAME" -s /bin/bash "$USERNAME"
printf '%s:%s\n' "$USERNAME" "$PASSWORD" | chpasswd
passwd -l root
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/10-wheel
chmod 440 /etc/sudoers.d/10-wheel

printf '[zram0]\nzram-size = min(ram / 2, 8192)\n' > /etc/systemd/zram-generator.conf
systemctl enable NetworkManager.service fstrim.timer
[[ -n $DM ]] && systemctl enable "$DM.service"

if [[ -n $WIFI_SSID ]]; then
  f="/etc/NetworkManager/system-connections/$WIFI_SSID.nmconnection"
  cat > "$f" <<EOF
[connection]
id=$WIFI_SSID
type=wifi
autoconnect=true

[wifi]
mode=infrastructure
ssid=$WIFI_SSID

[wifi-security]
key-mgmt=wpa-psk
psk=$WIFI_PASSWORD

[ipv4]
method=auto

[ipv6]
method=auto
EOF
  chmod 600 "$f"
fi

if [[ ${AUTOLOGIN,,} =~ ^(yes|y|true|1)$ ]]; then
  case $DM in
    sddm)
      mkdir -p /etc/sddm.conf.d
      printf '[Autologin]\nUser=%s\nSession=plasma\n' "$USERNAME" > /etc/sddm.conf.d/autologin.conf ;;
    gdm)
      mkdir -p /etc/gdm
      printf '[daemon]\nAutomaticLoginEnable=True\nAutomaticLogin=%s\n' "$USERNAME" > /etc/gdm/custom.conf ;;
    lightdm)
      groupadd -rf autologin; gpasswd -a "$USERNAME" autologin
      sed -i "s/^#\?autologin-user=.*/autologin-user=$USERNAME/" /etc/lightdm/lightdm.conf ;;
  esac
fi

# bootloader: systemd-boot on the internal disk (the stick is not needed later)
bootctl --esp-path=/boot install
cat > /boot/loader/loader.conf <<EOF
default arch.conf
timeout 3
console-mode max
editor no
EOF
cat > /boot/loader/entries/arch.conf <<EOF
title   Arch Linux
linux   /vmlinuz-$KERNEL
initrd  /initramfs-$KERNEL.img
options root=UUID=$ROOT_UUID rw quiet
EOF
cat > /boot/loader/entries/arch-fallback.conf <<EOF
title   Arch Linux (fallback)
linux   /vmlinuz-$KERNEL
initrd  /initramfs-$KERNEL-fallback.img
options root=UUID=$ROOT_UUID rw
EOF
systemctl enable systemd-boot-update.service
mkinitcpio -P
CHROOT
} > "$MNT/root/ap-configure.sh"
arch-chroot "$MNT" bash /root/ap-configure.sh
rm -f "$MNT/root/ap-configure.sh"

# --- profile software (inside the new system)
ap_log "Copying the repository to /opt/archprofiles"
rm -rf "$MNT/opt/archprofiles"
mkdir -p "$MNT/opt"
cp -a "$AP_SRC" "$MNT/opt/archprofiles"
# never keep a token in the installed copy
if [[ -d $MNT/opt/archprofiles/.git && -n ${AP_REPO_URL:-} ]]; then
  git -C "$MNT/opt/archprofiles" remote set-url origin "$AP_REPO_URL" 2>/dev/null || true
fi
chmod +x "$MNT/opt/archprofiles/installer/"*.sh
ln -sf /opt/archprofiles/installer/profile-apply.sh "$MNT/usr/local/bin/profile-apply"
mkdir -p "$MNT/etc/archprofiles"
cat > "$MNT/etc/archprofiles/install-info.conf" <<EOF
# Written by the Arch profile installer (no passwords stored here)
INSTALL_DATE=$(date '+%F %T')
PROFILES=${PROFILES[*]}
REPO_URL=${AP_REPO_URL:-}
REPO_BRANCH=${AP_REPO_BRANCH:-}
REPO_COMMIT=${AP_REPO_COMMIT:-}
DISK=$DISK
DESKTOP=$DESKTOP
KERNEL=$KERNEL
USERNAME=$USERNAME
EOF

ap_log "Installing profile software: ${PROFILES[*]}"
arch-chroot "$MNT" /opt/archprofiles/installer/profile-apply.sh --chroot "${PROFILES[@]}"

# --- finish
PROBLEMS=""
[[ -s $MNT/var/log/archprofiles/last-problems.txt ]] && PROBLEMS=$(<"$MNT/var/log/archprofiles/last-problems.txt")
mkdir -p "$MNT/var/log/archprofiles"
cp "$LOG" "$MNT/var/log/archprofiles/install.log"
sync
umount -R "$MNT"

echo
ap_ok "Installation finished: ${PROFILES[*]} on $DISK"
if [[ -n $PROBLEMS ]]; then
  ap_warn "Some items could not be installed (the system works anyway):"
  while IFS= read -r l; do printf '     - %s\n' "$l"; done <<<"$PROBLEMS"
  echo "  Fix the names in the profile files, then on the new system run: sudo profile-apply ${PROFILES[*]}"
  sleep 20
fi
echo "  Login: $USERNAME   (change the password with 'passwd')"
echo "  Remove the USB stick now. Log on the new system: /var/log/archprofiles/"
trap - ERR
for s in 10 9 8 7 6 5 4 3 2 1; do printf '\r  %s in %2d s ' "$FINISH_ACTION" "$s"; sleep 1; done
echo
if [[ $FINISH_ACTION == poweroff ]]; then systemctl poweroff; else systemctl reboot; fi
