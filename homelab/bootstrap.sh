#!/usr/bin/env bash
set -euo pipefail

REPO="https://github.com/mhallo/homelab.git"
DIR="$HOME/homelab"

sudo apt update
sudo apt install -y git pipx python3-venv

pipx install --include-deps ansible

git clone "$REPO" "$DIR"

cd "$DIR"
~/.local/bin/ansible-playbook -i inventory site.yml