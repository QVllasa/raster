#!/bin/zsh
# Signiert dist/Raster.app mit Developer ID (Hardened Runtime), lässt sie von Apple notarisieren,
# heftet das Ticket an und packt das Release-ZIP. Danach öffnet sich Raster ohne Gatekeeper-Warnung.
# Voraussetzungen: scripts/import-devid.sh einmal ausgeführt; App-Store-Connect-API-Schlüssel in
# ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_FILE (z. B. aus ~/.appstore-puls/env.sh).
# Aufruf: scripts/notarize.sh            (baut vorher mit scripts/build-app.sh)
#         SKIP_NOTARIZE=1 scripts/notarize.sh   (nur signieren – zum Prüfen ohne Apple)
set -euo pipefail
cd "$(dirname "$0")/.."
DIR="$HOME/.appstore-raster"
IDENTITY="${DEVID_IDENTITY:-Developer ID Application: Vllasa Ventures UG (haftungsbeschraenkt) (QU9LB387VU)}"
KEYCHAIN="${KEYCHAIN:-$DIR/raster-release.keychain-db}"
VERSION="$(cat VERSION)"
APP="dist/Raster.app"
ZIP="dist/Raster-$VERSION.zip"
[[ -f "$HOME/.appstore-puls/env.sh" && -z "${ASC_KEY_ID:-}" ]] && source "$HOME/.appstore-puls/env.sh"
[[ -f "$DIR/keychain.pw" ]] && security unlock-keychain -p "$(cat "$DIR/keychain.pw")" "$KEYCHAIN"

scripts/build-app.sh "$VERSION" >/dev/null

echo "▸ Signiere mit „$IDENTITY“ (Hardened Runtime) …"
codesign --force --options runtime --timestamp --keychain "$KEYCHAIN" --sign "$IDENTITY" "$APP"
codesign --verify --strict --deep "$APP"
codesign -d --verbose=2 "$APP" 2>&1 | grep -E "Authority|flags" | head -4

rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
if [[ -n "${SKIP_NOTARIZE:-}" ]]; then
    echo "✓ Signiert (Notarisierung übersprungen): $ZIP"; exit 0
fi

echo "▸ Notarisierung bei Apple (dauert meist 1–5 Minuten) …"
xcrun notarytool submit "$ZIP" --key "${ASC_KEY_FILE/#\~/$HOME}" --key-id "$ASC_KEY_ID" --issuer "$ASC_ISSUER_ID" --wait
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose=2 "$APP"

rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
shasum -a 256 "$ZIP" | tee "$ZIP.sha256"
echo "✓ Notarisiert und bereit für das GitHub-Release: $ZIP"
