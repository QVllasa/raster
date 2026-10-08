#!/bin/zsh
# Baut die Mac-App-Store-Version (Sandbox, ohne private Schnittstellen), signiert sie und erstellt das .pkg.
# Anbieter: Vllasa Ventures UG (haftungsbeschränkt), Team QU9LB387VU.
# Voraussetzungen: „Apple Distribution“ und „3rd Party Mac Developer Installer“ im Schlüsselbund,
# Bereitstellungsprofil appstore/Raster_Mac_App_Store.provisionprofile.
# Aufruf: scripts/build-appstore.sh [version]
set -euo pipefail
cd "$(dirname "$0")/.."

TEAM="QU9LB387VU"
BUNDLE_ID="com.vllasa.raster"
APP_IDENTITY="${APP_IDENTITY:-Apple Distribution: Vllasa Ventures UG (haftungsbeschraenkt) ($TEAM)}"
PKG_IDENTITY="${PKG_IDENTITY:-3rd Party Mac Developer Installer: Vllasa Ventures UG (haftungsbeschraenkt) ($TEAM)}"
PROFILE="appstore/Raster_Mac_App_Store.provisionprofile"
KEYCHAIN="${KEYCHAIN:-$HOME/.appstore-puls/puls-signing.keychain-db}"
[[ -f "$HOME/.appstore-puls/keychain.pw" ]] && security unlock-keychain -p "$(cat "$HOME/.appstore-puls/keychain.pw")" "$KEYCHAIN"
VERSION="${1:-$(cat VERSION)}"
BUILD="$(git rev-list --count HEAD)"
OUT="dist-store"
APP="$OUT/Raster.app"

echo "▸ Selbsttest und Übersetzungen …"
swift build >/dev/null && .build/debug/Raster --selftest | tail -1
python3 scripts/gen-strings.py

echo "▸ Kompiliere Store-Version $VERSION (Build $BUILD) …"
SLICES=.build-store/slices
rm -rf "$SLICES" && mkdir -p "$SLICES"
for arch in arm64 x86_64; do
    STAMP=$(date +%s)
    swift build -c release --arch "$arch" --build-path .build-store -Xswiftc -DAPPSTORE -Xswiftc -Osize >/dev/null
    # Seit den Command Line Tools für macOS 27 landet das Ergebnis unter out/Products/Release
    # (für jede Architektur am selben Ort) – daher sofort wegkopieren und auf Aktualität prüfen.
    BIN=""
    for cand in .build-store/out/Products/Release/Raster ".build-store/$arch-apple-macosx/release/Raster"; do
        if [[ -f "$cand" && $(stat -f %m "$cand") -ge $STAMP ]]; then BIN="$cand"; break; fi
    done
    [[ -n "$BIN" ]] || { echo "✗ Kein frisch gebautes Programm für $arch gefunden"; exit 1; }
    lipo -archs "$BIN" | grep -qw "$arch" || { echo "✗ $BIN enthält kein $arch"; exit 1; }
    cp "$BIN" "$SLICES/Raster-$arch"
done

echo "▸ Erzeuge und signiere den Begleit-Kurzbefehl …"
python3 scripts/make-shortcut.py --out .build-store/shortcut

echo "▸ Setze App-Paket zusammen …"
rm -rf "$OUT" && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build-store/shortcut/Raster.shortcut "$APP/Contents/Resources/"
chmod 644 "$APP/Contents/Resources/Raster.shortcut"
lipo -create -output "$APP/Contents/MacOS/Raster" "$SLICES/Raster-arm64" "$SLICES/Raster-x86_64"
strip -x "$APP/Contents/MacOS/Raster"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" -e "s/io.github.qvllasa.raster/$BUNDLE_ID/" \
    -e "s/© 2026 Qendrim Vllasa · MIT-Lizenz/© 2026 Vllasa Ventures UG (haftungsbeschränkt)/" \
    Resources/Info.plist > "$APP/Contents/Info.plist"
plutil -insert ITSAppUsesNonExemptEncryption -bool NO "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
cp -R Resources/en.lproj Resources/de.lproj "$APP/Contents/Resources/"
printf 'APPL????' > "$APP/Contents/PkgInfo"
cp "$PROFILE" "$APP/Contents/embedded.provisionprofile"

echo "▸ Prüfe auf private, gesperrte oder Accessibility-Schnittstellen …"
# Die Store-Version darf keinerlei Accessibility-API enthalten (Richtlinie 2.4.5, Ablehnung 02.10.2026):
# Fenster werden über den Begleit-Kurzbefehl bewegt. Kein _AX*-Symbol, keine Sandbox-Ausnahme.
if nm -u "$APP/Contents/MacOS/Raster" | grep -E "^_AX|_AXUIElementGetWindow|CGWindowListCreateImage|CGSPrivate|_CGS" \
    || strings "$APP/Contents/MacOS/Raster" | grep -E "^_?AXUIElementGetWindow$|^CGWindowListCreateImage$"; then
    echo "✗ Private, gesperrte oder Accessibility-Symbole gefunden – Abbruch"; exit 1
fi
if grep -q "temporary-exception" appstore/Raster.entitlements; then
    echo "✗ Entitlements enthalten eine temporäre Ausnahme – Apple gewährt sie nicht"; exit 1
fi

echo "▸ Signiere …"
codesign --force --keychain "$KEYCHAIN" --sign "$APP_IDENTITY" --entitlements appstore/Raster.entitlements --timestamp=none "$APP"
codesign --verify --strict --deep "$APP"
codesign -d --entitlements - "$APP" 2>/dev/null | grep -q "app-sandbox" || { echo "✗ Sandbox fehlt"; exit 1; }
codesign -d --entitlements - "$APP" 2>/dev/null | grep -q "com.apple.shortcuts.run" || { echo "✗ Scripting-Ziel Shortcuts Events fehlt"; exit 1; }

echo "▸ Erstelle Installationspaket …"
productbuild --component "$APP" /Applications --keychain "$KEYCHAIN" --sign "$PKG_IDENTITY" "$OUT/Raster-$VERSION.pkg"
pkgutil --check-signature "$OUT/Raster-$VERSION.pkg" | head -3
echo "✓ $OUT/Raster-$VERSION.pkg"
