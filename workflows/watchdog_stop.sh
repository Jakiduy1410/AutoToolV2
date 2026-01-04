#!/data/data/com.termux/files/usr/bin/bash
set -e

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="$BASE_DIR/logs"
PID_FILE="$LOG_DIR/watchdog.pid"

if [ ! -f "$PID_FILE" ]; then
  echo "[OK] Watchdog not running (no pid file)"
  exit 0
fi

PID="$(cat "$PID_FILE" 2>/dev/null || true)"
if [ -z "$PID" ]; then
  rm -f "$PID_FILE"
  echo "[OK] Watchdog stopped (pid empty)"
  exit 0
fi

# Gentle stop
if kill -0 "$PID" 2>/dev/null; then
  kill "$PID" 2>/dev/null || true
  sleep 1
fi

# If still alive, force
if kill -0 "$PID" 2>/dev/null; then
  kill -9 "$PID" 2>/dev/null || true
fi

rm -f "$PID_FILE"
echo "[OK] Watchdog stopped"
