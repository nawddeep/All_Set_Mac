#!/bin/bash
# Pushes this Mac's rendered wallpaper assets to the home server.
#
# All six library folders are sent, because every one of them holds some
# catalog entries' actual `playback` file: live/ for scene loops, stills/
# for scene stills, extracted/ for video-texture and GIF scenes, transcoded/
# for files this Mac can't decode efficiently as shipped, and originals/ for
# plain videos — their self-contained copy *is* what plays (no second copy
# is made). originals/ holds nothing else: scene wallpapers never get a raw
# copy there. Twice this script skipped folders on the assumption they were
# pipeline scratch; both times that was wrong, and the offload's own server
# check is what caught it.
#
#   scripts/cloud/push_wallpapers.sh --dry-run   # list what would go, send nothing
#   scripts/cloud/push_wallpapers.sh             # send it
#
# Resumable and idempotent: rsync skips files already there with the same
# size and timestamp, so a re-run after an interrupted transfer picks up
# where it stopped. Nothing on the server is deleted (no --delete): a
# wallpaper removed here stays there until that's a deliberate decision.
set -euo pipefail

LIBRARY="$HOME/Library/Application Support/AllSet/Wallpaper/Library"
SERVER="allset-server"                      # ~/.ssh/config alias
REMOTE="AllSetStorage/wallpapers"           # relative to the server's home

DRY=""
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY="--dry-run"
    echo "DRY RUN — nothing will be transferred"
fi

for folder in live stills thumbnails extracted transcoded originals; do
    source_dir="$LIBRARY/$folder"
    if [[ ! -d "$source_dir" ]]; then
        echo "skipping $folder (not on this Mac)"
        continue
    fi
    count=$(find "$source_dir" -type f ! -name '.DS_Store' | wc -l | tr -d ' ')
    size=$(du -sh "$source_dir" | cut -f1)
    echo "==> $folder: $count files, $size"
    rsync -avh --progress --partial $DRY \
        --exclude '.DS_Store' \
        "$source_dir/" "$SERVER:$REMOTE/$folder/"
done

echo
echo "Done. Catalog metadata is separate — see scripts/cloud/sync_catalog.py."
