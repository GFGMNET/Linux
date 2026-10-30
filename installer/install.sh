#!/usr/bin/env bash
# install.sh  fully unattended Arch Linux installation.
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
  cat <<'EOF'
   ___          _       ___           __ _ _          ___         _        _ _
  / _ \ _ _ __ | |_    | _ \_ _ ___  / _(_) |___ ___|_ _|_ _  __| |_ __ _| | |___ _ _
