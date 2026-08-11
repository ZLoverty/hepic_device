#!/usr/bin/env bash
# Bootstrap a brand-new device: pull the latest hepic_device source straight
# from the Tencent COS mirror (see .github/workflows/build-frontend.yml for
# how it's published), extract it into the user's home directory, and run
# install.sh.
#
# Meant to be copied onto a device that has nothing cloned yet, as an
# alternative to `git clone` on networks where reaching github.com is slow
# or unreliable. Unlike scripts/fetch_src.sh (which this repo's own scripts
# use once already cloned), this talks to COS only -- no GitHub fallback --
# since avoiding GitHub entirely is the point here.
#
# Usage:
#   ./bootstrap.sh                    # latest release, into ~/hepic_device
#   ./bootstrap.sh v0.2.0             # specific tag
#   TARGET_DIR=/opt/hepic ./bootstrap.sh
#
# Override HEPIC_COS_DOMAIN to point at a different bucket/CDN for testing.
set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
  echo "Run this as the etpi user with sudo available, not directly as root." >&2
  exit 1
fi

TAG="${1:-latest}"
COS_DOMAIN="${HEPIC_COS_DOMAIN:-https://hepic-device-1456772252.cos.ap-guangzhou.myqcloud.com}"
TARGET_DIR="${TARGET_DIR:-$HOME/hepic_device}"

TMP_TAR="$(mktemp)"
TMP_EXTRACT="$(mktemp -d)"
trap 'rm -f "$TMP_TAR"; rm -rf "$TMP_EXTRACT"' EXIT

if [ "$TAG" = "latest" ]; then
  echo "Resolving latest release tag from COS"
  TAG=$(curl -fsSL "$COS_DOMAIN/hepic-device/latest.json" \
    | python3 -c "import sys, json; print(json.load(sys.stdin)['tag'])")
  if [ -z "$TAG" ]; then
    echo "Could not resolve latest tag from $COS_DOMAIN/hepic-device/latest.json" >&2
    exit 1
  fi
fi

echo "Downloading hepic-device-src-${TAG}.tar.gz from COS"
curl -fsSL "$COS_DOMAIN/hepic-device/releases/$TAG/hepic-device-src-${TAG}.tar.gz" -o "$TMP_TAR"

echo "Extracting archive"
tar -xzf "$TMP_TAR" -C "$TMP_EXTRACT"

# The archive's own top-level folder is hepic-device-<tag>/ (see
# `git archive --prefix` in build-frontend.yml) -- pick it up rather than
# assuming the exact name.
ARCHIVE_ROOT="$(find "$TMP_EXTRACT" -mindepth 1 -maxdepth 1 -type d)"
if [ -z "$ARCHIVE_ROOT" ] || [ "$(echo "$ARCHIVE_ROOT" | wc -l)" -ne 1 ]; then
  echo "Unexpected archive layout in $TMP_EXTRACT" >&2
  exit 1
fi

mkdir -p "$TARGET_DIR"
echo "Laying source over $TARGET_DIR/"
cp -a "$ARCHIVE_ROOT/." "$TARGET_DIR/"

echo "==> Running install.sh in $TARGET_DIR"
cd "$TARGET_DIR"
exec ./install.sh "$TAG"
