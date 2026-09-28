#!/bin/zsh
# Baut Raster.app (Universal: Apple Silicon + Intel), signiert und packt ein ZIP.
# Signatur: lokale Identität „Raster Local Signing“, falls vorhanden – dann bleibt die
# Bedienungshilfen-Freigabe über Updates hinweg gültig. Sonst ad hoc.
# Aufruf: scripts/build-app.sh [version]
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-$(cat VERSION)}"
BUILD="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
APP="dist/Raster.app"
KEYCHAIN="$HOME/Library/Keychains/raster-signing.keychain-db"
IDENTITY="Raster Local Signing"

echo "▸ Selbsttest …"
swift build >/dev/null
.build/debug/Raster --selftest | tail -1

echo "▸ Kompiliere Raster $VERSION (Build $BUILD) …"
SLICES=.build/slices
rm -rf "$SLICES" && mkdir -p "$SLICES"
for arch in arm64 x86_64; do
    STAMP=$(date +%s)
    swift build -c release --arch "$arch" -Xswiftc -Osize >/dev/null
    # Seit den Command Line Tools für macOS 27 landet das Ergebnis unter out/Products/Release
    # (für jede Architektur am selben Ort) – daher sofort wegkopieren und auf Aktualität prüfen.
    BIN=""
    for cand in .build/out/Products/Release/Raster ".build/$arch-apple-macosx/release/Raster"; do
        if [[ -f "$cand" && $(stat -f %m "$cand") -ge $STAMP ]]; then BIN="$cand"; break; fi
    done
    [[ -n "$BIN" ]] || { echo "✗ Kein frisch gebautes Programm für $arch gefunden"; exit 1; }
    lipo -archs "$BIN" | grep -qw "$arch" || { echo "✗ $BIN enthält kein $arch"; exit 1; }
    cp "$BIN" "$SLICES/Raster-$arch"
done

echo "▸ Setze App-Paket zusammen …"
rm -rf dist && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create -output "$APP/Contents/MacOS/Raster" "$SLICES/Raster-arm64" "$SLICES/Raster-x86_64"
strip -x "$APP/Contents/MacOS/Raster"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" Resources/Info.plist > "$APP/Contents/Info.plist"
python3 scripts/gen-strings.py
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
cp -R Resources/en.lproj Resources/de.lproj "$APP/Contents/Resources/"
printf 'APPL????' > "$APP/Contents/PkgInfo"

if [[ -f "$KEYCHAIN" ]] && security unlock-keychain -p raster "$KEYCHAIN" 2>/dev/null \
    && security find-identity -p codesigning "$KEYCHAIN" | grep -q "$IDENTITY"; then
    echo "▸ Signiere mit „$IDENTITY“ …"
    codesign --force --sign "$IDENTITY" --keychain "$KEYCHAIN" --timestamp=none "$APP"
else
    echo "▸ Signiere (ad hoc) …"
    codesign --force --sign - --timestamp=none "$APP"
fi
codesign --verify --strict "$APP"

echo "▸ Packe ZIP …"
ditto -c -k --sequesterRsrc --keepParent "$APP" "dist/Raster-$VERSION.zip"
shasum -a 256 "dist/Raster-$VERSION.zip" | tee "dist/Raster-$VERSION.zip.sha256"
lipo -archs "$APP/Contents/MacOS/Raster"
echo "✓ Fertig: $APP"
