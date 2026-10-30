#!/bin/bash
# Starter of the Arch profile installer. The Arch ISO runs it automatically
# (boot option script=...). Used on a prepared stick and inside the ready-made
# ISO from GitHub Releases. It only:
#   1. reads settings.conf (see the order below)
#   2. connects to the internet (cable, or Wi-Fi from settings.conf)
#   3. downloads your Git repository (REPO_URL / REPO_BRANCH)
#   4. starts installer/install.sh from that repository
# Everything else (profiles, install logic) lives in the repository.

STICK=/run/archiso/bootmnt/archprofiles
WORK=/tmp/archprofiles-repo
# settings.conf: the first one found is used
#   1. archprofiles/settings.conf on the stick (you can edit it there)
#   2. the defaults built into the ISO
SETTINGS=""
for f in "$STICK/settings.conf" /root/archprofiles/settings.conf; do
  if [[ -f $f ]]; then SETTINGS=$f; break; fi
done
CACHE=$STICK/repo-cache          # optional offline copy, made by make-stick.sh

say()  { printf '\e[1;34m==>\e[0m %s\n' "$*"; }
fail() {
  printf '\e[1;31m==> ERROR:\e[0m %s\n' "$*" >&2
  echo "    You are in the live system shell. Fix settings.conf on the stick and boot again." >&2
  exit 1
}

# read KEY=value without executing the file
conf() {
  local key=$1 default=${2-} line value=${2-}
  [[ -f $SETTINGS ]] || { printf '%s\n' "$default"; return; }
  while IFS= read -r line || [[ -n $line ]]; do
    line=${line//$'\r'/}
    [[ $line =~ ^[[:space:]]*${key}[[:space:]]*=(.*)$ ]] || continue
    value=${BASH_REMATCH[1]}
    value=${value%%#*}
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    value=${value#\"}; value=${value%\"}; value=${value#\'}; value=${value%\'}
  done < "$SETTINGS"
  printf '%s\n' "$value"
}

[[ -n $SETTINGS ]] || fail "settings.conf not found (expected archprofiles/settings.conf on the stick)."

REPO_URL=$(conf REPO_URL)
REPO_BRANCH=$(conf REPO_BRANCH main)
# "auto" or empty: use the repository the ISO was built from
BUILTIN=/root/archprofiles/settings.conf
if [[ -f $BUILTIN ]]; then
  [[ -z $REPO_URL || $REPO_URL == auto ]] && REPO_URL=$(SETTINGS=$BUILTIN conf REPO_URL)
  [[ -z $REPO_BRANCH || $REPO_BRANCH == auto ]] && REPO_BRANCH=$(SETTINGS=$BUILTIN conf REPO_BRANCH main)
fi
[[ $REPO_BRANCH == auto ]] && REPO_BRANCH=main
REPO_TOKEN=$(conf REPO_TOKEN)
WIFI_SSID=$(conf WIFI_SSID)
WIFI_PASSWORD=$(conf WIFI_PASSWORD)
loadkeys "$(conf KEYMAP us)" 2>/dev/null

clear
say "Arch profile installer - starting"
say "Settings: $SETTINGS"
say "Waiting for the live system to finish booting"
systemctl is-system-running --wait &>/dev/null

# --- network
if [[ -n $WIFI_SSID ]]; then
  for dev in /sys/class/net/*; do
    [[ -d $dev/wireless ]] || continue
    dev=${dev##*/}
    say "Connecting to Wi-Fi '$WIFI_SSID' ($dev)"
    iwctl --passphrase "$WIFI_PASSWORD" station "$dev" connect "$WIFI_SSID"
    break
  done
fi
say "Waiting for internet"
online=0
for _ in $(seq 1 60); do
  if ping -c1 -W2 archlinux.org &>/dev/null; then online=1; break; fi
  sleep 2
done

# --- repository
rm -rf "$WORK"
if (( online )); then
  [[ -n $REPO_URL && $REPO_URL != auto && $REPO_URL != *YOUR-NAME* ]] || fail "REPO_URL is not set in settings.conf."
  command -v git &>/dev/null || { say "Installing git"; pacman -Sy --noconfirm --needed git >/dev/null; }
  url=$REPO_URL
  if [[ -n $REPO_TOKEN && $url == https://* ]]; then
    case $url in
      https://github.com/*) user=x-access-token ;;
      https://gitlab.com/*) user=oauth2 ;;
      *)                    user=token ;;
    esac
    url="https://$user:$REPO_TOKEN@${url#https://}"
  fi
  say "Downloading $REPO_URL ($REPO_BRANCH)"
  if ! GIT_TERMINAL_PROMPT=0 git clone --quiet --depth 1 --branch "$REPO_BRANCH" "$url" "$WORK"; then
    rm -rf "$WORK"
    printf '\e[1;33m==> WARNING:\e[0m could not download the repository.\n' >&2
  fi
fi
if [[ ! -f $WORK/installer/install.sh ]]; then
  (( online )) || printf '\e[1;33m==> WARNING:\e[0m no internet connection.\n' >&2
  if [[ -f $CACHE/installer/install.sh ]]; then
    say "Using the offline copy on the stick (may be older than the repository)"
    cp -r "$CACHE" "$WORK"
  else
    fail "No repository available. Check the network cable / Wi-Fi settings, REPO_URL, REPO_BRANCH and REPO_TOKEN."
  fi
  (( online )) || fail "Installing needs internet (all software is downloaded fresh). Connect a cable or set WIFI_SSID."
fi

COMMIT=$(git -C "$WORK" rev-parse --short HEAD 2>/dev/null || echo unknown)
say "Repository version: $COMMIT"

export AP_SETTINGS=$SETTINGS AP_REPO_URL=$REPO_URL AP_REPO_BRANCH=$REPO_BRANCH AP_REPO_COMMIT=$COMMIT
exec bash "$WORK/installer/install.sh" "$WORK"
