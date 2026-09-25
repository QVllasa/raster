#!/bin/zsh
# Installiert dist/Raster.app nach /Applications und startet sie neu.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -d dist/Raster.app ]] || scripts/build-app.sh
pkill -x Raster 2>/dev/null && sleep 1 || true
rm -rf /Applications/Raster.app
ditto dist/Raster.app /Applications/Raster.app
open /Applications/Raster.app
echo "✓ Raster installiert und gestartet"
