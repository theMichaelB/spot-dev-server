#!/bin/bash
set -euo pipefail

echo "Installing Tailscale..."

# Install Tailscale using official script
curl -fsSL https://tailscale.com/install.sh | sh

# Enable and start Tailscale daemon
systemctl enable --now tailscaled

# Wait for tailscaled to be ready
sleep 5

echo "Tailscale installed and running"
tailscale version
