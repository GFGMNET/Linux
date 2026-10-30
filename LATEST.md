# Check result: OK - all checks passed

| | |
|---|---|
| Branch | `main` |
| Commit | `f677a1f` |
| Started by | push |
| Time (UTC) | 2026-10-30 12:29 |
| Prepare Arch Linux | success |
| Check profiles | success |
| Check scripts | success |
| Full log | https://github.com/GFGMNET/Linux/actions/runs/41055229599 |

## Profile check

| Level | Where | Problem |
|---|---|---|
| OK | all profiles | no errors |

**Result: all profiles OK** (0 warning(s))

## Script check (shellcheck)

No problems.

## Full profile check output

```

== _base: Installed together with every profile
  ok      vulkan-radeon (extra)
  ok      vulkan-intel (extra)
  ok      intel-media-driver (extra)
  ok      nvidia-open-dkms (extra)
  ok      nvidia-utils (extra)
  ok      nvidia-settings (extra)
  ok      firefox (extra)
  ok      firefox-i18n-de (extra)
  ok      noto-fonts (extra)
  ok      noto-fonts-emoji (extra)
  ok      ttf-dejavu (extra)
  ok      ttf-liberation (extra)
  ok      htop (extra)
  ok      fastfetch (extra)
  ok      unzip (extra)
  ok      7zip (extra)
  ok      wget (extra)
  ok      rsync (extra)
  ok      bluez (extra)
  ok      bluez-utils (extra)
  ok      power-profiles-daemon (extra)
  ok      fwupd (extra)
  ok      discover (extra)
  ok      packagekit-qt6 (extra)
  ok      kcalc (extra)
  ok      filelight (extra)
  ok      partitionmanager (extra)
  ok      libnotify (extra)
  ok      xdg-user-dirs (extra)
  ok      clamav (extra)
  ok      ufw (extra)
  ok      resolves together (none graphics, 25 packages)
  ok      resolves together (nvidia graphics, 28 packages)
  ok      resolves together (amd graphics, 26 packages)
  ok      resolves together (intel graphics, 27 packages)
  ok      brave-bin (AUR)
  ok      com.gitlab.davem.ClamTk (Flathub)
  ok      bluetooth.service
  ok      power-profiles-daemon.service
  ok      clamav-freshclam.service
  ok      ufw.service
  ok      setup.sh syntax

== ai: Local AI: Ollama, Python, Jupyter, GPU acceleration
  ok      ollama-rocm (extra)
  ok      python-pytorch-rocm (extra)
  ok      ollama-cuda (extra)
  ok      cuda (extra)
  ok      cudnn (extra)
  ok      python-pytorch-cuda (extra)
  ok      nvidia-container-toolkit (extra)
  ok      ollama (extra)
  ok      python (core)
  ok      python-pip (extra)
  ok      python-pipx (extra)
  ok      python-virtualenv (extra)
  ok      python-numpy (extra)
  ok      python-pandas (extra)
  ok      python-matplotlib (extra)
  ok      jupyterlab (extra)
  ok      docker (extra)
  ok      docker-compose (extra)
  ok      git-lfs (extra)
  ok      resolves together (none graphics, 37 packages)
  ok      resolves together (nvidia graphics, 45 packages)
  ok      resolves together (amd graphics, 40 packages)
  ok      resolves together (intel graphics, 39 packages)
  ok      visual-studio-code-bin (AUR)
  ok      com.jeffser.Alpaca (Flathub)
  ok      ollama.service
  ok      docker.service
  ok      setup.sh syntax

== cad: FreeCAD, KiCad, LibreCAD, OpenSCAD, Blender, 3D printing
  ok      freecad (extra)
  ok      openscad (extra)
  ok      librecad (extra)
  ok      kicad (extra)
  ok      kicad-library (extra)
  ok      kicad-library-3d (extra)
  ok      blender (extra)
  ok      prusa-slicer (extra)
  ok      inkscape (extra)
  ok      resolves together (none graphics, 34 packages)
  ok      resolves together (nvidia graphics, 37 packages)
  ok      resolves together (amd graphics, 35 packages)
  ok      resolves together (intel graphics, 36 packages)

== games: Steam, Lutris, Heroic, Wine, GameMode, MangoHud
  ok      lib32-vulkan-radeon (multilib)
  ok      lib32-vulkan-intel (multilib)
  ok      lib32-nvidia-utils (multilib)
  ok      steam (multilib)
  ok      lutris (extra)
  ok      wine (extra)
  ok      winetricks (extra)
  ok      gamemode (extra)
  ok      lib32-gamemode (multilib)
  ok      mangohud (extra)
  ok      lib32-mangohud (multilib)
  ok      gamescope (extra)
  ok      resolves together (none graphics, 34 packages)
  ok      resolves together (nvidia graphics, 38 packages)
  ok      resolves together (amd graphics, 36 packages)
  ok      resolves together (intel graphics, 37 packages)
  ok      com.heroicgameslauncher.hgl (Flathub)
  ok      net.davidotek.pupgui2 (Flathub)
  ok      setup.sh syntax

== office: LibreOffice, mail, PDF, printing and scanning
  ok      libreoffice-fresh (extra)
  ok      libreoffice-fresh-de (extra)
  ok      hunspell-de (extra)
  ok      hunspell-en_us (extra)
  ok      hyphen-de (extra)
  ok      ttf-carlito (extra)
  ok      ttf-caladea (extra)
  ok      thunderbird (extra)
  ok      thunderbird-i18n-de (extra)
  ok      pdfarranger (extra)
  ok      cups (extra)
  ok      cups-pdf (extra)
  ok      system-config-printer (extra)
  ok      print-manager (extra)
  ok      skanlite (extra)
  ok      keepassxc (extra)
  ok      resolves together (none graphics, 41 packages)
  ok      resolves together (nvidia graphics, 44 packages)
  ok      resolves together (amd graphics, 42 packages)
  ok      resolves together (intel graphics, 43 packages)
  ok      cups.service

All profiles OK (0 warning(s)).
```
