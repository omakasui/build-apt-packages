#!/usr/bin/env bash
# install-yq.sh — Install mikefarah yq v4 to /usr/local/bin if not already present.
# Safe to call multiple times (idempotent).

set -euo pipefail

# Check for mikefarah yq v4 at the exact install path (avoids matching Python yq).
if [[ -x /usr/local/bin/yq ]] && /usr/local/bin/yq --version 2>&1 | grep -qE 'mikefarah|v[4-9]\.'; then
  echo "yq already installed: $(/usr/local/bin/yq --version)"
  exit 0
fi

echo "Installing yq..."
sudo wget -qO /usr/local/bin/yq \
  https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq
echo "yq installed: $(yq --version)"