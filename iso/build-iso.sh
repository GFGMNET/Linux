#!/usr/bin/env bash
# build-iso.sh - builds the ready-made installer ISO with Arch's own tool
# (mkarchiso, "releng" profile = the official Arch ISO) and adds:
#   - the starter      /root/archprofiles/autoinstall.sh
#   - default settings /root/archprofiles/settings.conf (from iso/settings.conf)
#   - a boot menu entry "Install Arch Linux (choose profile ...)"
#
# Runs on GitHub (.github/workflows/build-iso.yml) or on any Arch Linux PC:
#   sudo REPO_URL=https://github.com/you/repo.git REPO_BRANCH=main bash iso/build-iso.sh out
#
# Needs root and the package "archiso".

set -Eeuo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
OUT=$(realpath -m "${1:-$HERE/../out}")
REPO_URL=${REPO_URL:?set REPO_URL to your repository, e.g. https://github.com/you/repo.git}
REPO_BRANCH=${REPO_BRANCH:-main}
RELENG=${RELENG:-/usr/share/archiso/configs/releng}
BUILD=${BUILD_DIR:-/tmp/archprofiles-iso}
PROFILE=$BUILD/profile
WORK=$BUILD/work
VERSION=$(date -u +%Y.%m.%d)
NAME=arch-profiles-installer

log() { printf '\e[1;34m==>\e[0m %s\n' "$*"; }
die() { printf '\e[1;31m==> ERROR:\e[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Run as root."
[[ -d $RELENG ]] || die "Arch ISO profile not found at $RELENG - install the package 'archiso'."

log "Copying the official Arch ISO profile (releng)"
rm -rf "$BUILD"
mkdir -p "$BUILD" "$OUT"
cp -a "$RELENG" "$PROFILE"

# --- 1. starter + default settings inside the live system
log "Adding the starter and default settings"
install -Dm755 "$HERE/autoinstall.sh" "$PROFILE/airootfs/root/archprofiles/autoinstall.sh"
sed -e "s|^REPO_URL=auto\$|REPO_URL=$REPO_URL|" \
    -e "s|^REPO_BRANCH=auto\$|REPO_BRANCH=$REPO_BRANCH|" \
    "$HERE/settings.conf" > "$PROFILE/airootfs/root/archprofiles/settings.conf"
grep -q "^REPO_URL=$REPO_URL\$" "$PROFILE/airootfs/root/archprofiles/settings.conf" \
  || die "Could not set REPO_URL in the built-in settings."
{
  echo
  echo '# added by build-iso.sh'
  echo 'file_permissions["/root/archprofiles/autoinstall.sh"]="0:0:755"'
} >> "$PROFILE/profiledef.sh"
sed -i -e "s|^iso_name=.*|iso_name=\"$NAME\"|" \
       -e "s|^iso_application=.*|iso_application=\"Arch Linux profile installer\"|" \
       "$PROFILE/profiledef.sh"

# --- 2. boot menu entry (UEFI, systemd-boot)
log "Adding the install entry to the boot menu"
ENTRIES=$PROFILE/efiboot/loader/entries
[[ -d $ENTRIES ]] || die "No efiboot/loader/entries in the releng profile - the Arch ISO layout changed."
TEMPLATE=""
for f in $(ls "$ENTRIES"/*.conf 2>/dev/null | sort); do
  [[ $f =~ speech|accessib|memtest|copytoram ]] && continue
  grep -qE '^\s*options.*archisobasedir' "$f" || continue
  TEMPLATE=$f; break
done
[[ -n $TEMPLATE ]] || die "No suitable boot entry found in $ENTRIES."
log "Using $(basename "$TEMPLATE") as template"
INSTALL_ENTRY=$ENTRIES/00-archprofiles-install.conf
sed -e 's|^title .*|title    Install Arch Linux (choose profile - ERASES the first disk)|' \
    -e '/^\s*options/ s|$| script=/root/archprofiles/autoinstall.sh|' \
    "$TEMPLATE" > "$INSTALL_ENTRY"
if grep -q '^sort-key' "$INSTALL_ENTRY"; then
  sed -i 's|^sort-key.*|sort-key 00|' "$INSTALL_ENTRY"
fi
grep -q 'script=/root/archprofiles/autoinstall.sh' "$INSTALL_ENTRY" || die "Could not add the script= option."
echo "----- $INSTALL_ENTRY"; cat "$INSTALL_ENTRY"; echo "-----"

# --- 3. build
log "Building the ISO (this takes 10-20 minutes)"
rm -f "$OUT"/*.iso
mkarchiso -v -w "$WORK" -o "$OUT" "$PROFILE"

ISO=$(ls "$OUT"/*.iso | head -n1)
[[ -f $ISO ]] || die "mkarchiso did not produce an ISO."
FINAL=$OUT/$NAME-$VERSION.iso
mv "$ISO" "$FINAL"
(cd "$OUT" && sha256sum "$(basename "$FINAL")" > "$(basename "$FINAL").sha256")
rm -rf "$WORK"

log "Done: $FINAL ($(du -h "$FINAL" | cut -f1))"
if [[ -n ${GITHUB_OUTPUT:-} ]]; then
  {
    echo "version=$VERSION"
    echo "iso=$FINAL"
    echo "iso_name=$(basename "$FINAL")"
  } >> "$GITHUB_OUTPUT"
fi
