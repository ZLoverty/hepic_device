#!/usr/bin/env bash
# Install and start the HEPiC Device systemd services on the Raspberry Pi:
#   - hepic-device-backend.service  (FastAPI/uvicorn backend)
#   - hepic-device-kiosk.service    (X11 + Chromium fullscreen kiosk)
#
# Run on the Pi (Raspberry Pi OS Lite, no desktop), as a user with sudo:
#   scripts/install_services.sh
set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
  echo "Run this as the etpi user with sudo available, not directly as root." >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Installing system packages"
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  xserver-xorg xinit x11-xserver-utils chromium unclutter curl

echo "==> Installing systemd unit files"
sudo cp "$REPO_ROOT/deploy/hepic-device-backend.service" /etc/systemd/system/
sudo cp "$REPO_ROOT/deploy/hepic-device-kiosk.service" /etc/systemd/system/
chmod +x "$REPO_ROOT/deploy/kiosk.xinitrc"

echo "==> Reloading systemd and enabling services"
sudo systemctl daemon-reload
sudo systemctl enable --now hepic-device-backend.service
sudo systemctl enable --now hepic-device-kiosk.service

echo "==> Status"
systemctl --no-pager status hepic-device-backend.service || true
systemctl --no-pager status hepic-device-kiosk.service || true

cat <<'EOF'

Done. Useful commands:
  systemctl status hepic-device-backend
  systemctl status hepic-device-kiosk
  journalctl -u hepic-device-backend -f
  journalctl -u hepic-device-kiosk -f
  sudo systemctl restart hepic-device-backend hepic-device-kiosk
EOF
