#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

PKG="${1:-}"
if [[ -z "$PKG" ]]; then
  echo "[ERR] Usage: bash workflows/recover.sh <package>"
  exit 2
fi

BASE="/sdcard/Download/AutoToolV2"
LOG="$BASE/logs/recover.log"
mkdir -p "$BASE/logs"

ts() { date "+%Y-%m-%d %H:%M:%S"; }
log() { echo "[$(ts)] $*" | tee -a "$LOG"; }

log "[RECOVER] start pkg=$PKG"

# 1) Force-stop (kill sạch)
log "[RECOVER] am force-stop $PKG"
su -c "am force-stop $PKG" || true
sleep 2

# 2) Kill phụ trợ theo PID (KHÔNG dùng pkill -f để tránh tự kill script)
PIDS="$(pidof "$PKG" 2>/dev/null || true)"
if [[ -n "$PIDS" ]]; then
  log "[RECOVER] still has pid(s)=$PIDS -> kill -9"
  su -c "kill -9 $PIDS" || true
  sleep 1
fi

# 3) Verify stopped
if pidof -s "$PKG" >/dev/null 2>&1; then
  PID_NOW="$(pidof -s "$PKG" || true)"
  log "[WARN] still running pid=$PID_NOW after stop"
else
  log "[OK] stopped"
fi

# 4) Launch lại
log "[RECOVER] launch via monkey"
su -c "monkey -p $PKG -c android.intent.category.LAUNCHER 1" >/dev/null 2>&1 || true

# 5) Wait + verify started
sleep 4
PID_NEW="$(pidof -s "$PKG" || true)"
if [[ -n "$PID_NEW" ]]; then
  log "[OK] relaunched pid=$PID_NEW"
  exit 0
else
  log "[ERR] relaunch failed (no pid)"
  exit 1
fi
