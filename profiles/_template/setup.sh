#!/bin/bash
# Optional: your own commands. Runs as root inside the new system, LAST,
# after all packages are installed. Delete this file if you don't need it.
#
# Available variables:
#   $AP_PROFILE       name of this profile
#   $AP_GPU_VENDORS   detected GPUs, e.g. "nvidia" or "amd intel"
#   $AP_IN_CHROOT     1 during installation, 0 when run later on the system
#
# The first normal user (created by the installer):
# shellcheck disable=SC2034
USER_NAME=$(getent passwd 1000 | cut -d: -f1)

# Example: add the user to a group
# usermod -aG docker "$USER_NAME"

true
