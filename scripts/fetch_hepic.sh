#!/usr/bin/env bash
# Download HEPiC's tagged source archive (no .git/ history) as an
# alternative to `pip install git+https://github.com/ZLoverty/HEPiC.git`
# -- pip's git support ignores --index-url and always talks to github.com
# directly, which is exactly what this avoids on networks where reaching
# it is slow or unreliable.
#
# Tries the Tencent COS mirror first (see HEPiC's
# .github/workflows/cos-source.yml for how it's produced), then falls back
# to GitHub's auto-generated tag archive -- HEPiC's Release only ships the
# Windows installer .exe, not a source tarball, so there's no Release
# asset to fall back to (see HEPiC's .github/workflows/release.yml).
#
# Usage:
#   scripts/fetch_hepic.sh                    # latest release, extract into ./
#   scripts/fetch_hepic.sh v1.6.1             # specific tag
#   scripts/fetch_hepic.sh v1.6.1 /opt/hepic  # extract into a chosen directory
#
# Extracts to <target>/HEPiC-<tag>/ from the COS mirror. The GitHub
# fallback's folder naming can differ slightly (GitHub strips a leading
# "v" from the tag), so callers should locate the extracted folder rather
# than assuming its exact name.
#
# For a private repo, export GITHUB_TOKEN with a token that has read access.
set -euo pipefail

REPO="ZLoverty/HEPiC"
TAG="${1:-latest}"
TARGET_DIR="${2:-.}"
COS_DOMAIN="https://hepic-1456772252.cos.ap-guangzhou.myqcloud.com"

TMP_TAR="$(mktemp)"
trap 'rm -f "$TMP_TAR"' EXIT

fetch_from_cos() {
  local tag="$TAG"
  if [ "$tag" = "latest" ]; then
    tag=$(curl -fsSL "$COS_DOMAIN/hepic/latest.json" 2>/dev/null \
      | python3 -c "import sys, json; print(json.load(sys.stdin)['tag'])" 2>/dev/null) || return 1
    [ -n "$tag" ] || return 1
  fi
  echo "Trying COS mirror for $tag"
  curl -fsSL "$COS_DOMAIN/hepic/releases/$tag/hepic-src-${tag}.tar.gz" -o "$TMP_TAR" 2>/dev/null
}

fetch_from_github() {
  local auth_header=()
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    auth_header=(-H "Authorization: Bearer $GITHUB_TOKEN")
  fi

  local tag="$TAG"
  if [ "$tag" = "latest" ]; then
    tag=$(curl -fsSL "${auth_header[@]}" "https://api.github.com/repos/$REPO/releases/latest" \
      | python3 -c "import sys, json; print(json.load(sys.stdin)['tag_name'])")
  fi

  echo "Falling back to GitHub tag archive: $tag"
  curl -fsSL "${auth_header[@]}" \
    "https://github.com/$REPO/archive/refs/tags/${tag}.tar.gz" -o "$TMP_TAR"
}

if ! fetch_from_cos; then
  fetch_from_github
fi

mkdir -p "$TARGET_DIR"
echo "Extracting into $TARGET_DIR/"
tar -xzf "$TMP_TAR" -C "$TARGET_DIR"

echo "Done."
