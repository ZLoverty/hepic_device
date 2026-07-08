#!/bin/sh
# X session for the kiosk display: no window manager, just a fullscreen
# Chromium pointed at the locally running HEPiC Device backend.
set -e

xset s off
xset -dpms
xset s noblank

unclutter -idle 0.5 -root &

# The backend service is started first (systemd ordering), but uvicorn may
# still be finishing startup — wait until it actually answers before
# launching the browser, otherwise Chromium shows a connection error page.
until curl -sf http://localhost:8000/api/system/info >/dev/null 2>&1; do
  sleep 1
done

exec chromium \
  --kiosk \
  --noerrdialogs \
  --disable-infobars \
  --disable-session-crashed-bubble \
  --check-for-update-interval=31536000 \
  --incognito \
  http://localhost:8000
