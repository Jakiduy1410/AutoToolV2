#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$ROOT/config" "$ROOT/logs"
echo "[INFO] TODO Phase sau. Tạm thời: tạo config/game_package.txt thủ công."
echo -n "Enter package (vd: com.zamdepzai.clienv): "
read -r pkg
echo "$pkg" > "$ROOT/config/game_package.txt"
echo "[OK] Saved to config/game_package.txt"
