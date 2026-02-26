#!/usr/bin/env bash
set -euo pipefail

REPO="https://github.com/mhallo/homelab.git"
DIR="/tmp/homelab-bootstrap"

sudo apt update
sudo apt install -y git pipx python3-venv

pipx install --include-deps ansible

if [ -d "$DIR" ]; then
    echo "$DIR exists, pulling latest changes"
    cd "$DIR"
    git pull
else
    git clone "$REPO" "$DIR"
    cd "$DIR"
fi

~/.local/bin/ansible-playbook -i inventory site.yml