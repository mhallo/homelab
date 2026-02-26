#!/usr/bin/env bash
set -euo pipefail

REPO="https://github.com/mhallo/homelab.git"
DIR="/tmp/homelab-bootstrap"

sudo apt update
sudo apt install -y git pipx python3-venv

# Use current non-root user for pipx install
pipx install --include-deps ansible --force

if [ -d "$DIR" ]; then
    echo "$DIR exists, pulling latest changes"
    cd "$DIR"
    git pull
else
    git clone "$REPO" "$DIR"
    cd "$DIR"
fi

# Run playbook using full path to ansible-playbook in pipx
~/.local/bin/ansible-playbook -i inventory site.yml