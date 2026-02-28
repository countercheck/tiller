#!/usr/bin/env bash
# deploy/scripts/bootstrap.sh
# One-time VM setup: install dependencies and clone repos.
# Safe to re-run (idempotent).
#
# Usage (on a fresh Ubuntu 22.04 VM):
#   bash /path/to/bootstrap.sh
#
# After running: log out and back in to activate Docker group membership,
# then create /etc/breedbase-client.env (RUNBOOK.md step 4) and run deploy.sh.
set -euo pipefail

# Vetted 2025-07-30: "Update traits: Fix docker compose cp command"
BREEDBASE_SHA="0a4d34aa0fcab30ce6680b8baf960bf2c7ef5869"
TILLER_REPO="https://github.com/countercheck/tiller"
BREEDBASE_REPO="https://github.com/TriticeaeToolbox/breedbase"

echo "=== Bootstrap: updating packages ==="
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

echo "=== Bootstrap: installing Docker ==="
if ! command -v docker &>/dev/null; then
    curl -fsSL https://get.docker.com | sudo sh
fi

sudo apt-get install -y docker-compose-plugin

echo "=== Bootstrap: installing nginx and certbot ==="
sudo apt-get install -y nginx certbot python3-certbot-nginx

echo "=== Bootstrap: installing Azure CLI ==="
if ! command -v az &>/dev/null; then
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
fi

echo "=== Bootstrap: adding $USER to docker group ==="
if ! groups "$USER" | grep -q '\bdocker\b'; then
    sudo usermod -aG docker "$USER"
fi

echo "=== Bootstrap: cloning T3 Breedbase ==="
if [ ! -d /opt/breedbase ]; then
    sudo git clone "$BREEDBASE_REPO" /opt/breedbase
    (cd /opt/breedbase && sudo git checkout "$BREEDBASE_SHA")
    sudo chown -R "$USER:$USER" /opt/breedbase
else
    echo "  /opt/breedbase already exists — skipping"
fi

echo "=== Bootstrap: cloning tiller ==="
if [ ! -d /opt/tiller ]; then
    sudo git clone "$TILLER_REPO" /opt/tiller
    sudo chown -R "$USER:$USER" /opt/tiller
else
    echo "  /opt/tiller already exists — skipping"
fi

echo ""
echo "Bootstrap complete."
echo ""
echo "IMPORTANT: Log out and back in to activate Docker group membership."
echo "Then:"
echo "  1. Create /etc/breedbase-client.env  (RUNBOOK.md step 4)"
echo "  2. Run: bash /opt/tiller/deploy/scripts/deploy.sh"
