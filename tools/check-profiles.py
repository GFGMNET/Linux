#!/usr/bin/env python3
"""check-profiles.py — check every profile's package names before installing.

Works on any PC with Python 3 and internet (Linux, Windows, macOS):
    python3 check-profiles.py            check all profiles
    python3 check-profiles.py ai games   check only these

Checks pacman names against archlinux.org, AUR names against the AUR,
Flatpak IDs against Flathub, and warns when a multilib package is used
without NEEDS_MULTILIB=yes.
"""
import json
import pathlib
import sys
import urllib.error
import urllib.parse
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent / "profiles"
UA = {"User-Agent": "archprofiles-check/1.0"}


def read_list(path: pathlib.Path):
    if not path.is_file():
        return []
    out = []
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        out.extend(line.split("#", 1)[0].split())
    return out


def conf_get(path: pathlib.Path, key: str, default=""):
    value = default
    if path.is_file():
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
            line = line.strip()
            if line.startswith(key) and "=" in line and line.split("=", 1)[0].strip() == key:
                value = line.split("=", 1)[1].split("#", 1)[0].strip().strip('"').strip("'")
    return value


def http_status(url: str) -> int:
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=20) as r:
            return r.status
    except urllib.error.HTTPError as e:
        return e.code


def get_json(url: str):
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=20) as r:
        return json.load(r)


def check_pacman(name: str):
    """Return (ok, repo_or_message)."""
    data = get_json("https://archlinux.org/packages/search/json/?name=" + urllib.parse.quote(name))
    for res in data.get("results", []):
        if res.get("pkgname") == name:
            return True, res.get("repo", "")
    if http_status(f"https://archlinux.org/groups/x86_64/{urllib.parse.quote(name)}/") == 200:
        return True, "group"
    return False, "not in the Arch repositories (AUR package? typo?)"


def check_aur(names):
    if not names:
        return set()
    query = "&".join("arg[]=" + urllib.parse.quote(n) for n in names)
    data = get_json("https://aur.archlinux.org/rpc/v5/info?" + query)
    return {r["Name"] for r in data.get("results", [])}


def check_flatpak(app_id: str) -> bool:
    return http_status("https://flathub.org/api/v2/appstream/" + urllib.parse.quote(app_id)) == 200


def main():
    wanted = sys.argv[1:]
    dirs = sorted(d for d in ROOT.iterdir() if d.is_dir() and d.name != "_template")
    if wanted:
        dirs = [d for d in dirs if d.name in wanted]
    problems = 0
    for d in dirs:
        print(f"\n== {d.name}: {conf_get(d / 'profile.conf', 'DESCRIPTION')}")
        multilib = conf_get(d / "profile.conf", "NEEDS_MULTILIB", "no").lower() in ("yes", "y", "true", "1", "on")
        for f in sorted(d.glob("packages*.txt")):
            for pkg in read_list(f):
                ok, info = check_pacman(pkg)
                if not ok:
                    problems += 1
                    print(f"  ✗ {f.name}: {pkg} — {info}")
                elif info == "multilib" and not multilib and d.name != "_base":
                    problems += 1
                    print(f"  ! {f.name}: {pkg} is in [multilib] — set NEEDS_MULTILIB=yes in profile.conf")
                else:
                    print(f"  ✓ {pkg} ({info})")
        aur = read_list(d / "aur.txt")
        found = check_aur(aur)
        for pkg in aur:
            if pkg in found:
                print(f"  ✓ {pkg} (AUR)")
            else:
                problems += 1
                print(f"  ✗ aur.txt: {pkg} — not found in the AUR")
        for app in read_list(d / "flatpak.txt"):
            if check_flatpak(app):
                print(f"  ✓ {app} (Flathub)")
            else:
                problems += 1
                print(f"  ✗ flatpak.txt: {app} — not found on Flathub")
    print(f"\n{'No problems found.' if not problems else f'{problems} problem(s) found.'}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
