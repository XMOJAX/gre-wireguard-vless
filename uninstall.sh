#!/bin/bash
# ==============================================================================
#  ⚡ GRE + WireGuard + VLESS Manager - Uninstaller
#  Author: MOJA (https://github.com/XMOJAX)
# ==============================================================================

if [ "$EUID" -ne 0 ]; then
  echo -e "\e[31mPlease run as root (use sudo)\e[0m"
  exit 1
fi

rm -f /usr/local/bin/gwv
rm -f /usr/local/bin/gwv-tunnel

echo -e "\e[1;32m✔ gwv has been cleanly removed from /usr/local/bin.\e[0m"
