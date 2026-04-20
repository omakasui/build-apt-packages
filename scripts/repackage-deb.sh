#!/usr/bin/env bash
# repackage-deb.sh — Repackage an upstream .deb under the omakasui namespace.
# Usage: repackage-deb.sh <input.deb> <upstream-name> <new-name> <output.deb>

set -euo pipefail

INPUT_DEB="${1:?Usage: repackage-deb.sh <input.deb> <upstream-name> <new-name> <output.deb>}"
UPSTREAM_NAME="${2:?missing upstream-name}"
NEW_NAME="${3:?missing new-name}"
OUTPUT_DEB="${4:?missing output.deb path}"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

EXTRACTED="${WORK_DIR}/extracted"
CTRL="${EXTRACTED}/DEBIAN/control"

echo "Extracting ${INPUT_DEB}..."
mkdir -p "$EXTRACTED"
dpkg-deb -R "$INPUT_DEB" "$EXTRACTED"

awk 'BEGIN{p=1} /^$/{p=0} p{print}' "$CTRL" > "${WORK_DIR}/control.clean" && mv "${WORK_DIR}/control.clean" "$CTRL"

echo "Renaming Package: ${UPSTREAM_NAME} -> ${NEW_NAME}..."
sed -i "s/^Package: ${UPSTREAM_NAME}$/Package: ${NEW_NAME}/" "$CTRL"

# Remove empty/blank lines from conffiles — dpkg-deb rejects non-absolute paths.
if [ -f "${EXTRACTED}/DEBIAN/conffiles" ]; then
  sed -i '/^[[:space:]]*$/d' "${EXTRACTED}/DEBIAN/conffiles"
  [ ! -s "${EXTRACTED}/DEBIAN/conffiles" ] && rm "${EXTRACTED}/DEBIAN/conffiles"
fi

echo "Adding Conflicts / Replaces / Provides for ${UPSTREAM_NAME}..."
grep -q "^Conflicts:" "$CTRL" || printf "Conflicts: %s\n" "$UPSTREAM_NAME" >> "$CTRL"
grep -q "^Replaces:"  "$CTRL" || printf "Replaces: %s\n"  "$UPSTREAM_NAME" >> "$CTRL"
grep -q "^Provides:"  "$CTRL" || printf "Provides: %s\n"  "$UPSTREAM_NAME" >> "$CTRL"

echo "Building ${OUTPUT_DEB}..."
mkdir -p "$(dirname "$OUTPUT_DEB")"
dpkg-deb -b "$EXTRACTED" "$OUTPUT_DEB"

echo "Done: $(ls -lh "$OUTPUT_DEB")"