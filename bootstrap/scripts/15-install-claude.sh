#!/bin/bash
set -euo pipefail

echo "Installing Node.js and Claude Code..."

# Install Node.js via NodeSource
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs

# Install Claude Code globally as debian user
npm install -g @anthropic-ai/claude-code

echo "Claude Code installed"
claude --version || true
