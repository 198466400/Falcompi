cat > ~/Falcom/Falcom.sh <<'EOF'
#!/usr/bin/env bash

set -e

echo "========================================"
echo " FALCOM AUTOMATIC INSTALLER"
echo " Raspberry Pi Configuration"
echo "========================================"

USER_NAME="$(whoami)"
HOME_DIR="$(eval echo ~${USER_NAME})"

sudo apt update
sudo apt install -y git retroarch dosbox dosfstools udisks2

mkdir -p "${HOME_DIR}/Falcom"
mkdir -p "${HOME_DIR}/Falcom/bin"
mkdir -p "${HOME_DIR}/Falcom/Games"

cat > "${HOME_DIR}/Falcom/bin/falcom" <<'LAUNCHER'
#!/usr/bin/env bash

GAME_DIR="$HOME/Falcom/Games"
mkdir -p "$GAME_DIR"

echo "Scanning floppy drives..."

DEVICE="$(lsblk -lnpo NAME,RM | awk '$2==1{print $1}' | head -n 1)"

if [ -z "$DEVICE" ]; then
    echo "No removable floppy device detected."
    exit 1
fi

sudo mkdir -p /mnt/falcom

if mount | grep -q "/mnt/falcom"; then
    sudo umount /mnt/falcom || true
fi

sudo mount "$DEVICE" /mnt/falcom 2>/dev/null || {
    echo "Unable to mount floppy."
    exit 1
}

echo "Copying files..."
cp -r /mnt/falcom/* "$GAME_DIR/" 2>/dev/null || true

sudo umount /mnt/falcom

echo "Games imported to:"
echo "$GAME_DIR"

echo "Launching RetroArch..."
retroarch >/dev/null 2>&1 &
LAUNCHER

chmod +x "${HOME_DIR}/Falcom/bin/falcom"

mkdir -p "${HOME_DIR}/Desktop"

cat > "${HOME_DIR}/Desktop/Falcom.desktop" <<DESKTOP
[Desktop Entry]
Version=1.0
Type=Application
Name=Falcom
Comment=Play floppy disk games
Exec=${HOME_DIR}/Falcom/bin/falcom
Terminal=true
Categories=Game;
DESKTOP

chmod +x "${HOME_DIR}/Desktop/Falcom.desktop"

echo
echo "========================================"
echo " Falcom installed successfully"
echo "========================================"
echo
echo "Launch with:"
echo "    ~/Falcom/bin/falcom"
echo
echo "Games will be copied to:"
echo "    ~/Falcom/Games"
echo
EOF

chmod +x ~/Falcom/Falcom.sh
~/Falcom/Falcom.sh
