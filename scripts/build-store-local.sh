#!/bin/zsh
# Baut die Store-Variante (Sandbox, Kurzbefehl statt Accessibility) zum lokalen Testen: gleiche Quellen und
# gleiche Sandbox-Berechtigungen wie der Store-Build, aber signiert mit „Raster Local Signing“ statt
# Apple Distribution – so lässt sie sich hier starten und die Sandbox greift trotzdem.
# Aufruf: scripts/build-store-local.sh → dist-store-local/Raster.app
set -euo pipefail
cd "$(dirname "$0")/.."

KEYCHAIN="$HOME/Library/Keychains/raster-signing.keychain-db"
IDENTITY="Raster Local Signing"
OUT="dist-store-local"
APP="$OUT/Raster.app"
VERSION="$(cat VERSION)"
BUILD="$(git rev-list --count HEAD)"

echo "▸ Kompiliere Store-Variante (Debug, nur diese Architektur) …"
swift build --build-path .build-store -Xswiftc -DAPPSTORE >/dev/null
.build-store/debug/Raster --selftest | tail -1
python3 scripts/gen-strings.py
python3 scripts/make-shortcut.py --out .build-store/shortcut

echo "▸ Setze App-Paket zusammen …"
rm -rf "$OUT" && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build-store/debug/Raster "$APP/Contents/MacOS/Raster"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" -e "s/io.github.qvllasa.raster/com.vllasa.raster/" \
    Resources/Info.plist > "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
cp -R Resources/en.lproj Resources/de.lproj "$APP/Contents/Resources/"
cp .build-store/shortcut/Raster.shortcut "$APP/Contents/Resources/"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Gleiche Sandbox-Regeln wie im Store, ohne die Apple-Kennungen (die passen nur zur Apple-Signatur).
ENT="$OUT/local.entitlements"
python3 - "$ENT" <<'PY'
import plistlib, sys
ent = plistlib.load(open("appstore/Raster.entitlements", "rb"))
for key in ("com.apple.application-identifier", "com.apple.developer.team-identifier"):
    ent.pop(key, None)
plistlib.dump(ent, open(sys.argv[1], "wb"))
PY

echo "▸ Prüfe auf Accessibility-Symbole …"
if nm -u "$APP/Contents/MacOS/Raster" | grep -qE "^_AX"; then echo "✗ Accessibility-Symbole gefunden"; exit 1; fi

echo "▸ Signiere mit „$IDENTITY“ (Sandbox) …"
security unlock-keychain -p raster "$KEYCHAIN"
codesign --force --keychain "$KEYCHAIN" --sign "$IDENTITY" --entitlements "$ENT" --timestamp=none "$APP"
codesign --verify --strict "$APP"
codesign -d --entitlements - "$APP" 2>/dev/null | grep -E "app-sandbox|shortcuts" | sed 's/^/  /'
echo "✓ $APP"
