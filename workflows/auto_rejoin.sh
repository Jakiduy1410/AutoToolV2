#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="$ROOT/logs/auto_rejoin.log"
PIDFILE="$ROOT/logs/auto_rejoin.pid"
STATE="$ROOT/state.json"

mkdir -p "$ROOT/logs" "$ROOT/config"

ts(){ date "+%Y-%m-%d %H:%M:%S"; }
log(){ echo "[$(ts)] $*" | tee -a "$LOG"; }

# ưu tiên đọc pkg từ config, nếu không có thì lấy arg1
PKG_FILE="$ROOT/config/game_package.txt"
PKG="${1:-}"
if [[ -z "${PKG}" && -f "$PKG_FILE" ]]; then
  PKG="$(tr -d '\r\n' < "$PKG_FILE" || true)"
fi

if [[ -z "${PKG}" ]]; then
  log "[ERR] Missing package. Set it first (Menu [2]) or run: bash workflows/auto_rejoin.sh <package>"
  exit 1
fi

echo "$$" > "$PIDFILE"
trap 'rm -f "$PIDFILE"; log "[OK] Auto Rejoin stopped"; exit 0' INT TERM

log "[OK] Auto Rejoin started pkg=$PKG"

# đảm bảo watchdog đang chạy (nếu m đã có watchdog_start.sh)
if [[ -f "$ROOT/workflows/watchdog_start.sh" ]]; then
  bash "$ROOT/workflows/watchdog_start.sh" "$PKG" >/dev/null 2>&1 || true
fi

# đọc status từ state.json (không phụ thuộc format quá cứng)
read_status() {
  python - <<'PY' "$STATE"
import json, sys, os
p=sys.argv[1]
if not os.path.exists(p):
    print("NO_STATE"); raise SystemExit
try:
    d=json.load(open(p,"r",encoding="utf-8"))
except Exception:
    print("BAD_STATE"); raise SystemExit

# ưu tiên vài key phổ biến
for k in ["status","confirmed","confirmed_state","state"]:
    if k in d and isinstance(d[k], str):
        print(d[k]); raise SystemExit

# fallback: nếu có "running_issue" hay "issue"
if "running_issue" in d and isinstance(d["running_issue"], str):
    print("RUNNING_ISSUE_"+d["running_issue"]); raise SystemExit
if "issue" in d and isinstance(d["issue"], str):
    print("RUNNING_ISSUE_"+d["issue"]); raise SystemExit

print("UNKNOWN")
PY
}

# rule: chỉ recover khi OFFLINE hoặc có ISSUE (NET_DOWN / DISCONNECT / STUCK)
should_recover() {
  case "$1" in
    OFFLINE|NO_STATE|BAD_STATE) return 0 ;;
    RUNNING_ISSUE*|*NET_DOWN*|*DISCONNECT*|*STUCK*) return 0 ;;
    *) return 1 ;;
  esac
}

# loop nhẹ, tránh quá tải máy
INTERVAL=5
COOLDOWN=12
LAST_RECOVER=0

while true; do
  STATUS="$(read_status || true)"
  log "[INFO] status=$STATUS"

  now="$(date +%s)"
  if should_recover "$STATUS"; then
    # cooldown chống spam recover
    if (( now - LAST_RECOVER >= COOLDOWN )); then
      LAST_RECOVER="$now"
      if [[ -f "$ROOT/workflows/recover.sh" ]]; then
        log "[RECOVER] trigger recover for $PKG (status=$STATUS)"
        bash "$ROOT/workflows/recover.sh" "$PKG" || true
      else
        log "[ERR] workflows/recover.sh not found"
      fi
    else
      log "[INFO] recover skipped (cooldown)"
    fi
  fi

  sleep "$INTERVAL"
done

