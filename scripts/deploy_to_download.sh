#!/data/data/com.termux/files/usr/bin/bash
set -e

SRC="$HOME/AutoToolV2"
DST="/sdcard/Download/AutoToolV2"

echo "[*] Syncing code to Download..."

mkdir -p "$DST"

rsync -a --delete \
  "$SRC/" "$DST/" \
  --exclude .git \
  --exclude logs \
  --exclude runtime

echo "[DONE] Code synced to $DST"
