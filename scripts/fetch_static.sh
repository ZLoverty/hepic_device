#!/usr/bin/env bash
# Download the frontend build artifact from a GitHub Release (see
# .github/workflows/build-frontend.yml) and extract it into backend/static/.
#
# Usage:
#   scripts/fetch_static.sh            # latest release
#   scripts/fetch_static.sh v0.2.0     # specific tag
#
# For a private repo, export GITHUB_TOKEN with a token that has read access.
set -euo pipefail

REPO="ZLoverty/hepic_device"
TAG="${1:-latest}"

if [ "$TAG" = "latest" ]; then
  API_URL="https://api.github.com/repos/$REPO/releases/latest"
else
  API_URL="https://api.github.com/repos/$REPO/releases/tags/$TAG"
fi

AUTH_HEADER=()
if [ -n "${GITHUB_TOKEN:-}" ]; then
  AUTH_HEADER=(-H "Authorization: Bearer $GITHUB_TOKEN")
fi

echo "Looking up release: $TAG"
ASSET_ID=$(curl -fsSL "${AUTH_HEADER[@]}" "$API_URL" \
  | python3 -c "import sys, json; d = json.load(sys.stdin); print(next(a['id'] for a in d['assets'] if a['name'].startswith('hepic-device-static-')))")

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
TMP_TAR="$(mktemp)"
trap 'rm -f "$TMP_TAR"' EXIT

echo "Downloading asset $ASSET_ID"
curl -fsSL "${AUTH_HEADER[@]}" -H "Accept: application/octet-stream" \
  "https://api.github.com/repos/$REPO/releases/assets/$ASSET_ID" -o "$TMP_TAR"

echo "Extracting into $REPO_ROOT/backend/"
rm -rf "$REPO_ROOT/backend/static"
tar -xzf "$TMP_TAR" -C "$REPO_ROOT/backend"

echo "Done: $REPO_ROOT/backend/static"
