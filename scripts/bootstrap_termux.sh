#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "======================================"
echo "[ AutoToolV2 ] Bootstrap Termux - Phase 0"
echo "======================================"

### 1. Check Termux
if [ -z "$PREFIX" ]; then
  echo "[ERROR] Not running inside Termux."
  exit 1
fi

### 2. Update system
echo "[*] Updating Termux packages..."
pkg update -y && pkg upgrade -y

### 3. Install required packages
echo "[*] Installing dependencies..."
pkg install -y \
  python \
  git \
  rsync \
  procps \
  iproute2 \
  coreutils \
  tsu \
  python-psutil

echo "[*] Installing python libs (safe)..."
pip install --no-deps requests

### 4. Setup storage
echo "[*] Setting up shared storage..."
termux-setup-storage
sleep 2

RUNTIME_DIR="/sdcard/Download/AutoTool"
LOG_DIR="$RUNTIME_DIR/logs"

mkdir -p "$LOG_DIR"

### 5. Root check
echo "[*] Checking root access..."
if ! su -c id >/dev/null 2>&1; then
  echo "[ERROR] Root not available. Abort."
  exit 1
fi
echo "[OK] Root access confirmed."

### 6. Fix Phantom Process Killer (Android 12+)
echo "[*] Applying Phantom Process Killer fix (one-time)..."
su -c "/system/bin/device_config set_sync_disabled_for_tests none"
su -c "/system/bin/device_config put activity_manager max_phantom_processes 2147483647"
su -c "settings put global settings_enable_monitor_phantom_procs false"

### 7. Basic write test
TEST_LOG="$LOG_DIR/bootstrap_test.log"
echo "[TEST] $(date) Bootstrap write test OK" > "$TEST_LOG"

if [ ! -f "$TEST_LOG" ]; then
  echo "[ERROR] Cannot write to runtime directory."
  exit 1
fi

### 8. Summary
echo "--------------------------------------"
echo "[DONE] Bootstrap completed successfully"
echo "Runtime directory : $RUNTIME_DIR"
echo "Log test file     : $TEST_LOG"
echo "--------------------------------------"
echo "Next step: Phase 1 – UI Skeleton"
