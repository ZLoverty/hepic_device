#!/usr/bin/env bash
# Download the full project source archive (a git archive of the tagged
# tree, no .git/ history) as an alternative to `git clone` — useful in
# networks where reaching github.com directly is slow or unreliable.
#
# Tries the Tencent COS mirror first, then falls back to the GitHub Release
# asset (see .github/workflows/build-frontend.yml for how both are produced).
#
# Usage:
#   scripts/fetch_src.sh                    # latest release, extract into ./
#   scripts/fetch_src.sh v0.2.0             # specific tag
#   scripts/fetch_src.sh v0.2.0 /opt/hepic  # extract into a chosen directory
#
# Extracts to <target>/hepic-device-<tag>/ (the archive's own top-level
# folder) — this does NOT include backend/static (gitignored, built
# separately, see fetch_static.sh) or the venv; run install.sh afterward.
#
# For a private repo, export GITHUB_TOKEN with a token that has read access.
# Override HEPIC_COS_DOMAIN to point at a different bucket/CDN for testing.
set -euo pipefail

REPO="ZLoverty/hepic_device"
TAG="${1:-latest}"
TARGET_DIR="${2:-.}"
COS_DOMAIN="${HEPIC_COS_DOMAIN:-https://REPLACE-WITH-YOUR-BUCKET.cos.REPLACE-REGION.myqcloud.com}"

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

mkdir -p "$TARGET_DIR"
echo "Extracting into $TARGET_DIR/"
tar -xzf "$TMP_TAR" -C "$TARGET_DIR"

echo "Done. cd into the extracted hepic-device-*/ directory and run ./install.sh"
