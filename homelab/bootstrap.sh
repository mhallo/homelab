#!/usr/bin/env bash
set -euo pipefail
set -x

REPO="https://github.com/mhallo/homelab.git"
DIR="/tmp/homelab-bootstrap"

sudo apt update
sudo apt install -y git pipx python3-venv

pipx install --include-deps ansible --force

# Make the temp folder safe for git
git config --global --add safe.directory "$DIR"

# Clone or update the repo
if [ -d "$DIR" ]; then
    echo "$DIR exists, pulling latest changes"
    cd "$DIR"
    git pull
else
    git clone "$REPO" "$DIR"
    cd "$DIR"
fi

# Find the first site.yml in the repo
SITE_PLAYBOOK=$(find "$DIR" -name "site.yml" | head -n 1)
if [ -z "$SITE_PLAYBOOK" ]; then
    echo "Error: site.yml not found in repo"
    exit 1
fi

# Run the playbook with inventory
~/.local/bin/ansible-playbook -i /tmp/homelab-bootstrap/inventory /tmp/homelab-bootstrap/homelab/site.yml