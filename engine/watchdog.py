#!/usr/bin/env python3
import os
import re
import json
import time
import signal
import subprocess
from pathlib import Path
from typing import Optional, Tuple

# =======================
# CONFIG (Phase 2.3)
# =======================
SLOW_INTERVAL_SEC = 20          # nhẹ máy để treo đêm
OFFLINE_STREAK_NEED = 2         # mất PID 2 vòng liên tiếp => OFFLINE confirmed
PING_FAIL_STREAK_NEED = 2       # ping fail 2 vòng liên tiếp => NET_DOWN
RECOVER_COOLDOWN_SEC = 120      # sau khi recover, cooldown 120s tránh loop kill
GRACE_PERIOD_SEC = 45           # sau khi relaunch, bỏ qua detect offline trong khoảng này
CIRCUIT_WINDOW_SEC = 300        # cửa sổ thời gian cho circuit breaker (5 phút)
CIRCUIT_MAX_RECOVERS = 3        # quá số lần recover trong cửa sổ => mở circuit breaker
NET_UNSTABLE_HISTORY = 6        # số mẫu net để xác định flapping
NET_UNSTABLE_COOLDOWN = 240     # cooldown khi mạng chập chờn

# Logcat scan: mỗi vòng chỉ dump ít dòng
LOGCAT_TAIL_LINES = 250

# Detect disconnect patterns (279 / network disconnect)
DISCONNECT_PATTERNS = [
    r"error\s*code\s*279",
    r"\b279\b.*disconnect",
    r"disconnect.*\b279\b",
    r"Sending disconnect with reason:\s*279",
    r"Client:Disconnect",
]

DEBUG = os.environ.get("AUTOTOOL_DEBUG", "").strip().lower() in {"1", "true", "yes", "on", "debug"}
CLONE_ID = os.environ.get("AUTOTOOL_CLONE", "").strip() or "default"

# =======================
# PATHS
# =======================
ENGINE_DIR = Path(__file__).resolve().parent
BASE_DIR = ENGINE_DIR.parent
LOG_DIR = BASE_DIR / "logs"
LOG_DIR.mkdir(parents=True, exist_ok=True)

RUNTIME_DIR = BASE_DIR / "runtime"
RUNTIME_DIR.mkdir(parents=True, exist_ok=True)

WATCHDOG_LOG = LOG_DIR / "watchdog.log"
STATE_FILE = BASE_DIR / "state.json"

# =======================
# UTIL
# =======================
def ts() -> str:
    return time.strftime("%Y-%m-%d %H:%M:%S")

def log(msg: str, level: str = "INFO") -> None:
    line = f"[{ts()}] [{level}] {msg}"
    # print to stdout (in case user runs foreground)
    print(line, flush=True)
    # append to file
    with WATCHDOG_LOG.open("a", encoding="utf-8") as f:
        f.write(line + "\n")

def log_event(payload: dict) -> None:
    try:
        line = json.dumps(payload, ensure_ascii=False)
    except Exception:
        line = f"{ts()} {payload}"
    with EVENTS_LOG.open("a", encoding="utf-8") as f:
        f.write(line + "\n")

def run_cmd(cmd: str, timeout: int = 10) -> Tuple[int, str]:
    """Run shell command and return (rc, stdout+stderr)."""
    try:
        p = subprocess.run(
            cmd,
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=timeout,
            text=True
        )
        return p.returncode, (p.stdout or "")
    except subprocess.TimeoutExpired:
        return 124, "TIMEOUT"
    except Exception as e:
        return 1, f"EXCEPTION: {e}"

def su(cmd: str, timeout: int = 10) -> Tuple[int, str]:
    """Run command as root via su -c."""
    safe = cmd.replace('"', '\\"')
    return run_cmd(f'su -c "{safe}"', timeout=timeout)

def write_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

def get_pid(pkg: str) -> Optional[int]:
    rc, out = run_cmd(f"pidof -s {pkg}", timeout=3)
    if rc != 0:
        return None
    out = out.strip()
    if not out:
        return None
    try:
        return int(out)
    except:
        return None

def ping_ok() -> bool:
    # -W 1: wait 1 sec; -c 1: 1 packet
    rc, _ = run_cmd("ping -c 1 -W 1 1.1.1.1 >/dev/null 2>&1", timeout=3)
    return rc == 0

def has_default_route() -> bool:
    rc, out = run_cmd("ip route get 1.1.1.1 2>/dev/null | head -n1", timeout=4)
    return rc == 0 and bool(out.strip())

def dns_resolve_ok(host: str = "dns.google") -> bool:
    import socket
    try:
        socket.gethostbyname(host)
        return True
    except Exception:
        return False

def http_head_ok(url: str = "https://clients3.google.com/generate_204") -> bool:
    rc, out = run_cmd(f"curl -I -m 4 -s -o /dev/null -w \"%{{http_code}}\" {url}", timeout=6)
    if rc != 0:
        # nếu thiếu curl hoặc bị chặn, coi như không chắc (tránh false fail)
        if "not found" in (out or "") or rc == 127:
            return True
        return False
    code = (out or "").strip()
    return code.startswith("204") or code.startswith("200")

def get_net_status(history: list) -> Tuple[str, dict]:
    status_detail = {
        "default_route": has_default_route(),
        "ping": ping_ok(),
        "dns": dns_resolve_ok(),
        "http": http_head_ok(),
    }

    if not status_detail["default_route"]:
        net_status = "NO_ROUTE"
    elif not status_detail["dns"]:
        net_status = "DNS_FAIL"
    elif status_detail["http"]:
        net_status = "NET_OK"
    elif status_detail["ping"]:
        net_status = "NET_DEGRADED"
    else:
        net_status = "NET_DOWN"

    history.append(net_status)
    if len(history) > NET_UNSTABLE_HISTORY:
        history.pop(0)

    if len(set(history[-NET_UNSTABLE_HISTORY:])) > 2:
        net_status = "NET_UNSTABLE"

    return net_status, status_detail

def is_protected_package(pkg: str) -> bool:
    return pkg in {"com.termux", "com.termux.x11", "com.termux.x11.debug"}

def resumed_contains_pkg(pkg: str) -> bool:
    rc, out = su("dumpsys activity activities | grep -m 1 mResumedActivity", timeout=4)
    if rc != 0 or not out:
        return False
    return pkg in out

def read_oom_score(pid: Optional[int]) -> Optional[int]:
    if pid is None:
        return None
    try:
        val = Path(f"/proc/{pid}/oom_score").read_text(encoding="utf-8").strip()
        return int(val)
    except Exception:
        return None

def logcat_has_disconnect(pkg: str) -> bool:
    # Dump logcat tail and grep patterns. Root is safer.
    # Using -v brief for smaller output.
    rc, out = su(f"logcat -v brief -d -t {LOGCAT_TAIL_LINES}", timeout=12)
    if rc != 0 or not out.strip():
        return False

    # Light filter first: only keep lines mentioning Roblox or pkg or disconnect keywords
    # to reduce false positives
    hay = out
    # hard patterns check
    for pat in DISCONNECT_PATTERNS:
        if re.search(pat, hay, flags=re.IGNORECASE):
            return True
    return False

def trigger_recover(pkg: str, reason: str) -> int:
    # ALWAYS run with bash (sdcard noexec)
    recover_sh = BASE_DIR / "workflows" / "recover.sh"
    if not recover_sh.exists():
        log(f"recover.sh not found at {recover_sh}", "ERR")
        return 2

    log(f"TRIGGER recover reason={reason} pkg={pkg}", "WARN")
    # redirect recover output to its own log file
    recover_log = LOG_DIR / "recover_trigger.log"
    cmd = f"bash {recover_sh} {pkg} >> {recover_log} 2>&1"
    rc, _ = run_cmd(cmd, timeout=120)
    if rc == 0:
        log(f"recover done OK (reason={reason})", "OK")
    else:
        log(f"recover FAILED rc={rc} (reason={reason})", "ERR")
    return rc

def read_pkg_from_state() -> Optional[str]:
    # Try common config file names without assuming structure too much
    candidates = [
        STATE_FILE,
        BASE_DIR / "state.json",
        BASE_DIR / "config.json",
        BASE_DIR / "configs" / "state.json",
    ]
    for p in candidates:
        if p.exists():
            try:
                data = json.loads(p.read_text(encoding="utf-8"))
                # Try common keys
                for key in ["package", "pkg", "target_package", "package_name"]:
                    val = data.get(key)
                    if isinstance(val, str) and val.strip():
                        return val.strip()
                # Try packages list
                pkgs = data.get("packages")
                if isinstance(pkgs, list) and pkgs:
                    for v in pkgs:
                        if isinstance(v, str) and v.strip():
                            return v.strip()
            except:
                pass
    return None

# =======================
# MAIN LOOP
# =======================
STOP = False

def handle_stop(sig, frame):
    global STOP
    STOP = True

signal.signal(signal.SIGINT, handle_stop)
signal.signal(signal.SIGTERM, handle_stop)

def main():
    # package priority: argv > env > state.json
    import sys
    pkg = None
    if len(sys.argv) >= 2:
        pkg = sys.argv[1].strip()
    if not pkg:
        pkg = os.environ.get("AUTOTOOL_PKG", "").strip() or None
    if not pkg:
        pkg = read_pkg_from_state()
    if not pkg:
        log("No package specified. Run: python engine/watchdog.py <package>", "ERR")
        return 2

    log(f"Watchdog started (PID + LOGCAT + NET CHECK) pkg={pkg}", "INFO")
    if DEBUG:
        log("Debug mode enabled via AUTOTOOL_DEBUG", "DBG")

    last_state = None
    last_recover_at = 0.0
    recover_history = []  # timestamps (epoch) for circuit breaker
    circuit_open = False
    grace_until = 0.0
    net_history: list = []

    def persist_cooldown_state():
        data = {
            "clone_id": CLONE_ID,
            "package": pkg,
            "last_recover_at": last_recover_at,
            "grace_until": grace_until,
            "circuit_open": circuit_open,
            "recover_history": recover_history[-CIRCUIT_MAX_RECOVERS:],
        }
        try:
            write_json(COOLDOWN_FILE, data)
        except Exception as e:
            log(f"Failed to write cooldown.json: {e}", "ERR")

    def record_state(status: str, issue: Optional[str] = None, running_issue: Optional[str] = None, level: str = "INFO"):
        nonlocal last_state
        state_tuple = (status, issue or None, running_issue or None)
        if last_state == state_tuple:
            return
        last_state = state_tuple

        payload = {
            "package": pkg,
            "clone_id": CLONE_ID,
            "status": status,
            "issue": issue or None,
            "running_issue": running_issue or None,
        }

        try:
            write_json(STATE_FILE, payload)
            if CLONE_ID == "default":
                write_json(STATE_COMPAT_FILE, payload)
        except Exception as e:
            log(f"Failed to write state.json: {e}", "ERR")

        issue_text = payload["issue"] if payload["issue"] is not None else "-"
        running_text = payload["running_issue"] if payload["running_issue"] is not None else "-"
        log(f"STATE pkg={pkg} status={status} issue={issue_text} running_issue={running_text}", level)

    last_state = None

    def record_state(status: str, issue: Optional[str] = None, running_issue: Optional[str] = None, level: str = "INFO"):
        nonlocal last_state
        state_tuple = (status, issue or None, running_issue or None)
        if last_state == state_tuple:
            return
        last_state = state_tuple

        payload = {
            "package": pkg,
            "status": status,
            "issue": issue or None,
            "running_issue": running_issue or None,
        }

        try:
            STATE_FILE.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
        except Exception as e:
            log(f"Failed to write state.json: {e}", "ERR")

        issue_text = payload["issue"] if payload["issue"] is not None else "-"
        running_text = payload["running_issue"] if payload["running_issue"] is not None else "-"
        log(f"STATE pkg={pkg} status={status} issue={issue_text} running_issue={running_text}", level)

    offline_streak = 0
    ping_fail_streak = 0
    last_recover_at = 0.0

    while not STOP:
        now = time.time()
        pid = get_pid(pkg)
        resumed = resumed_contains_pkg(pkg)
        oom_score = read_oom_score(pid)

        # OFFLINE debounce
        if pid is None:
            offline_streak += 1
        else:
            offline_streak = 0

        # NET status
        net_status, net_detail = get_net_status(net_history)
        if net_status in {"NET_DOWN", "NET_DEGRADED"}:
            ping_fail_streak += 1
        else:
            ping_fail_streak = 0

        # Decide status
        now = time.time()

        # OFFLINE confirmed => recover
        if offline_streak >= OFFLINE_STREAK_NEED:
            record_state("OFFLINE", issue="OFFLINE", running_issue=None, level="WARN")

            if now - last_recover_at >= RECOVER_COOLDOWN_SEC:
                trigger_recover(pkg, "OFFLINE")
                last_recover_at = time.time()
            else:
                log(f"recover cooldown active ({int(RECOVER_COOLDOWN_SEC-(now-last_recover_at))}s left)", "INFO")

            time.sleep(SLOW_INTERVAL_SEC)
            continue

        # If app running, check disconnect via logcat (279)
        if pid is not None:
            if logcat_has_disconnect(pkg):
                record_state("RUNNING_ISSUE", issue="DISCONNECT_279", running_issue="DISCONNECT_279", level="WARN")

                if now - last_recover_at >= RECOVER_COOLDOWN_SEC:
                    trigger_recover(pkg, "DISCONNECT_279")
                    last_recover_at = time.time()
                else:
                    log(f"recover cooldown active ({int(RECOVER_COOLDOWN_SEC-(now-last_recover_at))}s left)", "INFO")

                time.sleep(SLOW_INTERVAL_SEC)
                continue

        # NET down: chỉ log (không recover)
        if ping_fail_streak >= PING_FAIL_STREAK_NEED:
            record_state("RUNNING_ISSUE", issue=None, running_issue="NET_DOWN", level="WARN")
        else:
            # if nothing wrong & previously had issues, mark OK once
            if pid is not None and ping_fail_streak == 0:
                record_state("RUNNING_OK", issue=None, running_issue=None, level="OK")
            elif pid is None and DEBUG:
                log(f"[DBG] pid=None ping_fail_streak={ping_fail_streak}", "DBG")

        time.sleep(SLOW_INTERVAL_SEC)

    record_state("STOPPED", issue=None, running_issue=None, level="INFO")
    log("Watchdog stopped", "INFO")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
