#!/bin/bash
# Runs as root after all packages of this profile are installed.
USER_NAME=$(getent passwd 1000 | cut -d: -f1)

# let the user run docker without sudo
[[ -n $USER_NAME ]] && usermod -aG docker "$USER_NAME"

# make Docker containers able to use the NVIDIA GPU
if [[ $AP_GPU_VENDORS == *nvidia* ]] && command -v nvidia-ctk &>/dev/null; then
  nvidia-ctk runtime configure --runtime=docker || true
fi

# Optional: download a model on first use instead of now, e.g.
#   ollama pull llama3.2
true
