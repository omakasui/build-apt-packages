#!/usr/bin/env bash
# lint-package.sh — Legacy entry point. Delegates to lint.sh.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/lint.sh" "$@"