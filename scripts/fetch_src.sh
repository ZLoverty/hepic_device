#!/usr/bin/env bash
# Download the full project source archive (a git archive of the tagged
# tree, no .git/ history) as an alternative to `git clone` — useful in
# networks where reaching github.com directly is slow or unreliable.
#
# Tries the Tencent COS mirror first, then falls back to the GitHub Release
# asset (see .github/workflows/build-frontend.yml for how both are produced).
#
# Usage:
#   scripts/fetch_src.sh                    # latest release, laid over ./
#   scripts/fetch_src.sh v0.2.0             # specific tag
#   scripts/fetch_src.sh v0.2.0 /opt/hepic  # laid over a chosen directory
#
# Extracts the archive (whose own top-level folder is hepic-device-<tag>/)
# into a scratch dir, then copies its contents directly into <target> —
# this does NOT include backend/static (gitignored, built separately, see
# fetch_static.sh) or the venv; run install.sh afterward.
#
# For a private repo, export GITHUB_TOKEN with a token that has read access.
# Override HEPIC_COS_DOMAIN to point at a different bucket/CDN for testing.
set -euo pipefail

REPO="ZLoverty/hepic_device"
TAG="${1:-latest}"
TARGET_DIR="${2:-.}"
COS_DOMAIN="https://hepic-device-1456772252.cos.ap-guangzhou.myqcloud.com"

TMP_TAR="$(mktemp)"
TMP_EXTRACT="$(mktemp -d)"
trap 'rm -f "$TMP_TAR"; rm -rf "$TMP_EXTRACT"' EXIT

fetch_from_cos() {
  local tag="$TAG"
  if [ "$tag" = "latest" ]; then
    tag=$(curl -fsSL "$COS_DOMAIN/hepic-device/latest.json" 2>/dev/null \
      | python3 -c "import sys, json; print(json.load(sys.stdin)['tag'])" 2>/dev/null) || return 1
    [ -n "$tag" ] || return 1
  fi
  echo "Trying COS mirror for $tag"
  curl -fsSL "$COS_DOMAIN/hepic-device/releases/$tag/hepic-device-src-${tag}.tar.gz" -o "$TMP_TAR" 2>/dev/null
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
    | python3 -c "import sys, json; d = json.load(sys.stdin); print(next(a['id'] for a in d['assets'] if a['name'].startswith('hepic-device-src-')))")

  echo "Downloading asset $asset_id"
  curl -fsSL "${auth_header[@]}" -H "Accept: application/octet-stream" \
    "https://api.github.com/repos/$REPO/releases/assets/$asset_id" -o "$TMP_TAR"
}

if ! fetch_from_cos; then
  fetch_from_github
fi

tar -xzf "$TMP_TAR" -C "$TMP_EXTRACT"

# The archive's own top-level folder name depends on the resolved tag
# (which may differ from a "latest" TAG), so pick it up rather than
# assuming hepic-device-$TAG.
ARCHIVE_ROOT="$(find "$TMP_EXTRACT" -mindepth 1 -maxdepth 1 -type d)"
if [ -z "$ARCHIVE_ROOT" ] || [ "$(echo "$ARCHIVE_ROOT" | wc -l)" -ne 1 ]; then
  echo "Unexpected archive layout in $TMP_EXTRACT" >&2
  exit 1
fi

mkdir -p "$TARGET_DIR"
echo "Laying source over $TARGET_DIR/"
cp -a "$ARCHIVE_ROOT/." "$TARGET_DIR/"

echo "Done. cd into $TARGET_DIR and run ./install.sh"
