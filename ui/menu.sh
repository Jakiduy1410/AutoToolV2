#!/data/data/com.termux/files/usr/bin/bash

# ===== Colors =====
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
WHITE="\033[1;37m"
RESET="\033[0m"

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
read choice

echo
case "$choice" in
  1)
    bash workflows/auto_rejoin.sh
    ;;
  2)
    bash workflows/setup_game_id.sh
    ;;
  3)
    bash workflows/auto_login_cookie.sh
    ;;
  4)
    bash workflows/enable_webhook.sh
    ;;
  5)
    bash workflows/check_user_setup.sh
    ;;
  6)
    bash workflows/set_package_prefix.sh
    ;;
  7)
    bash workflows/change_android_id.sh
    ;;
  0)
    echo -e "${GREEN}Bye.${RESET}"
    exit 0
    ;;
  *)
    echo -e "${RED}[ERROR] Invalid choice${RESET}"
    ;;
esac

echo
read -p "Press Enter to return..."
bash "$0"
