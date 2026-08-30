#!/usr/bin/env bash
# check-updates.sh — Check upstream releases for all packages and open one PR per update.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

# Ensure mikefarah yq v4 takes precedence over Python yq or other variants.
export PATH="/usr/local/bin:$PATH"

VERSIONS_FILE="$REPO_ROOT/versions.yml"
SOURCES_FILE="$REPO_ROOT/update-sources.yml"

# Prefixed variants; note() rather than info() so it doesn't shadow common.sh.
log()  { echo "[check-updates] $*"; }
skip() { echo "[check-updates] SKIP $1 — $2"; }
note() { echo "[check-updates] INFO $1 — $2"; }

github_latest_release() {
  gh api "repos/$1/releases/latest" 2>/dev/null | jq -r '.tag_name // empty' 2>/dev/null || true
}

github_latest_release_prerelease() {
  gh api "repos/$1/releases?per_page=1" 2>/dev/null | jq -r '.[0].tag_name // empty' 2>/dev/null || true
}

# For repos that publish multiple products sharing the same upstream repo.
github_latest_release_filtered() {
  local owner_repo="$1" prefix="$2"
  gh api "repos/${owner_repo}/releases?per_page=50" 2>/dev/null \
    | jq -r --arg p "$prefix" \
      '[.[] | select(.draft == false and .prerelease == false and (.tag_name | startswith($p))) | .tag_name] | first // empty' \
    2>/dev/null || true
}

# For repos that publish tags instead of GitHub Releases.
github_latest_tag() {
  gh api "repos/$1/tags?per_page=1" 2>/dev/null | jq -r '.[0].name // empty' 2>/dev/null || true
}

gitlab_latest_release() {
  curl -fsSL "https://gitlab.com/api/v4/projects/${1//\//%2F}/releases?per_page=1" \
    | jq -r '.[0].tag_name // empty' 2>/dev/null || true
}

codeberg_latest_release() {
  curl -fsSL "https://codeberg.org/api/v1/repos/$1/releases?limit=1" \
    | jq -r '.[0].tag_name // empty' 2>/dev/null || true
}

codeberg_latest_tag() {
  curl -fsSL "https://codeberg.org/api/v1/repos/$1/tags?limit=1" \
    | jq -r '.[0].name // empty' 2>/dev/null || true
}

# For entries marked external: true
sibling_repo_latest_release() {
  local owner_repo="$1" prefix="$2"
  gh release list --repo "$owner_repo" \
    --exclude-drafts --exclude-pre-releases -L 200 \
    --json tagName -q '.[].tagName' 2>/dev/null \
    | grep -m1 "^${prefix}" || true
}

ensure_label() {
  gh label create "auto-update" --color "0075ca" --description "Automated version bump" \
    2>/dev/null || true
  gh label create "auto-update-lock" --color "e4e669" --description "Freeze auto-updates until this PR is closed" \
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

  # Respect the auto-update-lock label: do not create or supersede a locked PR.
  local locked_num
  locked_num=$(gh pr list --label "auto-update-lock" --json number,headRefName 2>/dev/null \
    | jq -r --arg pkg "$pkg" \
      '[.[] | select(.headRefName | startswith("auto-update/\($pkg)/"))] | .[0].number // empty' \
    2>/dev/null || true)
  if [[ -n "$locked_num" ]]; then
    skip "$pkg" "PR #${locked_num} is locked (label 'auto-update-lock') — remove the label or close the PR to resume auto-updates"
    return 0
  fi

  # Close any stale auto-update PRs targeting a different version.
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
  elif [[ "$upstream" == codeberg:* ]]; then
    owner_repo="${upstream#codeberg:}"
    release_url="https://codeberg.org/${owner_repo}/releases"
  elif [[ "$upstream" == sibling:* ]]; then
    owner_repo="${upstream#sibling:}"
    release_url="https://github.com/${owner_repo}/releases"
  else
    release_url="(unknown)"
  fi

  local is_external body
  is_external=$(yq e ".${pkg}.external // false" "$VERSIONS_FILE")

  if [[ "$is_external" == "true" ]]; then
    body="Tracks the latest \`${pkg}-*\` release published in \`${owner_repo}\`: \`${current}\` → \`${new_ver}\`.

This only updates the tracking field in \`versions.yml\` — \`${pkg}\` is \`external: true\` and is never built here.

**Action needed:** dependents of \`${pkg}\` (see \`depends_on\`) are NOT rebuilt by this PR. Trigger **Build package** manually for them after merging.

**Release notes:** ${release_url}

---
*Created automatically by the [update check](../../actions/workflows/check-updates.yml).*"
  else
    body="Automated version bump for \`${pkg}\`: \`${current}\` → \`${new_ver}\`.

**Release notes:** ${release_url}

---
*Created automatically by the [daily update check](../../actions/workflows/check-updates.yml).*
*Only \`versions.yml\` is changed — merging triggers the build workflow.*"
  fi

  # Retry PR creation; apply the label separately to avoid label-fetch timeouts.
  local pr_url="" pr_created=false
  for attempt in 1 2 3; do
    if pr_url=$(gh pr create \
          --title "chore(${pkg}): update to ${new_ver}" \
          --body "$body" \
          --head "$branch" \
          --base main 2>&1); then
      pr_created=true
      gh pr edit "$pr_url" --add-label "auto-update" 2>/dev/null || true
      break
    fi
    log "$pkg: PR creation attempt ${attempt}/3 failed — ${pr_url}"
    [[ $attempt -lt 3 ]] && sleep $((attempt * 15))
  done
  if [[ "$pr_created" == false ]]; then
    log "$pkg: WARNING — PR creation failed after 3 attempts. Branch '${branch}' is already pushed."
    log "$pkg: SUGGESTION — Retry with:  CHECK_SINGLE_PACKAGE=${pkg} bash scripts/check-updates.sh"
    log "$pkg:              Or directly:  gh pr create --title 'chore(${pkg}): update to ${new_ver}' --head '${branch}' --base main --label 'auto-update'"
  fi
}

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
  # Read raw value without `// true` — jq `//` treats `false` as falsy.
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

  # Strip surrounding quotes added by yq.
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
  elif [[ "$upstream" == codeberg:* ]]; then
    owner_repo="${upstream#codeberg:}"
    if [[ "$use_tags" == "true" ]]; then
      raw_tag=$(codeberg_latest_tag "$owner_repo")
    else
      raw_tag=$(codeberg_latest_release "$owner_repo")
    fi
  elif [[ "$upstream" == sibling:* ]]; then
    owner_repo="${upstream#sibling:}"
    raw_tag=$(sibling_repo_latest_release "$owner_repo" "$tag_prefix")
  else
    skip "$pkg" "unknown upstream scheme: ${upstream}"
    continue
  fi

  if [[ -z "$raw_tag" || "$raw_tag" == "null" ]]; then
    note "$pkg" "could not fetch latest release tag"
    continue
  fi

  new_ver="${raw_tag#"$tag_prefix"}"

  if [[ -z "$new_ver" ]]; then
    note "$pkg" "tag '${raw_tag}' with prefix '${tag_prefix}' yielded empty version — skipping"
    continue
  fi

  if [[ "$new_ver" == "$current" ]]; then
    note "$pkg" "already at latest (${current})"
    continue
  fi

  create_pr "$pkg" "$current" "$new_ver" "$upstream"
done

log "Done."