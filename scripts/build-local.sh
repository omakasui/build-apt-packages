#!/usr/bin/env bash
# build-local.sh — Legacy entry point. Delegates to build.sh.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/build.sh" "$@"