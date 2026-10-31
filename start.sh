#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if ! command -v python3 &>/dev/null; then
    sudo apt-get install -y python3
fi

IP=$(hostname -I | awk '{print $1}')

echo "==============================="
echo "  FALCOM LAUNCHER"
echo "==============================="
echo "Open in browser:"
echo "  http://localhost:8080"
echo "  http://${IP}:8080"
echo "Press Ctrl+C to stop"

python3 -m http.server 8080