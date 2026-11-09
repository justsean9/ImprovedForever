#!/bin/bash
# Copy the PC's taint log (WoW Forever: /console taintLog 1 in game) to logs/taint/ on this Mac,
# one file per pull, stamped. The game restarts the log on every /reload while it is on,
# so pull before reloading.
set -e
SRC='C:/Program Files (x86)/World of Warcraft/_forever_/Logs/taint.log'
DIR="$(cd "$(dirname "$0")/.." && pwd)/logs/taint"
mkdir -p "$DIR"
OUT="$DIR/taint-$(date +%Y%m%d-%H%M%S).log"
scp -q "winpc:$SRC" "$OUT" 2>/dev/null || { echo "no taint.log on the PC (taintLog off, or the PC is off)"; rm -f "$OUT"; exit 1; }
echo "$OUT ($(wc -l < "$OUT") lines)"
grep -E "ImprovedForever|forbidden|blocked" "$OUT" | head -20
