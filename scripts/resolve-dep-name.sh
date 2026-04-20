#!/usr/bin/env bash
# resolve-dep-name.sh — Resolve the installed package name for a dependency key.
#
# Usage:  resolve-dep-name.sh <dep-key>
# Output: prints the resolved package name to stdout.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=lib/metadata.sh
source "${SCRIPT_DIR}/lib/metadata.sh"

DEP_KEY="${1:?Usage: resolve-dep-name.sh <dep-key>}"
resolve_dep_name "$DEP_KEY"