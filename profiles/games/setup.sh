#!/bin/bash
# Runs as root after all packages of this profile are installed.
USER_NAME=$(getent passwd 1000 | cut -d: -f1)

# GameMode needs the user in the gamemode group
[[ -n $USER_NAME ]] && getent group gamemode &>/dev/null && usermod -aG gamemode "$USER_NAME"
true
