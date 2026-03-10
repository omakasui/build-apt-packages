#!/usr/bin/env bash
# install-yq.sh — Install yq to /usr/local/bin if not already present.
# Safe to call multiple times (idempotent).

set -euo pipefail

if command -v yq >/dev/null 2>&1; then
  echo "yq already installed: $(yq --version)"
  exit 0
fi

echo "Installing yq..."
sudo wget -qO /usr/local/bin/yq \
  https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq
echo "yq installed: $(yq --version)"