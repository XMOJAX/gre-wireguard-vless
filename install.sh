#!/bin/bash
# ==============================================================================
#  ⚡ GRE + WireGuard + VLESS Manager (Pro Edition) - One-Line Installer
#  Author: MOJA (https://github.com/XMOJAX)
#  Repository: https://github.com/XMOJAX/gre-wireguard-vless
# ==============================================================================

set -e

# اتصال مجدد ورودی به ترمینال در صورت پایپ شدن (curl | bash)
if [ ! -t 0 ] && [ -e /dev/tty ]; then
    exec < /dev/tty
fi

# بررسی دسترسی روت / Check Root
if [ "$EUID" -ne 0 ]; then
  echo -e "\e[31m[ERROR] Please run this installer as root (use sudo)!\e[0m"
  echo -e "\e[31mلطفا این اسکریپت را با دسترسی روت اجرا کنید.\e[0m"
  exit 1
fi

clear
echo -e "\e[36m"
echo "  ╔═════════════════════════════════════════════════════════════════════╗"
echo "  ║         GRE + WireGuard + VLESS Manager - Auto Installer            ║"
echo "  ║                      Developed by MOJA                              ║"
echo "  ╚═════════════════════════════════════════════════════════════════════╝"
echo -e "\e[0m"

INSTALL_DIR="/usr/local/bin"
BIN_NAME="gwv"
SCRIPT_URL="https://raw.githubusercontent.com/XMOJAX/gre-wireguard-vless/main/gwv.sh"

echo -e "\e[33m[1/3] Downloading latest GRE + WireGuard + VLESS manager...\e[0m"
curl -fsSL "$SCRIPT_URL" -o "${INSTALL_DIR}/${BIN_NAME}"

echo -e "\e[33m[2/3] Setting executable permissions and global aliases...\e[0m"
chmod +x "${INSTALL_DIR}/${BIN_NAME}"
ln -sf "${INSTALL_DIR}/${BIN_NAME}" "${INSTALL_DIR}/gwv-tunnel"

# فعال‌سازی IPv4 Forwarding در صورت خاموش بودن
echo -e "\e[33m[3/3] Checking IP forwarding configuration...\e[0m"
if ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf 2>/dev/null; then
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1 || true
fi

echo -e "\n\e[1;32m═════════════════════════════════════════════════════════════════════\e[0m"
echo -e "\e[1;32m  ✔ Installation completed successfully! / نصب با موفقیت انجام شد!\e[0m"
echo -e "\e[1;32m═════════════════════════════════════════════════════════════════════\e[0m"
echo -e "  You can now run this tool anytime from anywhere by typing:"
echo -e "  از این پس می‌توانید با نوشتن یکی از دستورات زیر در ترمینال، اسکریپت را اجرا کنید:"
echo ""
echo -e "      \e[1;36msudo gwv\e[0m   or   \e[1;36msudo gwv-tunnel\e[0m"
echo ""

read -r -p "Would you like to run gwv right now? [y/N]: " RUN_NOW
if [[ "$RUN_NOW" =~ ^[yY]$ ]]; then
    exec "${INSTALL_DIR}/${BIN_NAME}"
fi
