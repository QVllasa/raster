#!/bin/zsh
# Einmalig: importiert das vom Kontoinhaber erzeugte Developer-ID-Zertifikat samt lokalem Schlüssel
# in einen eigenen Schlüsselbund (entsperrbar ohne Dialog).
# Voraussetzung: ~/.appstore-raster/devid.key (lokal erzeugt) und die heruntergeladene .cer-Datei.
# Aufruf: scripts/import-devid.sh ~/Downloads/developerID_application.cer
set -euo pipefail
DIR="$HOME/.appstore-raster"
CER="${1:?Pfad zur heruntergeladenen .cer-Datei angeben}"
KEYCHAIN="$DIR/raster-release.keychain-db"
[[ -f "$DIR/keychain.pw" ]] || { openssl rand -hex 16 > "$DIR/keychain.pw"; chmod 600 "$DIR/keychain.pw"; }
PW="$(cat "$DIR/keychain.pw")"

openssl x509 -inform DER -in "$CER" -out "$DIR/devid.pem" 2>/dev/null || cp "$CER" "$DIR/devid.pem"
openssl pkcs12 -export -inkey "$DIR/devid.key" -in "$DIR/devid.pem" -out "$DIR/devid.p12" -passout "pass:$PW" -name "Developer ID Application"
[[ -f "$KEYCHAIN" ]] || security create-keychain -p "$PW" "$KEYCHAIN"
security set-keychain-settings "$KEYCHAIN"
security unlock-keychain -p "$PW" "$KEYCHAIN"
# Apple-Zwischenzertifikat für Developer ID (G2), damit die Kette vollständig ist.
curl -fsSL https://www.apple.com/certificateauthority/DeveloperIDG2CA.cer -o "$DIR/DeveloperIDG2CA.cer"
security import "$DIR/DeveloperIDG2CA.cer" -k "$KEYCHAIN" 2>/dev/null || true
security import "$DIR/devid.p12" -k "$KEYCHAIN" -P "$PW" -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$PW" "$KEYCHAIN" >/dev/null
security list-keychains -d user -s $(security list-keychains -d user | tr -d '"') "$KEYCHAIN"
rm -f "$DIR/devid.p12"
security find-identity -v -p codesigning "$KEYCHAIN"
