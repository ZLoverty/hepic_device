#!/usr/bin/env bash
# Pulls the latest code, re-runs install.sh, and restarts the services.
# Triggered by POST /api/system/update (the frontend "更新" button).
#
# Runs detached from the backend process (see start_new_session in
# backend/routers/system.py) and the backend unit uses KillMode=process
# (see deploy/hepic-device-backend.service), so this script survives the
# `systemctl restart` it issues at the end instead of being killed by it.
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
trap 'rm -f "$RUNNING_FILE"' EXIT

RELEASE_BRANCH="main"

echo "===== update started $(date -Iseconds) ====="
cd "$REPO_ROOT"
git fetch origin "$RELEASE_BRANCH"
current_branch="$(git rev-parse --abbrev-ref HEAD)"
if [ "$current_branch" != "$RELEASE_BRANCH" ]; then
  echo "on branch '$current_branch', switching to '$RELEASE_BRANCH' before updating"
  git checkout "$RELEASE_BRANCH"
fi
git pull --ff-only origin "$RELEASE_BRANCH"
./install.sh
sudo systemctl restart hepic-device-backend.service hepic-device-kiosk.service
echo "===== update finished $(date -Iseconds) ====="
