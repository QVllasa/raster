#!/bin/zsh
# Beobachtet den App-Review-Status und endet, sobald Apple entschieden hat.
cd "$(dirname "$0")/.."
source ~/.appstore-raster/env.sh
last=""
for i in $(seq 1 864); do   # bis zu 72 Stunden, alle 5 Minuten
    s=$(uv run -q scripts/asc_submit.py status 2>/dev/null | tail -1)
    state=$(echo "$s" | python3 -c "import json,sys; print(json.load(sys.stdin)['state'])" 2>/dev/null || echo "?")
    if [[ "$state" != "$last" ]]; then echo "$(date '+%d.%m. %H:%M') Status: $state"; last="$state"; fi
    case "$state" in
        READY_FOR_SALE|READY_FOR_DISTRIBUTION|PENDING_DEVELOPER_RELEASE|PENDING_APPLE_RELEASE|PROCESSING_FOR_APP_STORE|REJECTED|METADATA_REJECTED|DEVELOPER_REJECTED|INVALID_BINARY|REMOVED_FROM_SALE)
            echo "ENTSCHEIDUNG: $state"; exit 0;;
    esac
    sleep 300
done
echo "TIMEOUT nach 72 Stunden, letzter Status: $last"
