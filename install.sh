#!/usr/bin/env bash
set -e

echo "=================================="
echo "  FALCOM PI INSTALLER"
echo "=================================="

if [ -d "$HOME/Falcompi" ]; then
    echo "Removing old copy..."
    rm -rf "$HOME/Falcompi"
fi

git clone https://github.com/198466400/Falcompi "$HOME/Falcompi"

cd "$HOME/Falcompi"

cat > "$HOME/Falcompi/start.sh" << 'EOF'
#!/usr/bin/env bash
cd "$(dirname "$0")"
IP=$(hostname -I | awk '{print $1}')
echo "=================================="
echo "  FALCOM RUNNING"
echo "  Open browser:"
echo "  http://localhost:8080"
echo "  http://$IP:8080"
echo "  Ctrl+C to stop"
echo "=================================="
python3 -m http.server 8080
EOF

chmod +x "$HOME/Falcompi/start.sh"
bash "$HOME/Falcompi/start.sh"