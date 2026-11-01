
cat > "$HOME/falcom-repair.sh" <<'FALCOM_RECOVERY'
#!/usr/bin/env bash
set -Eeuo pipefail

APP="$HOME/Falcom"
GAMES="$APP/Games"
BIN="$APP/bin"
LOG="$APP/install.log"

mkdir -p "$BIN" "$GAMES"
exec > >(tee -a "$LOG") 2>&1

echo "======================================"
echo "       FALCOM RECOVERY INSTALLER"
echo "======================================"

fail() {
    echo "[ERROR] $*" >&2
    echo "Log: $LOG" >&2
    exit 1
}
trap 'fail "Installation stopped at line $LINENO. See install.log."' ERR

command -v sudo >/dev/null || fail "sudo is required."
command -v apt-get >/dev/null || fail "This installer requires Raspberry Pi OS or Debian."

echo "[1/6] Installing dependencies..."
sudo apt-get update
sudo apt-get install -y git dosbox udisks2 dosfstools python3

echo "[2/6] Installing optional RetroArch..."
if ! command -v retroarch >/dev/null 2>&1; then
    sudo apt-get install -y retroarch || \
        echo "[INFO] RetroArch unavailable; DOSBox remains supported."
fi

echo "[3/6] Preserving existing files..."
mkdir -p "$GAMES" "$BIN"

if [ -f "$BIN/falcom" ]; then
    cp -p "$BIN/falcom" "$BIN/falcom.backup.$(date +%Y%m%d%H%M%S)"
fi

echo "[4/6] Creating working Falcom launcher..."

cat > "$BIN/falcom" <<'LAUNCHER'
#!/usr/bin/env bash
set -Eeuo pipefail

APP="$HOME/Falcom"
GAMES="$APP/Games"
mkdir -p "$GAMES"

echo
echo "=================================="
echo "          FALCOM"
echo "=================================="

import_disk() {
    command -v lsblk >/dev/null || {
        echo "lsblk is required."
        return 1
    }

    command -v udisksctl >/dev/null || {
        echo "udisks2 is not installed."
        return 1
    }

    echo "Looking for a removable FAT-compatible disk..."

    local dev=""
    local line name type rm fs tran

    # Prefer actual partitions, then whole-disk floppy devices.
    for wanted in part disk; do
        while read -r name type rm fs tran; do
            [ -n "${name:-}" ] || continue
            [ "$type" = "$wanted" ] || continue
            [ "$rm" = "1" ] || [ "$tran" = "usb" ] || continue
            [ -n "$fs" ] || continue

            case "$fs" in
                vfat|fat|msdos|exfat|ntfs|ext2|ext3|ext4)
                    dev="$name"
                    break
                    ;;
            esac
        done < <(lsblk -rpn -o NAME,TYPE,RM,FSTYPE,TRAN)

        [ -n "$dev" ] && break
    done

    if [ -z "$dev" ]; then
        echo "No supported removable filesystem found."
        echo "Check the USB floppy drive and disk."
        return 1
    fi

    echo "Detected: $dev"

    local output mountpoint
    output="$(udisksctl mount -b "$dev" 2>&1)" || {
        echo "$output"
        echo "Could not mount disk."
        return 1
    }

    echo "$output"

    mountpoint="$(printf '%s\n' "$output" |
        sed -n 's/^Mounted .* at \(.*\)\.$/\1/p')"

    if [ -z "$mountpoint" ]; then
        echo "Could not determine mount location."
        return 1
    fi

    echo "Importing disk contents..."

    if ! find "$mountpoint" -mindepth 1 -maxdepth 1 -print -quit |
        grep -q .; then
        echo "Disk is empty."
        udisksctl unmount -b "$dev" || true
        return 1
    fi

    if ! cp -a "$mountpoint"/. "$GAMES"/; then
        echo "Import failed. Disk may be damaged."
        udisksctl unmount -b "$dev" || true
        return 1
    fi

    udisksctl unmount -b "$dev" || {
        echo "WARNING: Disk could not be safely unmounted."
        return 1
    }

    echo "Disk successfully imported."
}

play_dos() {
    command -v dosbox >/dev/null 2>&1 || {
        echo "DOSBox is not installed."
        return 1
    }

    local games=()
    local f

    while IFS= read -r -d '' f; do
        games+=("$f")
    done < <(
        find "$GAMES" -type f \
            \( -iname '*.exe' -o -iname '*.com' -o -iname '*.bat' \) \
            -print0 | sort -z
    )

    if [ "${#games[@]}" -eq 0 ]; then
        echo "No DOS executable found in $GAMES"
        return 1
    fi

    echo
    echo "Available DOS games:"

    local i=1
    for f in "${games[@]}"; do
        printf "%d. %s\n" "$i" "${f#"$GAMES"/}"
        ((i+=1))
    done

    local choice
    if [ "${#games[@]}" -eq 1 ]; then
        choice=1
    else
        read -rp "Select game number: " choice
    fi

    [[ "$choice" =~ ^[0-9]+$ ]] || {
        echo "Invalid selection."
        return 1
    }

    (( choice >= 1 && choice <= ${#games[@]} )) || {
        echo "Selection out of range."
        return 1
    }

    f="${games[$((choice-1))]}"
    local relative="${f#"$GAMES"/}"
    local folder="${relative%/*}"
    local base="${relative##*/}"

    if [ "$folder" = "$relative" ]; then
        folder=""
    fi

    echo "Starting: $relative"

    if [ -n "$folder" ]; then
        dosbox -c "mount c \"$GAMES\"" \
               -c "c:" \
               -c "cd \"$folder\"" \
               -c "\"$base\""
    else
        dosbox -c "mount c \"$GAMES\"" \
               -c "c:" \
               -c "\"$base\""
    fi
}

while true; do
    echo
    echo "1. Import USB floppy"
    echo "2. Play DOS game"
    echo "3. View imported games"
    echo "4. Open RetroArch"
    echo "5. Exit"
    echo

    read -rp "Falcom selection: " option

    case "$option" in
        1) import_disk ;;
        2) play_dos ;;
        3) find "$GAMES" -type f -printf '%P\n' ;;
        4)
            if command -v retroarch >/dev/null 2>&1; then
                retroarch
            else
                echo "RetroArch is unavailable."
            fi
            ;;
        5) exit 0 ;;
        *) echo "Invalid selection." ;;
    esac
done
LAUNCHER

chmod +x "$BIN/falcom"

echo "[5/6] Creating desktop shortcut..."

mkdir -p "$HOME/Desktop"

cat > "$HOME/Desktop/Falcom.desktop" <<DESKTOP
[Desktop Entry]
Version=1.0
Type=Application
Name=Falcom
Comment=Import and play floppy disk games
Exec=$BIN/falcom
Terminal=true
Categories=Game;
DESKTOP

chmod +x "$HOME/Desktop/Falcom.desktop"

# Also make the shortcut available through the application menu.
mkdir -p "$HOME/.local/share/applications"
cp "$HOME/Desktop/Falcom.desktop" \
   "$HOME/.local/share/applications/Falcom.desktop"

echo "[6/6] Running installation verification..."

test -x "$BIN/falcom"
test -d "$GAMES"
bash -n "$BIN/falcom"
command -v dosbox >/dev/null

echo
echo "======================================"
echo "       FALCOM INSTALLATION READY"
echo "======================================"
echo "Launcher: $BIN/falcom"
echo "Games:    $GAMES"
echo "Log:      $LOG"
echo
echo "Starting Falcom..."
echo

"$BIN/falcom"
FALCOM_RECOVERY

chmod +x "$HOME/falcom-repair.sh"
bash "$HOME/falcom-repair.sh"
