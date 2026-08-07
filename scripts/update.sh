#!/usr/bin/env bash
# Checks the latest published release against the version currently
# installed, and if it's newer: fetches the source (Tencent COS mirror
# first, GitHub Release as fallback — see scripts/fetch_src.sh), re-runs
# install.sh, and restarts the services. No-ops if already up to date.
# Triggered by POST /api/system/update (the frontend "更新" button).
#
# Runs detached from the backend process (see start_new_session in
# backend/routers/system.py) and the backend unit uses KillMode=process
# (see deploy/hepic-device-backend.service), so this script survives the
# `systemctl restart` it issues at the end instead of being killed by it.
#
# Override HEPIC_COS_DOMAIN to point at a different bucket/CDN for testing.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="$REPO_ROOT/update.log"
LOCK_FILE="$REPO_ROOT/update.lock"
RUNNING_FILE="$REPO_ROOT/update.running"

exec >>"$LOG_FILE" 2>&1

exec 200>"$LOCK_FILE"
if ! flock -n 200; then
  echo "$(date -Iseconds) update already running, ignoring duplicate trigger"
  exit 1
fi

touch "$RUNNING_FILE"
cleanup() {
  rm -f "$RUNNING_FILE"
}
trap cleanup EXIT

REPO="ZLoverty/hepic_device"
COS_DOMAIN="https://hepic-device-1456772252.cos.ap-guangzhou.myqcloud.com"

echo "===== update started $(date -Iseconds) ====="
cd "$REPO_ROOT"

# Resolves the latest published tag: COS mirror pointer first (see
# scripts/fetch_src.sh / .github/workflows/build-frontend.yml), falling
# back to the GitHub Releases API if the mirror is unreachable.
resolve_latest_tag() {
  local tag
  tag=$(curl -fsSL "$COS_DOMAIN/hepic-device/latest.json" 2>/dev/null \
    | python3 -c "import sys, json; print(json.load(sys.stdin)['tag'])" 2>/dev/null) || tag=""
  if [ -n "$tag" ]; then
    echo "Resolved latest tag from COS: $tag" >&2
    echo "$tag"
    return 0
  fi

  echo "COS latest.json unreachable, falling back to GitHub API" >&2
  local auth_header=()
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    auth_header=(-H "Authorization: Bearer $GITHUB_TOKEN")
  fi
  tag=$(curl -fsSL "${auth_header[@]}" "https://api.github.com/repos/$REPO/releases/latest" \
    | python3 -c "import sys, json; print(json.load(sys.stdin)['tag_name'])" 2>/dev/null) || tag=""
  if [ -z "$tag" ]; then
    echo "Could not resolve latest tag from COS or GitHub" >&2
    return 1
  fi
  echo "Resolved latest tag from GitHub: $tag" >&2
  echo "$tag"
}

local_version="v$(python3 -c "from backend import __version__; print(__version__)")"
latest_tag="$(resolve_latest_tag)"

echo "installed: $local_version, latest release: $latest_tag"

is_behind=$(python3 -c "
local = tuple(int(x) for x in '$local_version'.lstrip('v').split('.'))
remote = tuple(int(x) for x in '$latest_tag'.lstrip('v').split('.'))
print('1' if local < remote else '0')
")

if [ "$is_behind" != "1" ]; then
  echo "already up to date, nothing to do"
  echo "===== update finished $(date -Iseconds) (no-op) ====="
  exit 0
fi

# git archive only includes tracked files, so this never touches .venv,
# backend/static, update.log/lock/running, or any other gitignored runtime
# state — safe to lay directly over the existing install.
echo "fetching source for $latest_tag"
"$REPO_ROOT/scripts/fetch_src.sh" "$latest_tag" "$REPO_ROOT"

./install.sh "$latest_tag"
sudo systemctl restart hepic-device-backend.service hepic-device-kiosk.service
echo "===== update finished $(date -Iseconds) ====="
