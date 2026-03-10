#!/usr/bin/env bash
# resolve-dep-name.sh — Resolve the installed package name for a dependency key.
#
# Given a key from versions.yml (e.g. "gtk4-layer-shell"), returns the value of
# produces[0] from the dep's package.yml (e.g. "omakasui-gtk4-layer-shell"),
# falling back to the key itself if produces[] is empty or missing.
#
# Usage:
#   resolve-dep-name.sh <dep-key>
#
# Output: prints the resolved package name to stdout.
# Requires: yq, packages/<dep-key>/package.yml to exist.

set -euo pipefail

DEP_KEY="${1:?Usage: resolve-dep-name.sh <dep-key>}"
PKG_YAML="packages/${DEP_KEY}/package.yml"

if [[ ! -f "$PKG_YAML" ]]; then
  echo "ERROR: ${PKG_YAML} not found" >&2
  exit 1
fi

PRODUCES="$(yq e '.produces[0] // ""' "$PKG_YAML")"
echo "${PRODUCES:-${DEP_KEY}}"