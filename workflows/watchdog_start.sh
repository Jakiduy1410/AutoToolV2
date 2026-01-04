#!/data/data/com.termux/files/usr/bin/bash
set -e

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="$BASE_DIR/logs"
PID_FILE="$LOG_DIR/watchdog.pid"

mkdir -p "$LOG_DIR"

# Optional: pkg as arg
PKG="${1:-}"

# If running already, do nothing
if [ -f "$PID_FILE" ]; then
  PID="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
    echo "[OK] Watchdog already running pid=$PID"
    exit 0
  fi
fi

cd "$BASE_DIR"

# Start watchdog in background, keep logs inside watchdog.log (python already writes file)
if [ -n "$PKG" ]; then
  nohup python engine/watchdog.py "$PKG" >/dev/null 2>&1 &
else
  nohup python engine/watchdog.py >/dev/null 2>&1 &
fi

echo $! > "$PID_FILE"
echo "[OK] Watchdog started pid=$(cat "$PID_FILE")"
