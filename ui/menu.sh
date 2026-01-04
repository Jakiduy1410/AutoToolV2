#!/data/data/com.termux/files/usr/bin/bash

# =========================
# AutoToolV2 - Main Menu
# (hardened path + workflow runner)
# =========================

# --- lock terminal size to avoid UI drift (Termux floating/split/keyboard) ---
cols=$(tput cols 2>/dev/null || echo 80)
lines=$(tput lines 2>/dev/null || echo 24)

# clamp (Termux sometimes returns absurd values)
[ "$cols" -gt 160 ] && cols=120
[ "$cols" -lt 60 ]  && cols=80
[ "$lines" -gt 60 ] && lines=35
[ "$lines" -lt 20 ] && lines=24

export COLUMNS="$cols" LINES="$lines"
stty cols "$cols" rows "$lines" 2>/dev/null || true

# ===== Colors =====
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
WHITE="\033[1;37m"
RESET="\033[0m"

# =========================
# Resolve project root + workflows dir (chống lệch cwd)
# =========================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WF_DIR="$ROOT_DIR/workflows"

list_workflows() {
  echo -e "${CYAN}Available workflows in:${RESET} ${WF_DIR}"
  ls -1 "$WF_DIR"/*.sh 2>/dev/null | sed 's#.*/##' || echo "(none)"
}

run_wf() {
  local name="$1"
  local f="$WF_DIR/$name"

  if [ ! -f "$f" ]; then
    echo -e "${RED}[ERROR] Missing file:${RESET} workflows/$name"
    list_workflows
    return 1
  fi

  # ZArchiver hay làm mất quyền exec -> set lại
  if [ ! -x "$f" ]; then
    chmod +x "$f" 2>/dev/null || true
  fi

  bash "$f"
}

pause_return() {
  echo
  read -p "Press Enter to return..." _
}

while true; do
  clear
  echo -e "${CYAN}==============================================${RESET}"
  echo -e "${CYAN}        AutoToolV2  -  Main Menu               ${RESET}"
  echo -e "${CYAN}==============================================${RESET}"
  echo
  echo -e "${YELLOW}[1]${WHITE} Start Auto Rejoin ${BLUE}(Auto setup User ID)${RESET}"
  echo -e "${YELLOW}[2]${WHITE} Setup Game ID for Packages${RESET}"
  echo -e "${YELLOW}[3]${WHITE} Auto Login with Cookie${RESET}"
  echo -e "${YELLOW}[4]${WHITE} Enable Discord Webhook${RESET}"
  echo -e "${YELLOW}[5]${WHITE} Auto Check User Setup${RESET}"
  echo -e "${YELLOW}[6]${WHITE} Configure Package Prefix${RESET}"
  echo -e "${YELLOW}[7]${WHITE} Auto Change Android ID${RESET}"
  echo
  echo -e "${RED}[0] Exit${RESET}"
  echo
  echo -ne "${GREEN}Enter command:${RESET} "
  read -r choice

  echo
  case "$choice" in
    1)
      # start watchdog first (silent), then auto rejoin
      run_wf "watchdog_start.sh" >/dev/null 2>&1
      run_wf "auto_rejoin.sh"
      pause_return
      ;;
    2)
      run_wf "setup_game_id.sh"
      pause_return
      ;;
    3)
      run_wf "auto_login_cookie.sh"
      pause_return
      ;;
    4)
      run_wf "enable_discord_webhook.sh"
      pause_return
      ;;
    5)
      run_wf "check_user_setup.sh"
      pause_return
      ;;
    6)
      # tên đúng trong workflows của m là configure_prefix.sh
      run_wf "configure_prefix.sh"
      pause_return
      ;;
    7)
      run_wf "change_android_id.sh"
      pause_return
      ;;
    0)
      run_wf "watchdog_stop.sh" >/dev/null 2>&1
      echo -e "${GREEN}Bye.${RESET}"
      exit 0
      ;;
    *)
      echo -e "${RED}[ERROR] Invalid choice${RESET}"
      pause_return
      ;;
  esac
done
