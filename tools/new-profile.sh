#!/usr/bin/env bash
# new-profile.sh - create a new profile folder from profiles/_template.
#
#   tools/new-profile.sh dev "Development" "Programming tools"
#
# Then edit the files in profiles/dev/, commit and push. The new profile
# shows up in the installer's list on the next install - nothing to change
# on the USB stick. (Copying the _template folder by hand works just as well.)
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
NAME=${1:-}
TITLE=${2:-$NAME}
DESC=${3:-"My $NAME profile"}

if [[ ! $NAME =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  echo "Usage: $0 <name> [\"Title\"] [\"Description\"]"
  echo "       name: lowercase letters, digits and '-' (it is also the folder name)"
  exit 2
fi
[[ ! -e $ROOT/profiles/$NAME ]] || { echo "Profile '$NAME' already exists."; exit 1; }

cp -r "$ROOT/profiles/_template" "$ROOT/profiles/$NAME"
sed -i "s|^NAME=.*|NAME=\"$TITLE\"|; s|^DESCRIPTION=.*|DESCRIPTION=\"$DESC\"|" "$ROOT/profiles/$NAME/profile.conf"
echo "Created profiles/$NAME - edit packages.txt, flatpak.txt, aur.txt there, then commit and push."
