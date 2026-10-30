#!/bin/bash
# _base/setup.sh - runs as root on every PC after the packages are installed.
# Safe to run again (updates run it too).
#
# Sets up updating:
#   - weekly automatic update (systemd timer)
#   - "Update" icon in the start menu and on every user's desktop

AP=/opt/archprofiles/installer
[[ -d $AP ]] || exit 0

install -Dm644 "$AP/archprofiles-update.service" /etc/systemd/system/archprofiles-update.service
install -Dm644 "$AP/archprofiles-update.timer"   /etc/systemd/system/archprofiles-update.timer
systemctl enable archprofiles-update.timer

chmod +x "$AP"/*.sh
install -Dm644 "$AP/archprofiles-update.desktop" /usr/share/applications/archprofiles-update.desktop
install -Dm644 "$AP/archprofiles-desktop-icon.desktop" /etc/xdg/autostart/archprofiles-desktop-icon.desktop
ln -sf "$AP/ap-update.sh" /usr/local/bin/ap-update

# firewall: block incoming connections, allow outgoing (ufw defaults).
# Set here instead of "ufw enable", which does not work during installation.
if [[ -f /etc/ufw/ufw.conf ]]; then
  sed -i 's/^ENABLED=.*/ENABLED=yes/' /etc/ufw/ufw.conf
  if [[ ${AP_IN_CHROOT:-0} != 1 ]] && command -v ufw &>/dev/null; then
    ufw --force enable >/dev/null 2>&1 || true
  fi
fi

# count updates from now on (Arch news older than this is ignored)
mkdir -p /var/lib/archprofiles
[[ -f /var/lib/archprofiles/last-update ]] || date +%s > /var/lib/archprofiles/last-update

# the update needs systemd to be running; outside the installer apply it now
if [[ ${AP_IN_CHROOT:-0} != 1 ]] && systemctl is-system-running &>/dev/null; then
  systemctl daemon-reload || true
  systemctl start archprofiles-update.timer || true
fi
true
