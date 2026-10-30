# Arch profiles

Profiles and installer scripts for the Arch Linux USB installer.
The USB stick downloads this repository at every install, so a change
pushed here is used by the next install — nothing to change on the stick.

## Layout

```
installer/          install logic (normally no need to touch)
  install.sh          unattended installation (runs on the stick's live system)
  profile-apply.sh    installs a profile's software (also usable later)
  common.sh           shared helpers
profiles/
  _base/            installed with EVERY profile (drivers, browser, fonts …)
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
| `packages.txt` | official Arch packages — names from https://archlinux.org/packages/ |
| `packages.nvidia.txt` / `.amd.txt` / `.intel.txt` | extra packages only for that graphics card |
| `flatpak.txt` | Flathub app IDs, e.g. `org.signal.Signal` (from the Flathub URL) |
| `aur.txt` | AUR packages (built during install — takes longer) |
| `services.txt` | systemd services to enable, e.g. `cups.service` |
| `setup.sh` | your own commands, run last as root |

A wrong name is skipped with a warning; the rest still installs. Check names
beforehand:

- **Windows:** double-click `tools/check-profiles.cmd`
- **Linux/macOS:** `python3 tools/check-profiles.py` (or `... games` for one profile)

## Add a profile

Copy `profiles/_template` to `profiles/<name>` (lowercase, no spaces), edit
its files, commit, push. Or: `tools/new-profile.sh dev "Development" "Programming tools"`.

## Test changes safely

Push to a branch (e.g. `testing`) and set `REPO_BRANCH=testing` in
`settings.conf` on a test stick. Merge to `main` when it works.

## On an installed PC

The repository is copied to `/opt/archprofiles`.

```
sudo profile-apply --list         # show profiles
sudo profile-apply cad            # add another profile later
sudo profile-apply --pull         # get the newest profiles from this repository
sudo profile-apply --update       # update everything: pacman, AUR, Flatpak
```

Logs: `/var/log/archprofiles/` · install details: `/etc/archprofiles/install-info.conf`
