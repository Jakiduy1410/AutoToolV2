#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="$ROOT/logs/auto_rejoin.log"
PIDFILE="$ROOT/logs/auto_rejoin.pid"
STATE="$ROOT/state.json"

mkdir -p "$ROOT/logs" "$ROOT/config"

ts(){ date "+%Y-%m-%d %H:%M:%S"; }
log(){
  local level="${2:-INFO}"
  echo "[$(ts)] [$level] $1" | tee -a "$LOG"
}

# ưu tiên đọc pkg từ config, nếu không có thì lấy arg1
PKG_FILE="$ROOT/config/game_package.txt"
PKG="${1:-}"
if [[ -z "${PKG}" && -f "$PKG_FILE" ]]; then
  PKG="$(tr -d '\r\n' < "$PKG_FILE" || true)"
fi

if [[ -z "${PKG}" ]]; then
  log "Missing package. Set it first (Menu [2]) or run: bash workflows/auto_rejoin.sh <package>" "ERR"
  exit 1
fi

echo "$$" > "$PIDFILE"
trap 'rm -f "$PIDFILE"; log "Auto Rejoin stopped" "OK"; exit 0' INT TERM

log "Auto Rejoin started pkg=$PKG" "OK"

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

pkg = d.get("package") if isinstance(d.get("package"), str) else ""
status = d.get("status") if isinstance(d.get("status"), str) else ""
issue = d.get("issue") if isinstance(d.get("issue"), str) else None
running_issue = d.get("running_issue") if isinstance(d.get("running_issue"), str) else None

parts = ["STATUS", status or "UNKNOWN"]
if pkg:
    parts.append(f"pkg={pkg}")
if issue:
    parts.append(f"issue={issue}")
if running_issue:
    parts.append(f"running_issue={running_issue}")

print(" ".join(parts))
PY
}

# rule: chỉ recover khi OFFLINE hoặc có ISSUE (NET_DOWN / DISCONNECT / STUCK)
should_recover() {
  case "$1" in
    STATUS\ OFFLINE*) return 0 ;;
    STATUS\ UNKNOWN*|NO_STATE|BAD_STATE) return 0 ;;
    *issue=*|*running_issue=*) return 0 ;;
    *) return 1 ;;
  esac
}

# loop nhẹ, tránh quá tải máy
INTERVAL=5
COOLDOWN=12
LAST_RECOVER=0

while true; do
  STATUS="$(read_status || true)"
  log "status=$STATUS"

  now="$(date +%s)"
  if should_recover "$STATUS"; then
    # cooldown chống spam recover
    if (( now - LAST_RECOVER >= COOLDOWN )); then
      LAST_RECOVER="$now"
      if [[ -f "$ROOT/workflows/recover.sh" ]]; then
        log "trigger recover for $PKG (status=$STATUS)" "RECOVER"
        bash "$ROOT/workflows/recover.sh" "$PKG" || true
      else
        log "workflows/recover.sh not found" "ERR"
      fi
    else
      log "recover skipped (cooldown)"
    fi
  fi

  sleep "$INTERVAL"
done
