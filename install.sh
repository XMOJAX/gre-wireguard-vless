#!/bin/bash
# ==============================================================================
#  ⚡ GRE + WireGuard + VLESS Manager (Pro Edition) - Instant Launcher
#  Author: MOJA (https://github.com/XMOJAX)
#  Repository: https://github.com/XMOJAX/gre-wireguard-vless
# ==============================================================================

set -e

# اتصال به ترمینال در صورت پایپ شدن
if [ ! -t 0 ] && [ -e /dev/tty ]; then
    exec < /dev/tty
fi

# بررسی روت
if [ "$EUID" -ne 0 ]; then
  echo -e "\e[31mPlease run as root (use sudo)\e[0m"
  exit 1
fi

INSTALL_DIR="/usr/local/bin"
BIN_NAME="gwv"
SCRIPT_URL="https://raw.githubusercontent.com/XMOJAX/gre-wireguard-vless/main/gwv.sh"

# دانلود سریع و قرار دادن به عنوان دستور سیستمی سراسری
curl -fsSL "$SCRIPT_URL" -o "${INSTALL_DIR}/${BIN_NAME}"
chmod +x "${INSTALL_DIR}/${BIN_NAME}"
ln -sf "${INSTALL_DIR}/${BIN_NAME}" "${INSTALL_DIR}/gwv-tunnel"

# فعال‌سازی IPv4 Forwarding
if ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf 2>/dev/null; then
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1 || true
fi

# ورود مستقیم و بدون معطلی به منوی اصلی برنامه
exec "${INSTALL_DIR}/${BIN_NAME}" "$@"
