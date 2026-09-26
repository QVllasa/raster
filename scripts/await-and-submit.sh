#!/bin/zsh
# Wartet, bis der App-Eintrag in App Store Connect existiert (nur im Browser anlegbar), und reicht Raster dann
# vollständig ein: Store-Build, Texte/Screenshots/Preis/Verfügbarkeit, Upload, Build anhängen, Einreichen.
# Protokoll: ~/.appstore-raster/submit.log
set -uo pipefail
cd "$(dirname "$0")/.."
source ~/.appstore-raster/env.sh
LOG=~/.appstore-raster/submit.log
step() { echo "$(date '+%d.%m. %H:%M') ▸ $*" | tee -a "$LOG"; }

step "Warte auf den App-Eintrag für com.vllasa.raster …"
for i in $(seq 1 1440); do   # bis zu 48 Stunden, alle 2 Minuten
    uv run -q scripts/asc_submit.py status >/dev/null 2>&1 && break
    sleep 120
done
uv run -q scripts/asc_submit.py status >/dev/null 2>&1 || { step "Kein App-Eintrag nach 48 Stunden – Abbruch"; exit 2; }
step "App-Eintrag gefunden"

run() { step "$1"; shift; "$@" >>"$LOG" 2>&1 || { step "✗ fehlgeschlagen: $*"; tail -25 "$LOG"; exit 1; }; }
run "Store-Build" scripts/build-appstore.sh
run "Texte, Kategorien, Alter, Preis, Verfügbarkeit, Screenshots, Prüfer-Infos" uv run -q scripts/asc_submit.py prepare
run "Upload über den Mac mit Xcode und Verarbeitung bei Apple" uv run -q scripts/asc_submit.py upload
run "Build an die Version hängen" uv run -q scripts/asc_submit.py attach
run "Vollständigkeit prüfen" uv run -q scripts/asc_submit.py check
run "Zur Prüfung einreichen" uv run -q scripts/asc_submit.py submit
step "✓ Eingereicht"
uv run -q scripts/asc_submit.py status | tee -a "$LOG"
