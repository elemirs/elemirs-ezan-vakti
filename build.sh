#!/bin/bash
# Kullanım: ./build.sh          → build/Ezan Vakti.app üretir
#           ./build.sh install  → ayrıca /Applications'a kurar ve başlatır
#           ./build.sh release  → Apple Silicon + Intel derler, dağıtım ZIP'i üretir (Xcode gerekir)
set -euo pipefail
cd "$(dirname "$0")"

SWIFT_FLAGS=(-c release)
if [[ "${1:-}" == "release" ]]; then
    SWIFT_FLAGS+=(--arch arm64 --arch x86_64)
fi

swift build "${SWIFT_FLAGS[@]}" --product EzanVakti
BIN_DIR="$(swift build "${SWIFT_FLAGS[@]}" --show-bin-path)"

APP="build/Ezan Vakti.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/EzanVakti" "$APP/Contents/MacOS/EzanVakti"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/locations.json "$APP/Contents/Resources/locations.json"
codesign --force --sign - "$APP"
echo "Hazır: $APP"

if [[ "${1:-}" == "release" ]]; then
    rm -f build/Ezan-Vakti-macOS.zip
    ditto -c -k --keepParent "$APP" build/Ezan-Vakti-macOS.zip
    echo "Hazır: build/Ezan-Vakti-macOS.zip"
fi

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
