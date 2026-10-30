#!/usr/bin/env bash
# ci-check.sh - strict check of all profiles inside a real Arch Linux system.
#
# Runs automatically on GitHub (see .github/workflows/check-profiles.yml).
# Can also be run by hand on any Arch Linux PC:   bash tools/ci-check.sh
#
# Checks, for every profile:
#   - every name in packages*.txt exists in the Arch repositories
#   - 32-bit [multilib] packages are only used with NEEDS_MULTILIB=yes
#   - pacman can resolve all packages together (no conflicts), separately
#     for no / NVIDIA / AMD / Intel graphics
#   - every name in aur.txt exists in the AUR
#   - every ID in flatpak.txt exists on Flathub
#   - every service in services.txt is provided by some package (warning)
#   - setup.sh has no syntax errors
#
# Needs: pacman with [multilib] enabled and synced (pacman -Sy, pacman -Fy),
#        curl, jq.

set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT" || exit 1
PROFILES=profiles
ERRORS=0
WARNINGS=0
SUMMARY=${GITHUB_STEP_SUMMARY:-/dev/null}
GH=${GITHUB_ACTIONS:-false}

# shellcheck source=SCRIPTDIR/../installer/common.sh
source installer/common.sh

# report LEVEL FILE LINE MESSAGE   (LEVEL = error | warning)
report() {
  local level=$1 file=$2 line=$3 msg=$4
  if [[ $level == error ]]; then ERRORS=$((ERRORS+1)); else WARNINGS=$((WARNINGS+1)); fi
  if [[ $GH == true ]]; then
    printf '::%s file=%s,line=%s::%s\n' "$level" "$file" "$line" "$msg"
  else
    printf '  %-7s %s:%s  %s\n' "${level^^}" "$file" "$line" "$msg"
  fi
  printf '| %s | `%s` line %s | %s |\n' "$( [[ $level == error ]] && echo 'ERROR' || echo 'warning')" "$file" "$line" "$msg" >> "$SUMMARY"
}

# entries FILE -> prints "LINE<TAB>NAME" for every entry
entries() {
  local file=$1 n=0 line word
  [[ -f $file ]] || return 0
  while IFS= read -r line || [[ -n $line ]]; do
    n=$((n+1))
    line=${line%%#*}
    line=${line//$'\r'/}
    set -f
    # shellcheck disable=SC2086
    for word in $line; do printf '%s\t%s\n' "$n" "$word"; done
    set +f
  done < "$file"
}

pkg_repo() {  # prints the repository of an official package/provider, empty if unknown
  ap_pkg_resolve "$1" | awk 'NR==1 {print $1}'
}

check_pacman_lists() {
  local prof=$1 dir=$PROFILES/$1 needs_ml=$2 f ln pkg res first real
  for f in "$dir"/packages*.txt; do
    [[ -f $f ]] || continue
    while IFS=$'\t' read -r ln pkg; do
      if ! res=$(ap_pkg_resolve "$pkg") || [[ -z $res ]]; then
        local hint="not found in the Arch repositories"
        if aur_exists "$pkg"; then hint="$hint - it is an AUR package, move it to aur.txt"; fi
        report error "$f" "$ln" "'$pkg' $hint"
        continue
      fi
      if grep -q '^multilib' <<<"$res" && ! ap_is_yes "$needs_ml"; then
        report error "$f" "$ln" "'$pkg' is a 32-bit [multilib] package - set NEEDS_MULTILIB=yes in $dir/profile.conf"
        continue
      fi
      first=$(head -n1 <<<"$res"); real=${first#* }
      if (( $(wc -l <<<"$res") > 1 )); then
        echo "  ok      $pkg (group, $(wc -l <<<"$res") packages)"
      elif [[ $real != "$pkg" ]]; then
        echo "  ok      $pkg -> $real (${first%% *})"
        report warning "$f" "$ln" "'$pkg' is now provided by '$real' - consider writing '$real' instead"
      else
        echo "  ok      $pkg (${first%% *})"
      fi
    done < <(entries "$f")
  done
}

aur_exists() {
  local n
  n=$(curl -fsS "https://aur.archlinux.org/rpc/v5/info?arg[]=$(jq -rn --arg v "$1" '$v|@uri')" | jq -r '.resultcount' 2>/dev/null)
  [[ ${n:-0} -gt 0 ]]
}

check_aur() {
  local f=$PROFILES/$1/aur.txt ln pkg
  [[ -f $f ]] || return 0
  while IFS=$'\t' read -r ln pkg; do
    if aur_exists "$pkg"; then
      echo "  ok      $pkg (AUR)"
      if [[ -n $(pkg_repo "$pkg") ]]; then
        report warning "$f" "$ln" "'$pkg' is also in the official repositories - faster to put it in packages.txt"
      fi
    else
      report error "$f" "$ln" "'$pkg' not found in the AUR"
    fi
  done < <(entries "$f")
}

check_flatpak() {
  local f=$PROFILES/$1/flatpak.txt ln app code
  [[ -f $f ]] || return 0
  while IFS=$'\t' read -r ln app; do
    code=$(curl -s -o /dev/null -w '%{http_code}' "https://flathub.org/api/v2/appstream/$app")
    if [[ $code == 200 ]]; then
      echo "  ok      $app (Flathub)"
    else
      report error "$f" "$ln" "'$app' not found on Flathub (HTTP $code) - use the ID from the Flathub page URL"
    fi
  done < <(entries "$f")
}

check_services() {
  local f=$PROFILES/$1/services.txt ln svc
  [[ -f $f ]] || return 0
  while IFS=$'\t' read -r ln svc; do
    [[ $svc == *.* ]] || svc="$svc.service"
    if pacman -F -- "usr/lib/systemd/system/$svc" &>/dev/null; then
      echo "  ok      $svc"
    else
      report warning "$f" "$ln" "no package provides '$svc' - check the name"
    fi
  done < <(entries "$f")
}

check_setup() {
  local f=$PROFILES/$1/setup.sh out
  [[ -f $f ]] || return 0
  if out=$(bash -n "$f" 2>&1); then
    echo "  ok      setup.sh syntax"
  else
    report error "$f" 1 "syntax error: ${out//$'\n'/ }"
  fi
}

# Resolve everything that would be installed together, once per GPU vendor.
check_resolution() {
  local prof=$1 v f ln pkg out
  local -A res_msg=()
  local -a res_order=()
  for v in none nvidia amd intel; do
    local -a pkgs=() files=("$PROFILES/_base/packages.txt" "$PROFILES/_base/packages.$v.txt")
    [[ $prof != _base ]] && files+=("$PROFILES/$prof/packages.txt" "$PROFILES/$prof/packages.$v.txt")
    for f in "${files[@]}"; do
      while IFS=$'\t' read -r ln pkg; do
        if ap_pkg_resolve "$pkg" >/dev/null; then pkgs+=("$pkg"); fi
      done < <(entries "$f")
    done
    (( ${#pkgs[@]} )) || continue
    if out=$(pacman -S --print --noconfirm -- "${pkgs[@]}" 2>&1 >/dev/null); then
      echo "  ok      resolves together ($v graphics, ${#pkgs[@]} packages)"
    else
      out=$(grep -iE 'error|conflict|unresolvable' <<<"$out" | head -n 3 | tr '\n' ' ')
      out=${out:-pacman failed}
      # same problem for several graphics types -> report it once
      if [[ -n ${res_msg[$out]+x} ]]; then res_msg[$out]+=", $v"; else res_msg[$out]=$v; res_order+=("$out"); fi
    fi
  done
  for out in "${res_order[@]}"; do
    report error "$PROFILES/$prof/packages.txt" 1 "packages cannot be installed together (graphics: ${res_msg[$out]}): $out"
  done
}

# ---------------------------------------------------------------- main ----
{
  echo "## Profile check"
  echo
  echo "| Level | Where | Problem |"
  echo "|---|---|---|"
} >> "$SUMMARY"

for dir in "$PROFILES"/*/; do
  prof=$(basename "$dir")
  [[ $prof == _template ]] && continue
  conf=$dir/profile.conf
  needs_ml=$(ap_conf_get "$conf" NEEDS_MULTILIB no)
  echo
  echo "== $prof: $(ap_conf_get "$conf" DESCRIPTION "")"
  [[ -f $conf ]] || report warning "$conf" 1 "profile.conf is missing (name and description will be empty)"
  [[ $prof =~ ^[a-z0-9_][a-z0-9-]*$ ]] || report error "$dir" 1 "folder name '$prof' must be lowercase letters, digits and '-' only"
  check_pacman_lists "$prof" "$needs_ml"
  check_resolution "$prof"
  check_aur "$prof"
  check_flatpak "$prof"
  check_services "$prof"
  check_setup "$prof"
done

echo
if (( ERRORS == 0 )); then
  echo "| OK | all profiles | no errors |" >> "$SUMMARY"
  echo "All profiles OK ($WARNINGS warning(s))."
  printf '\n**Result: all profiles OK** (%d warning(s))\n' "$WARNINGS" >> "$SUMMARY"
  exit 0
fi
echo "$ERRORS error(s), $WARNINGS warning(s)."
printf '\n**Result: %d error(s), %d warning(s)** - fix them before installing.\n' "$ERRORS" "$WARNINGS" >> "$SUMMARY"
exit 1
