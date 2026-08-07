#!/usr/bin/env bash
# One-stop installer for the Raspberry Pi. Run once after `git clone`:
#
#   ./install.sh            # latest frontend release
#   ./install.sh v0.2.0     # specific tag
#
# Steps:
#   1. create the Python venv and install the backend (+ HEPiC core) into it
#   2. download and extract the built frontend from a GitHub Release
#   3. install the systemd units and start backend + kiosk services
#
# For a private repo, export GITHUB_TOKEN before running (see scripts/fetch_static.sh).
set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
  echo "Run this as the etpi user with sudo available, not directly as root." >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TAG="${1:-latest}"
PIP_INDEX_URL="https://pypi.tuna.tsinghua.edu.cn/simple"

echo "==> [1/3] Setting up Python virtualenv"
if [ ! -d "$REPO_ROOT/.venv" ]; then
  python3 -m venv "$REPO_ROOT/.venv"
fi
"$REPO_ROOT/.venv/bin/pip" install --index-url "$PIP_INDEX_URL" --upgrade pip

# pyproject.toml lists a plain "HEPiC>=..." (no VCS URL) so that pip never
# tries to `git clone` github.com itself -- fetch and install it from the
# COS-mirrored source archive first, so it's already satisfied by the time
# `pip install -e .` below resolves hepic-device's own dependencies.
HEPIC_TMP="$(mktemp -d)"
trap 'rm -rf "$HEPIC_TMP"' EXIT
"$REPO_ROOT/scripts/fetch_hepic.sh" "${HEPIC_TAG:-latest}" "$HEPIC_TMP"
HEPIC_SRC="$(find "$HEPIC_TMP" -mindepth 1 -maxdepth 1 -type d)"
"$REPO_ROOT/.venv/bin/pip" install --index-url "$PIP_INDEX_URL" "$HEPIC_SRC"

"$REPO_ROOT/.venv/bin/pip" install --index-url "$PIP_INDEX_URL" -e "$REPO_ROOT"

echo "==> [2/3] Fetching frontend build ($TAG)"
"$REPO_ROOT/scripts/fetch_static.sh" "$TAG"

echo "==> [3/3] Installing and starting systemd services"
"$REPO_ROOT/scripts/install_services.sh"

echo
echo "Install complete."
