#!/bin/sh
# Copies every addon folder of the repo to the Windows PC's WoW Forever (ssh alias `winpc`),
# so the game there loads the working copy (/reload after). Each addon's folder on the PC is
# emptied first, so a file deleted or renamed here is gone there too.
#   tools/sync_pc.sh
# (the PC has no symlink to the repo, which lives on the Mac: a copy; see the winpc-remote skill)
set -e
DEST='C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns'
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
dirs=""
for dir in ImprovedForever*/; do
    name="${dir%/}"
    [ -f "$name/$name.toc" ] && dirs="$dirs $name"
done
[ -n "$dirs" ] || { echo "no addon folder found in $root"; exit 1; }
ssh -o ConnectTimeout=8 winpc "cd /d \"$DEST\"" >/dev/null || { echo "the PC isn't reachable (ssh winpc)"; exit 1; }
cmd=""
for name in $dirs; do
    cmd="$cmd if exist \"$DEST\\$name\" rmdir /s /q \"$DEST\\$name\" &"
done
ssh winpc "$cmd echo." >/dev/null
# shellcheck disable=SC2086
tar --exclude='.DS_Store' -czf - $dirs | ssh winpc "cd /d \"$DEST\" && tar -xzf -"
echo "synced to the PC:$dirs"
