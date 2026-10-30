#!/usr/bin/env bash
# ap-desktop-icon.sh - puts the "Update" icon on the user's desktop.
# Runs once per user at login (autostart). Uses the desktop folder of the
# user's language (e.g. "Schreibtisch" in German).

src=/usr/share/applications/archprofiles-update.desktop
marker=${XDG_CONFIG_HOME:-$HOME/.config}/archprofiles-desktop-icon.done
[[ -f $src && ! -f $marker ]] || exit 0

desktop=$(xdg-user-dir DESKTOP 2>/dev/null)
[[ -n $desktop && $desktop != "$HOME" ]] || desktop=$HOME/Desktop
mkdir -p "$desktop"
cp "$src" "$desktop/Update.desktop"
chmod +x "$desktop/Update.desktop"     # executable = trusted, no warning on click

mkdir -p "$(dirname "$marker")"
touch "$marker"
