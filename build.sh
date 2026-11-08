#!/bin/bash
# Kullanım: ./build.sh          → build/Ezan Vakti.app üretir
#           ./build.sh install  → ayrıca /Applications'a kurar ve başlatır
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release --product EzanVakti
BIN_DIR="$(swift build -c release --show-bin-path)"

APP="build/Ezan Vakti.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/EzanVakti" "$APP/Contents/MacOS/EzanVakti"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/locations.json "$APP/Contents/Resources/locations.json"
codesign --force --sign - "$APP"
echo "Hazır: $APP"

if [[ "${1:-}" == "install" ]]; then
    osascript -e 'quit app id "com.elemirs.ezanvakti"' 2>/dev/null || true
    # Eski süreç bitmeden yenisi açılırsa LaunchServices -600 hatası verir.
    for _ in {1..25}; do
        pgrep -x EzanVakti >/dev/null || break
        sleep 0.2
    done
    rm -rf "/Applications/Ezan Vakti.app"
    ditto "$APP" "/Applications/Ezan Vakti.app"
    open "/Applications/Ezan Vakti.app"
    echo "Kuruldu: /Applications/Ezan Vakti.app"
fi
