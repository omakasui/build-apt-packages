#!/usr/bin/env bash
# check-updates.sh — Check upstream releases for all packages and open one PR per update.
# Requires: yq v4 (mikefarah), gh (GitHub CLI), jq, curl, git

set -euo pipefail

# Ensure mikefarah yq v4 takes precedence over Python yq or other variants.
export PATH="/usr/local/bin:$PATH"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSIONS_FILE="$REPO_ROOT/versions.yml"
SOURCES_FILE="$REPO_ROOT/update-sources.yml"

log()  { echo "[check-updates] $*"; }
skip() { echo "[check-updates] SKIP $1 — $2"; }
info() { echo "[check-updates] INFO $1 — $2"; }

github_latest_release() {
  gh api "repos/$1/releases/latest" 2>/dev/null | jq -r '.tag_name // empty' 2>/dev/null || true
}

github_latest_release_prerelease() {
  gh api "repos/$1/releases?per_page=1" 2>/dev/null | jq -r '.[0].tag_name // empty' 2>/dev/null || true
}

# Used when multiple products share the same repo (e.g. bitwarden/clients).
github_latest_release_filtered() {
  local owner_repo="$1" prefix="$2"
  gh api "repos/${owner_repo}/releases?per_page=50" 2>/dev/null \
    | jq -r --arg p "$prefix" \
      '[.[] | select(.draft == false and .prerelease == false and (.tag_name | startswith($p))) | .tag_name] | first // empty' \
    2>/dev/null || true
}

# For repos that publish git tags instead of GitHub releases.
github_latest_tag() {
  gh api "repos/$1/tags?per_page=1" 2>/dev/null | jq -r '.[0].name // empty' 2>/dev/null || true
}

gitlab_latest_release() {
  curl -fsSL "https://gitlab.com/api/v4/projects/${1//\//%2F}/releases?per_page=1" \
    | jq -r '.[0].tag_name // empty' 2>/dev/null || true
}

ensure_label() {
  gh label create "auto-update" --color "0075ca" --description "Automated version bump" \
    2>/dev/null || true
}

create_pr() {
  local pkg="$1" current="$2" new_ver="$3" upstream="$4"
  local branch="auto-update/${pkg}/${new_ver}"
  local existing release_url owner_repo

  existing=$(gh pr list --head "$branch" --json number --jq '.[0].number' 2>/dev/null || true)
  if [[ -n "$existing" ]]; then
    skip "$pkg" "PR #${existing} for ${new_ver} already open"
    return 0
  fi

  # Close any stale auto-update PRs for this package targeting a different version.
  gh pr list --label "auto-update" --json number,headRefName 2>/dev/null \
    | jq -r --arg pkg "$pkg" --arg b "$branch" \
      '.[] | select(.headRefName | startswith("auto-update/\($pkg)/")) | select(.headRefName != $b) | .number | tostring' \
    | while read -r stale_num; do
      gh pr close "$stale_num" --comment "Superseded by a newer version bump to \`${new_ver}\`." 2>/dev/null || true
      log "$pkg: closed stale PR #${stale_num} (superseded by ${new_ver})"
    done

  log "$pkg: ${current} → ${new_ver} — creating PR"

  trap 'git checkout main 2>/dev/null || true' RETURN

  git checkout -B "$branch"
  yq e -i ".${pkg}.version = \"${new_ver}\"" "$VERSIONS_FILE"
  git add "$VERSIONS_FILE"
  git commit -m "chore(${pkg}): update to ${new_ver}"
  git push --force-with-lease --set-upstream origin "$branch"

  if [[ "$upstream" == github:* ]]; then
    owner_repo="${upstream#github:}"
    release_url="https://github.com/${owner_repo}/releases"
  elif [[ "$upstream" == gitlab:* ]]; then
    owner_repo="${upstream#gitlab:}"
    release_url="https://gitlab.com/${owner_repo}/-/releases"
  else
    release_url="(unknown)"
  fi

  gh pr create \
    --title "chore(${pkg}): update to ${new_ver}" \
    --body "Automated version bump for \`${pkg}\`: \`${current}\` → \`${new_ver}\`.

**Release notes:** ${release_url}

---
*Created automatically by the [daily update check](../../actions/workflows/check-updates.yml).*
*Only \`versions.yml\` is changed — merging triggers the build workflow.*" \
    --head "$branch" \
    --base main \
    --label "auto-update" || true
}

# ---------------------------------------------------------------------------

log "Starting update check…"
echo ""

git checkout main
git pull --ff-only origin main
ensure_label

PACKAGES=$(yq e 'keys | .[]' "$VERSIONS_FILE")

if [[ -n "${CHECK_SINGLE_PACKAGE:-}" ]]; then
  if ! echo "$PACKAGES" | grep -qx "$CHECK_SINGLE_PACKAGE"; then
    echo "ERROR: package '${CHECK_SINGLE_PACKAGE}' not found in versions.yml" >&2
    exit 1
  fi
  PACKAGES="$CHECK_SINGLE_PACKAGE"
  log "Single-package mode: checking only '${CHECK_SINGLE_PACKAGE}'"
fi

for pkg in $PACKAGES; do
  # Read raw value: avoid `// true` since jq `//` treats `false` as falsy.
  auto_update=$(yq e ".${pkg}.auto_update" "$VERSIONS_FILE")
  if [[ "$auto_update" == "false" ]]; then
    skip "$pkg" "auto_update is false"
    continue
  fi

  upstream=$(yq e ".${pkg}.upstream" "$SOURCES_FILE")
  tag_prefix=$(yq e ".${pkg}.tag_prefix" "$SOURCES_FILE")
  filter_releases=$(yq e ".${pkg}.filter_releases // false" "$SOURCES_FILE")
  use_prerelease=$(yq e ".${pkg}.prerelease // false" "$SOURCES_FILE")
  use_tags=$(yq e ".${pkg}.use_tags // false" "$SOURCES_FILE")

  # yq wraps plain strings in quotes; strip them
  upstream="${upstream//\"/}"
  tag_prefix="${tag_prefix//\"/}"

  if [[ -z "$upstream" || "$upstream" == "null" ]]; then
    skip "$pkg" "no upstream configured in update-sources.yml"
    continue
  fi

  current=$(yq e ".${pkg}.version" "$VERSIONS_FILE")
  current="${current//\"/}"

  raw_tag=""

  if [[ "$upstream" == github:* ]]; then
    owner_repo="${upstream#github:}"
    if [[ "$filter_releases" == "true" ]]; then
      raw_tag=$(github_latest_release_filtered "$owner_repo" "$tag_prefix")
    elif [[ "$use_tags" == "true" ]]; then
      raw_tag=$(github_latest_tag "$owner_repo")
    elif [[ "$use_prerelease" == "true" ]]; then
      raw_tag=$(github_latest_release_prerelease "$owner_repo")
    else
      raw_tag=$(github_latest_release "$owner_repo")
    fi
  elif [[ "$upstream" == gitlab:* ]]; then
    owner_repo="${upstream#gitlab:}"
    raw_tag=$(gitlab_latest_release "$owner_repo")
  else
    skip "$pkg" "unknown upstream scheme: ${upstream}"
    continue
  fi

  if [[ -z "$raw_tag" || "$raw_tag" == "null" ]]; then
    info "$pkg" "could not fetch latest release tag"
    continue
  fi

  new_ver="${raw_tag#"$tag_prefix"}"

  if [[ -z "$new_ver" ]]; then
    info "$pkg" "tag '${raw_tag}' with prefix '${tag_prefix}' yielded empty version — skipping"
    continue
  fi

  if [[ "$new_ver" == "$current" ]]; then
    info "$pkg" "already at latest (${current})"
    continue
  fi

  create_pr "$pkg" "$current" "$new_ver" "$upstream"
done

log "Done."
