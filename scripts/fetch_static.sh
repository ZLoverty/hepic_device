#!/usr/bin/env bash
# Download the frontend build artifact and extract it into backend/static/.
#
# Tries the Tencent COS mirror first (see .github/workflows/build-frontend.yml
# for how it's populated), then falls back to the GitHub Release asset if the
# mirror is unreachable or doesn't have the file yet.
#
# Usage:
#   scripts/fetch_static.sh            # latest release
#   scripts/fetch_static.sh v0.2.0     # specific tag
#
# For a private repo, export GITHUB_TOKEN with a token that has read access.
# Override HEPIC_COS_DOMAIN to point at a different bucket/CDN for testing.
set -euo pipefail

REPO="ZLoverty/hepic_device"
TAG="${1:-latest}"
COS_DOMAIN="${HEPIC_COS_DOMAIN:-https://REPLACE-WITH-YOUR-BUCKET.cos.REPLACE-REGION.myqcloud.com}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
TMP_TAR="$(mktemp)"
trap 'rm -f "$TMP_TAR"' EXIT

fetch_from_cos() {
  local tag="$TAG"
  if [ "$tag" = "latest" ]; then
    tag=$(curl -fsSL "$COS_DOMAIN/hepic-device/latest.json" 2>/dev/null \
      | python3 -c "import sys, json; print(json.load(sys.stdin)['tag'])" 2>/dev/null) || return 1
    [ -n "$tag" ] || return 1
  fi
  echo "Trying COS mirror for $tag"
  curl -fsSL "$COS_DOMAIN/hepic-device/releases/$tag/hepic-device-static-${tag}.tar.gz" -o "$TMP_TAR" 2>/dev/null
}

fetch_from_github() {
  local api_url
  if [ "$TAG" = "latest" ]; then
    api_url="https://api.github.com/repos/$REPO/releases/latest"
  else
    api_url="https://api.github.com/repos/$REPO/releases/tags/$TAG"
  fi

  local auth_header=()
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    auth_header=(-H "Authorization: Bearer $GITHUB_TOKEN")
  fi

  echo "Falling back to GitHub release: $TAG"
  local asset_id
  asset_id=$(curl -fsSL "${auth_header[@]}" "$api_url" \
    | python3 -c "import sys, json; d = json.load(sys.stdin); print(next(a['id'] for a in d['assets'] if a['name'].startswith('hepic-device-static-')))")

  echo "Downloading asset $asset_id"
  curl -fsSL "${auth_header[@]}" -H "Accept: application/octet-stream" \
    "https://api.github.com/repos/$REPO/releases/assets/$asset_id" -o "$TMP_TAR"
}

if ! fetch_from_cos; then
  fetch_from_github
fi

echo "Extracting into $REPO_ROOT/backend/"
rm -rf "$REPO_ROOT/backend/static"
tar -xzf "$TMP_TAR" -C "$REPO_ROOT/backend"

echo "Done: $REPO_ROOT/backend/static"
