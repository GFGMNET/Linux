# Arch profiles

Profiles and installer scripts for the Arch Linux USB installer.
The USB stick downloads this repository at every install, so a change
pushed here is used by the next install - nothing to change on the stick.

## Layout

```
installer/          install logic (normally no need to touch)
  install.sh          unattended installation (runs on the stick's live system)
  profile-apply.sh    installs a profile's software (also usable later)
  common.sh           shared helpers
profiles/
  _base/            installed with EVERY profile (drivers, browser, fonts ...)
  _template/        copy this to make a new profile
  ai/  office/  cad/  games/
tools/
  new-profile.sh    create a profile from the template
  check-profiles.cmd/.ps1  check all package names (Windows, double-click)
  check-profiles.py        the same with Python (Linux/macOS)
```

Folders starting with `_` are never shown in the profile list.

## Files in a profile folder

All files are optional. One or more names per line, `#` starts a comment.

| File | What goes in it |
|---|---|
| `profile.conf` | `NAME`, `DESCRIPTION`, `NEEDS_MULTILIB=yes` for 32-bit (Steam, Wine) |
| `packages.txt` | official Arch packages - names from https://archlinux.org/packages/ |
| `packages.nvidia.txt` / `.amd.txt` / `.intel.txt` | extra packages only for that graphics card |
| `flatpak.txt` | Flathub app IDs, e.g. `org.signal.Signal` (from the Flathub URL) |
| `aur.txt` | AUR packages (built during install - takes longer) |
| `services.txt` | systemd services to enable, e.g. `cups.service` |
| `setup.sh` | your own commands, run last as root |

A wrong name is skipped with a warning; the rest still installs. Check names
beforehand:

- **Windows:** double-click `tools/check-profiles.cmd`
- **Linux/macOS:** `python3 tools/check-profiles.py` (or `... games` for one profile)

### Automatic check on GitHub

Every change is checked automatically inside a real Arch Linux system
(`.github/workflows/check-profiles.yml` runs `tools/ci-check.sh`), and once
a week in case Arch removes or renames a package. A green check or red X
appears next to each commit; click it to see which file and line is wrong.
Run it by hand: **Actions -> Check profiles -> Run workflow**.

## Ready-made ISO (no script, no stick preparation)

GitHub builds an installer ISO every month and publishes it under
**Releases** (`.github/workflows/build-iso.yml`, files in `iso/`).
Start a build by hand: **Actions -> Build ISO -> Run workflow** (about 20 minutes).

1. Download `arch-profiles-installer-<date>.iso` from Releases.
2. Flash it with Rufus and choose **"ISO Image mode"** when asked -
   or attach it to a virtual machine (UEFI on, Secure Boot off).
3. Optional, for your own user/password/Wi-Fi: create the folder `archprofiles`
   on the stick and put a copy of `iso/settings.conf` in it, then edit it.
   Without it the built-in defaults are used (user `user`, password `changeme`).
   Never put a real password into `iso/settings.conf` here - this repository is public.
4. Boot and choose **"Install Arch Linux (choose profile - ERASES the first disk)"**.

Profile changes never need a new ISO; profiles are downloaded at every install.

## Add a profile

Copy `profiles/_template` to `profiles/<name>` (lowercase, no spaces), edit
its files, commit, push. Or: `tools/new-profile.sh dev "Development" "Programming tools"`.

## Test changes safely

Push to a branch (e.g. `testing`) and set `REPO_BRANCH=testing` in
`settings.conf` on a test stick. Merge to `main` when it works.

## Updates on installed PCs

- **Automatic, weekly** (systemd timer, catches up if the PC was off).
  It gets the newest profiles from this repository, installs what is new in
  the PC's profiles and updates everything (packages, AUR, Flatpak).
  Safeguards: it **skips** when Arch Linux published news since the last update
  (may need a manual step) or when a laptop runs on battery; shutdown is
  blocked while it runs. The user gets a notification with the result, and
  "please restart" after a kernel update.
- **"Update" icon** on the desktop and in the start menu: the same update, right
  now, in a window (asks for the password, shows Arch news and asks first).
- Log: `/var/log/archprofiles/update.log` - set up by `profiles/_base/setup.sh`.

## Security (in `_base`, on every PC)

- **Firewall (ufw)** switched on: incoming connections blocked, outgoing allowed.
  Manage it in KDE System Settings -> Firewall.
- **ClamAV** virus scanner; definitions update automatically (`clamav-freshclam`).
- **Weekly virus scan** of `/home` after the automatic update. Infected files are
  reported by notification and in `/var/log/archprofiles/virus-scan.log` -
  nothing is deleted automatically.
- **ClamTk** (Flatpak): scan files or folders by hand.

## On an installed PC

The repository is copied to `/opt/archprofiles`.

```
sudo profile-apply --list         # show profiles
sudo profile-apply cad            # add another profile later
sudo profile-apply --pull         # get the newest profiles from this repository
sudo profile-apply --update       # update everything: pacman, AUR, Flatpak
```

Logs: `/var/log/archprofiles/` - install details: `/etc/archprofiles/install-info.conf`
