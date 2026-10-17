#!/bin/bash

echo "Installing Falcom..."

sudo apt update
sudo apt install -y retroarch dosbox mount

mkdir -p ~/Falcom/Games
mkdir -p ~/Falcom/bin

cat << 'EOF' > ~/Falcom/bin/falcom
#!/bin/bash
echo "Scanning floppy..."
sudo mount /dev/sda /mnt 2>/dev/null
cp /mnt/* ~/Falcom/Games/ 2>/dev/null
echo "Launching RetroArch..."
retroarch
EOF

chmod +x ~/Falcom/bin/falcom

echo "[Desktop Entry]
Type=Application
Name=Falcom
Exec=/home/pi/Falcom/bin/falcom
Icon=system-run
Terminal=true" > ~/Desktop/Falcom.desktop

chmod +x ~/Desktop/Falcom.desktop

echo "Falcom installed."
