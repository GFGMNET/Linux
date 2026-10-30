# shellcheck shell=bash
# Shared helpers for install.sh and profile-apply.sh.
# This file is sourced, never executed directly.

ap_log()  { printf '\e[1;34m==>\e[0m %s\n' "$*"; }
ap_ok()   { printf '\e[1;32m==>\e[0m %s\n' "$*"; }
ap_warn() { printf '\e[1;33m==> WARNING:\e[0m %s\n' "$*" >&2; }
ap_err()  { printf '\e[1;31m==> ERROR:\e[0m %s\n' "$*" >&2; }

# ap_read_list FILE
# Prints every entry of a list file, one per line.
#  - Everything after '#' is a comment.
#  - Blank lines are ignored.
#  - Several entries may share a line, separated by spaces.
#  - Windows line endings (CRLF) are tolerated.
#  - A missing file simply yields nothing.
ap_read_list() {
  local file=$1 line word
  [[ -f $file ]] || return 0
  while IFS= read -r line || [[ -n $line ]]; do
    line=${line%%#*}
    line=${line//$'\r'/}
    set -f
    # shellcheck disable=SC2086
    for word in $line; do printf '%s\n' "$word"; done
    set +f
  done < "$file"
}

# ap_conf_get FILE KEY [DEFAULT]
# Reads KEY=value from a simple config file without executing it.
# Surrounding quotes are removed. The last occurrence wins.
ap_conf_get() {
  local file=$1 key=$2 default=${3-} line value found=0
  if [[ -f $file ]]; then
    while IFS= read -r line || [[ -n $line ]]; do
      line=${line//$'\r'/}
      [[ $line =~ ^[[:space:]]*${key}[[:space:]]*=(.*)$ ]] || continue
      value=${BASH_REMATCH[1]}
      # strip trailing comment only when the value is not quoted
      if [[ $value =~ ^[[:space:]]*\"(.*)\"[[:space:]]*(#.*)?$ ]] \
         || [[ $value =~ ^[[:space:]]*\'(.*)\'[[:space:]]*(#.*)?$ ]]; then
        value=${BASH_REMATCH[1]}
      else
        value=${value%%#*}
        value="${value#"${value%%[![:space:]]*}"}"
        value="${value%"${value##*[![:space:]]}"}"
      fi
      found=1
    done < "$file"
  fi
  if (( found )); then printf '%s\n' "$value"; else printf '%s\n' "$default"; fi
}

# ap_is_yes VALUE  -> true for yes/y/true/1/on (any case)
ap_is_yes() { [[ ${1,,} =~ ^(yes|y|true|1|on)$ ]]; }

# ap_list_profiles PROFILES_DIR
# Prints selectable profile names (folders not starting with '_').
ap_list_profiles() {
  local dir=$1 d name
  for d in "$dir"/*/; do
    [[ -d $d ]] || continue
    name=$(basename "$d")
    [[ $name == _* ]] && continue
    printf '%s\n' "$name"
  done
}

# ap_pkg_resolve NAME
# Asks pacman what installing NAME would install, without installing it.
# Prints "<repo> <package>" per line. Works for normal packages, for names
# that point to another package (e.g. p7zip -> 7zip) and for groups.
# Returns non-zero when pacman does not know the name.
ap_pkg_resolve() {
  pacman -S --print --nodeps --nodeps --noconfirm --print-format '%r %n' -- "$1" 2>/dev/null
}

# ap_enable_multilib [PACMAN_CONF]
# Turns on the 32-bit [multilib] repository. Uncomments the standard
# section, or adds it when the file has none. Returns 0 when enabled.
ap_enable_multilib() {
  local conf=${1:-/etc/pacman.conf}
  grep -q '^\[multilib\]' "$conf" && return 0
  sed -i '/^#[[:space:]]*\[multilib\]/,/^#[[:space:]]*Include/ s/^#[[:space:]]*//' "$conf"
  grep -q '^\[multilib\]' "$conf" && return 0
  printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' >> "$conf"
  grep -q '^\[multilib\]' "$conf"
}

# ap_gpu_vendors
# Prints detected GPU vendors (nvidia, amd, intel), one per line.
# Uses sysfs only, so it needs no extra packages.
ap_gpu_vendors() {
  local dev class vendor
  local -A seen=()
  for dev in "${AP_SYSFS_PCI:-/sys/bus/pci/devices}"/*; do
    [[ -r $dev/class && -r $dev/vendor ]] || continue
    class=$(<"$dev/class")
    [[ $class == 0x03* ]] || continue        # display controllers only
    vendor=$(<"$dev/vendor")
    case $vendor in
      0x10de) seen[nvidia]=1 ;;
      0x1002) seen[amd]=1 ;;
      0x8086) seen[intel]=1 ;;
    esac
  done
  for vendor in "${!seen[@]}"; do printf '%s\n' "$vendor"; done | sort
}
