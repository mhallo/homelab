#!/usr/bin/env bash
set -euo pipefail

REPO="https://github.com/mhallo/homelab.git"
DIR="/tmp/homelab-bootstrap"

sudo apt update
sudo apt install -y git pipx python3-venv

# Install ansible
pipx install --include-deps ansible --force

# Tell Git the temp folder is safe
git config --global --add safe.directory "$DIR"

if [ -d "$DIR" ]; then
    echo "$DIR exists, pulling latest changes"
    cd "$DIR"
    git pull
else
    git clone "$REPO" "$DIR"
    cd "$DIR"
fi

# Run ansible-playbook
~/.local/bin/ansible-playbook -i inventory site.yml