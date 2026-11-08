#!/bin/bash

# اتصال مجدد ورودی به ترمینال در صورت پایپ شدن (curl | bash)
if [ ! -t 0 ] && [ -e /dev/tty ]; then
    exec < /dev/tty
fi

# بررسی دسترسی روت
if [ "$EUID" -ne 0 ]; then
  echo -e "\e[31mPlease run as root (use sudo)\e[0m"
  exit 1
fi

# بررسی پیشنیازها با سیستم انتظار هوشمند
if ! command -v wg &> /dev/null || ! command -v curl &> /dev/null; then
    echo -e "\e[33mChecking dependencies... waiting for system locks to clear...\e[0m"
    while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
        sleep 2
    done
    apt-get update -yqq && apt-get install -yqq wireguard iproute2 curl
fi

get_free_udp_port() {
    local port=$1
    while ss -uln | grep -qE ":$port\b"; do ((port++)); done
    echo "$port"
}

get_free_tcp_port() {
    local port=$1
    while ss -tln | grep -qE ":$port\b"; do ((port++)); done
    echo "$port"
}

get_free_ip_prefix() {
    local base_prefix=$1
    local subnet=99
    while ip addr show | grep -q "${base_prefix}.${subnet}."; do
        ((subnet--))
    done
    echo "${base_prefix}.${subnet}"
}

# --- تابع ساخت سرویس دائمی (با اضافه شدن شناسه Key برای جلوگیری از تداخل لینوکس) ---
create_persistent_service() {
    local TNAME=$1
    local IP_L=$2
    local IP_R=$3
    local GRE_L=$4
    local G_MTU=$5
    local WG_P=$6

    cat <<EOF > /etc/systemd/system/gre-${TNAME}.service
[Unit]
Description=Persistent GRE Tunnel ${TNAME}
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/sbin/ip tunnel add gre-${TNAME} mode gre remote ${IP_R} local ${IP_L} key ${WG_P} ttl 255
ExecStart=/sbin/ip link set dev gre-${TNAME} mtu ${G_MTU}
ExecStart=/sbin/ip link set gre-${TNAME} up
ExecStart=/sbin/ip addr add ${GRE_L}/30 dev gre-${TNAME}
ExecStop=/sbin/ip link set gre-${TNAME} down
ExecStop=/sbin/ip tunnel del gre-${TNAME}

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable gre-${TNAME}.service >/dev/null 2>&1
    systemctl start gre-${TNAME}.service
    systemctl enable wg-quick@wg-${TNAME} >/dev/null 2>&1
}

# --- تابع پاک کردن تمیز سرویسها ---
remove_persistent_service() {
    local WG_IF=$1
    local GRE_IF=$2
    local SRV_NAME=$3

    systemctl stop wg-quick@${WG_IF} >/dev/null 2>&1
    systemctl disable wg-quick@${WG_IF} >/dev/null 2>&1
    systemctl stop ${SRV_NAME} >/dev/null 2>&1
    systemctl disable ${SRV_NAME} >/dev/null 2>&1
    rm -f /etc/systemd/system/${SRV_NAME}
    systemctl daemon-reload
}

while true; do
    clear
    echo -e "\e[36m================================================\e[0m"
    echo -e "\e[1;32m GRE + WireGuard + VLESS Manager (Pro Edition) \e[0m"
    echo -e "\e[36m================================================\e[0m"
    echo "1) Source Server (Iran / Outbound)"
    echo "2) Destination Server (Kharej / Inbound)"
    echo -e "\e[1;33m3) Manage / Delete Existing Tunnels (Cleanup)\e[0m"
    echo -e "\e[1;34m4) View Setup History & Tokens\e[0m"
    echo -e "\e[1;35m5) Test Tunnel Connections (Ping peers)\e[0m"
    echo -e "\e[1;36m6) Change MTU of an Existing Tunnel\e[0m"
    echo -e "\e[1;31m0) Exit\e[0m"
    echo -e "\e[36m------------------------------------------------\e[0m"
    
    if ! read -r -p "Select an option (0 to 6): " ROLE; then
        echo -e "\n\e[32mExiting...\e[0m"
        exit 0
    fi
    ROLE=$(echo "$ROLE" | tr -d '[:space:]')

    if [ -z "$ROLE" ]; then
        continue
    fi

    if [ "$ROLE" == "1" ]; then
        echo -e "\n\e[33mScanning system for free ports and IPs...\e[0m"
        
        EXT_IP=$(curl -s4 --connect-timeout 3 api.ipify.org 2>/dev/null || curl -s4 --connect-timeout 3 ifconfig.me 2>/dev/null || curl -s4 --connect-timeout 3 ipv4.icanhazip.com 2>/dev/null)
        LOCAL_IPS=($(ip -4 addr show scope global | awk '/inet / {print $2}' | cut -d/ -f1))
        
        IP_LIST=()
        [ -n "$EXT_IP" ] && IP_LIST+=("$EXT_IP")
        for ip in "${LOCAL_IPS[@]}"; do
            if [[ ! " ${IP_LIST[@]} " =~ " ${ip} " ]]; then
                IP_LIST+=("$ip")
            fi
        done

        echo -e "\n\e[36m--- Network Configuration ---\e[0m"
        
        # گرفتن نام اختصاصی از کاربر
        while true; do
            read -r -p "Enter a custom NAME for this tunnel (e.g., germany, game, vip1): " TUNNEL_NAME
            if [[ ! "$TUNNEL_NAME" =~ ^[a-zA-Z0-9_-]{1,10}$ ]]; then
                echo -e "\e[31mInvalid name! Use only letters, numbers, hyphens or underscores (max 10 chars).\e[0m"
                continue
            fi
            if ip link show "gre-${TUNNEL_NAME}" &>/dev/null || [ -f "/etc/wireguard/wg-${TUNNEL_NAME}.conf" ]; then
                echo -e "\e[31mTunnel with this name already exists. Choose another.\e[0m"
                continue
            fi
            break
        done

        if [ ${#IP_LIST[@]} -gt 0 ]; then
            echo -e "\nWhich one is your Source Public IP (Iran)?"
            for i in "${!IP_LIST[@]}"; do
                echo -e "  \e[33m$((i+1)))\e[0m \e[32m${IP_LIST[$i]}\e[0m"
            done
            echo -e "  \e[33m0)\e[0m \e[32mEnter a custom IP manually\e[0m"
            read -r -p "Select IP [1]: " IP_CHOICE
            IP_CHOICE=${IP_CHOICE:-1}
            
            if [[ "$IP_CHOICE" == "0" ]]; then
                read -r -p "Enter Source Public IP (Iran): " IP_IRAN
            elif [[ "$IP_CHOICE" =~ ^[0-9]+$ ]] && [ "$IP_CHOICE" -le "${#IP_LIST[@]}" ]; then
                IP_IRAN="${IP_LIST[$((IP_CHOICE-1))]}"
            else
                IP_IRAN="${IP_LIST[0]}"
            fi
        else
            read -r -p "Enter Source Public IP (Iran): " IP_IRAN
        fi

        RANDOM_WG_BASE=$(( 50000 + RANDOM % 9000 ))
        RANDOM_VLESS_BASE=$(( 40000 + RANDOM % 9000 ))

        SUGGESTED_GRE_PREFIX=$(get_free_ip_prefix "10.99")
        SUGGESTED_WG_PREFIX=$(get_free_ip_prefix "10.88")
        SUGGESTED_WG_PORT=$(get_free_udp_port $RANDOM_WG_BASE)
        SUGGESTED_VLESS_PORT=$(get_free_tcp_port $RANDOM_VLESS_BASE)

        echo -e "\n\e[36m(Press ENTER to use defaults in brackets)\e[0m"
        read -r -p "Enter Destination Public IP (Kharej): " IP_KHAREJ
        while [[ -z "$IP_KHAREJ" ]]; do
            read -r -p "Destination IP cannot be empty! Enter Destination Public IP: " IP_KHAREJ
        done

        read -r -p "Enter GRE IP for Iran [${SUGGESTED_GRE_PREFIX}.1]: " GRE_IRAN
        GRE_IRAN=${GRE_IRAN:-${SUGGESTED_GRE_PREFIX}.1}
        read -r -p "Enter GRE IP for Kharej [${SUGGESTED_GRE_PREFIX}.2]: " GRE_KHAREJ
        GRE_KHAREJ=${GRE_KHAREJ:-${SUGGESTED_GRE_PREFIX}.2}
        
        read -r -p "Enter WireGuard IP for Iran [${SUGGESTED_WG_PREFIX}.1]: " WG_IRAN
        WG_IRAN=${WG_IRAN:-${SUGGESTED_WG_PREFIX}.1}
        read -r -p "Enter WireGuard IP for Kharej [${SUGGESTED_WG_PREFIX}.2]: " WG_KHAREJ
        WG_KHAREJ=${WG_KHAREJ:-${SUGGESTED_WG_PREFIX}.2}

        read -r -p "Enter WireGuard Port [$SUGGESTED_WG_PORT]: " WG_PORT
        WG_PORT=${WG_PORT:-$SUGGESTED_WG_PORT}
        read -r -p "Enter VLESS Connection Port [$SUGGESTED_VLESS_PORT]: " VLESS_PORT
        VLESS_PORT=${VLESS_PORT:-$SUGGESTED_VLESS_PORT}
        read -r -p "Enter WireGuard MTU [1360]: " WG_MTU
        WG_MTU=${WG_MTU:-1360}

        PRIV_IRAN=$(wg genkey)
        PUB_IRAN=$(echo "$PRIV_IRAN" | wg pubkey)
        PRIV_KHAREJ=$(wg genkey)
        PUB_KHAREJ=$(echo "$PRIV_KHAREJ" | wg pubkey)
        UUID=$(cat /proc/sys/kernel/random/uuid)

        # قرار دادن اسم در توکن برای سرور مقصد
        RAW_TOKEN="${IP_IRAN}|${IP_KHAREJ}|${GRE_IRAN}|${GRE_KHAREJ}|${WG_IRAN}|${WG_KHAREJ}|${WG_PORT}|${PRIV_KHAREJ}|${PUB_IRAN}|${UUID}|${VLESS_PORT}|${WG_MTU}|${TUNNEL_NAME}"
        TOKEN=$(echo -n "$RAW_TOKEN" | base64 -w 0)

        echo -e "\n\e[36mConfiguring Tunnel: wg-${TUNNEL_NAME} & gre-${TUNNEL_NAME}...\e[0m"
        GRE_MTU=$((WG_MTU + 60))
        
        # ارسال پورت وایرگارد به عنوان Key برای تانل GRE
        create_persistent_service "$TUNNEL_NAME" "$IP_IRAN" "$IP_KHAREJ" "$GRE_IRAN" "$GRE_MTU" "$WG_PORT"

        cat <<EOF > /etc/wireguard/wg-${TUNNEL_NAME}.conf
[Interface]
PrivateKey = $PRIV_IRAN
Address = ${WG_IRAN}/30
ListenPort = $WG_PORT
MTU = $WG_MTU

[Peer]
PublicKey = $PUB_KHAREJ
Endpoint = ${GRE_KHAREJ}:${WG_PORT}
AllowedIPs = ${WG_KHAREJ}/32
PersistentKeepalive = 25
EOF
        wg-quick up wg-${TUNNEL_NAME} 2>/dev/null

        cat <<EOF >> tunnel_configs.txt
------------------------------------------------
[$(date)]
Role: Source (Iran -> Kharej) | Tunnel Name: $TUNNEL_NAME
Iran Interface IP: $IP_IRAN
Kharej Public IP: $IP_KHAREJ
WG Kharej IP: $WG_KHAREJ
WG Port: $WG_PORT | MTU: $WG_MTU
VLESS Port: $VLESS_PORT
UUID: $UUID
TOKEN:
$TOKEN
------------------------------------------------
EOF

        echo -e "\n\e[1;32m========================================================\e[0m"
        echo -e "Waiting for Destination server to connect..."
        echo -e "Copy this TOKEN and run the script on the Destination server:"
        echo -e "\e[1;32m========================================================\e[0m"
        echo -e "\n\e[1;33m$TOKEN\e[0m\n"
        
        echo -e "\e[1;36m>>> XRAY OUTBOUND SETUP FOR IRAN (Sanaei) <<<\e[0m"
        echo -e "  * Protocol:   \e[32mvless\e[0m"
        echo -e "  * Tag:        \e[32mTo-${TUNNEL_NAME}\e[0m"
        echo -e "  * Address:    \e[32m${WG_KHAREJ}\e[0m"
        echo -e "  * Port:       \e[32m${VLESS_PORT}\e[0m"
        echo -e "  * ID (UUID):  \e[32m${UUID}\e[0m"
        
        read -r -p $'\n\e[1;32m[!] Press ENTER to return to the main menu...\e[0m'

    elif [ "$ROLE" == "2" ]; then
        echo -e "\n\e[33m--- Awaiting Configuration Token ---\e[0m"
        read -r -p "Enter Token from Source Server: " TOKEN
        RAW_TOKEN=$(echo -n "$TOKEN" | base64 -d)

        IP_IRAN=$(echo "$RAW_TOKEN" | cut -d'|' -f1)
        IP_KHAREJ=$(echo "$RAW_TOKEN" | cut -d'|' -f2)
        GRE_IRAN=$(echo "$RAW_TOKEN" | cut -d'|' -f3)
        GRE_KHAREJ=$(echo "$RAW_TOKEN" | cut -d'|' -f4)
        WG_IRAN=$(echo "$RAW_TOKEN" | cut -d'|' -f5)
        WG_KHAREJ=$(echo "$RAW_TOKEN" | cut -d'|' -f6)
        WG_PORT=$(echo "$RAW_TOKEN" | cut -d'|' -f7)
        PRIV_KHAREJ=$(echo "$RAW_TOKEN" | cut -d'|' -f8)
        PUB_IRAN=$(echo "$RAW_TOKEN" | cut -d'|' -f9)
        UUID=$(echo "$RAW_TOKEN" | cut -d'|' -f10)
        VLESS_PORT=$(echo "$RAW_TOKEN" | cut -d'|' -f11)
        WG_MTU=$(echo "$RAW_TOKEN" | cut -d'|' -f12)
        WG_MTU=${WG_MTU:-1360}
        
        SUGGESTED_NAME=$(echo "$RAW_TOKEN" | cut -d'|' -f13)
        SUGGESTED_NAME=${SUGGESTED_NAME:-myvpn}
        
        echo -e "\n\e[36m--- Local Interface Configuration ---\e[0m"
        while true; do
            read -r -p "Enter a custom NAME for THIS server (Kharej) [$SUGGESTED_NAME]: " TUNNEL_NAME
            TUNNEL_NAME=${TUNNEL_NAME:-$SUGGESTED_NAME}
            
            if [[ ! "$TUNNEL_NAME" =~ ^[a-zA-Z0-9_-]{1,10}$ ]]; then
                echo -e "\e[31mInvalid name! Use only letters, numbers, hyphens or underscores (max 10 chars).\e[0m"
                continue
            fi
            if ip link show "gre-${TUNNEL_NAME}" &>/dev/null || [ -f "/etc/wireguard/wg-${TUNNEL_NAME}.conf" ]; then
                echo -e "\e[31mTunnel with this name already exists. Choose another.\e[0m"
                continue
            fi
            break
        done

        if ss -uln | grep -qE ":$WG_PORT\b"; then
            echo -e "\e[1;31m[WARNING] UDP Port $WG_PORT is already in use on this server!\e[0m"
        fi

        echo -e "\n\e[36mConfiguring Tunnel: wg-${TUNNEL_NAME} & gre-${TUNNEL_NAME} (MTU: $WG_MTU)...\e[0m"
        GRE_MTU=$((WG_MTU + 60))
        
        create_persistent_service "$TUNNEL_NAME" "$IP_KHAREJ" "$IP_IRAN" "$GRE_KHAREJ" "$GRE_MTU" "$WG_PORT"

        cat <<EOF > /etc/wireguard/wg-${TUNNEL_NAME}.conf
[Interface]
PrivateKey = $PRIV_KHAREJ
Address = ${WG_KHAREJ}/30
ListenPort = $WG_PORT
MTU = $WG_MTU

[Peer]
PublicKey = $PUB_IRAN
Endpoint = ${GRE_IRAN}:${WG_PORT}
AllowedIPs = ${WG_IRAN}/32
PersistentKeepalive = 25
EOF
        wg-quick up wg-${TUNNEL_NAME} 2>/dev/null

        cat <<EOF >> tunnel_configs.txt
------------------------------------------------
[$(date)]
Role: Destination (Kharej) | Tunnel Name: $TUNNEL_NAME
Iran Interface IP: $IP_IRAN
WG Kharej IP: $WG_KHAREJ
WG Port: $WG_PORT | MTU: $WG_MTU
VLESS Port: $VLESS_PORT
UUID: $UUID
------------------------------------------------
EOF

        echo -e "\n\e[33mRunning Connection Test...\e[0m"
        if ping -c 3 -W 2 $WG_IRAN > /dev/null 2>&1; then
            echo -e "\e[1;32m[OK] Tunnel connection is SUCCESSFUL!\e[0m"
            
            echo -e "\n\e[1;36m>>> XRAY INBOUND SETUP FOR KHAREJ (Sanaei) <<<\e[0m"
            echo -e "  * Remark:     \e[32mWG-Tunnel-${TUNNEL_NAME}-In\e[0m"
            echo -e "  * Listen IP:  \e[32m${WG_KHAREJ}\e[0m"
            echo -e "  * Port:       \e[32m${VLESS_PORT}\e[0m"
            echo -e "  * UUID:       \e[32m${UUID}\e[0m"
        else
            echo -e "\e[1;31m[ERROR] Connection Test FAILED!\e[0m"
        fi
        
        read -r -p $'\n\e[1;32m[!] Press ENTER to return to the main menu...\e[0m'

    elif [ "$ROLE" == "3" ]; then
        echo -e "\n\e[1;33m--- Manage & Delete Existing Tunnels ---\e[0m"
        
        echo -e "\n\e[36m[+] Scanning for WireGuard tunnels...\e[0m"
        WG_ARRAY=($(ls /etc/wireguard/*.conf 2>/dev/null | awk -F'/' '{print $NF}' | sed 's/.conf//g'))
        
        if [ ${#WG_ARRAY[@]} -eq 0 ]; then
            echo "No tunnels found to delete."
        else
            for i in "${!WG_ARRAY[@]}"; do
                echo -e "  \e[33m$((i+1)))\e[0m \e[32m${WG_ARRAY[$i]}\e[0m (Will also cleanly delete associated GRE Service)"
            done
            read -r -p "Enter tunnel number to delete (or press Enter to skip): " DEL_NUM
            
            if [[ "$DEL_NUM" =~ ^[0-9]+$ ]] && [ "$DEL_NUM" -ge 1 ] && [ "$DEL_NUM" -le "${#WG_ARRAY[@]}" ]; then
                DEL_WG="${WG_ARRAY[$((DEL_NUM-1))]}"
                
                # سازگاری با فرمت قدیمی wg1 و فرمت جدید wg-name
                if [[ "$DEL_WG" == wg-* ]]; then
                    TUNNEL_NAME="${DEL_WG#wg-}"
                    GRE_IF="gre-${TUNNEL_NAME}"
                    SRV_NAME="gre-${TUNNEL_NAME}.service"
                else
                    TUNNEL_NAME="${DEL_WG#wg}"
                    GRE_IF="gre${TUNNEL_NAME}"
                    SRV_NAME="gre${TUNNEL_NAME}-tunnel.service"
                fi
                
                remove_persistent_service "$DEL_WG" "$GRE_IF" "$SRV_NAME"
                rm -f "/etc/wireguard/${DEL_WG}.conf"
                echo -e "\e[1;32m[OK] Tunnel '$DEL_WG' and '$GRE_IF' completely stopped, disabled, and deleted.\e[0m"
            fi
        fi
        
        read -r -p $'\n\e[1;32m[!] Press ENTER to return to the main menu...\e[0m'

    elif [ "$ROLE" == "4" ]; then
        echo -e "\n\e[1;33m--- Setup History & Saved Tokens ---\e[0m"
        if [ -f "tunnel_configs.txt" ]; then
            cat tunnel_configs.txt
            read -r -p $'\n\e[1;32m[!] Press ENTER to return, or type "C" to clear history: \e[0m' CLEAR_OPT
            if [[ "${CLEAR_OPT^^}" == "C" ]]; then
                rm -f tunnel_configs.txt
                echo -e "\e[32mHistory cleared successfully.\e[0m"
                sleep 1
            fi
        else
            echo -e "\n\e[31mNo previous configuration history found.\e[0m"
            read -r -p $'\n\e[1;32m[!] Press ENTER to return to the main menu...\e[0m'
        fi

    elif [ "$ROLE" == "5" ]; then
        echo -e "\n\e[1;35m--- Test Tunnel Connections ---\e[0m"
        WG_ARRAY=($(ls /etc/wireguard/*.conf 2>/dev/null | awk -F'/' '{print $NF}' | sed 's/.conf//g'))
        
        if [ ${#WG_ARRAY[@]} -eq 0 ]; then
            echo -e "\e[31mNo WireGuard tunnels found.\e[0m"
        else
            echo -e "  \e[33m0)\e[0m \e[32mTest ALL Tunnels\e[0m"
            for i in "${!WG_ARRAY[@]}"; do
                echo -e "  \e[33m$((i+1)))\e[0m \e[32m${WG_ARRAY[$i]}\e[0m"
            done
            read -r -p "Select a tunnel to test [0]: " TEST_OPT
            TEST_OPT=${TEST_OPT:-0}

            test_single_tunnel() {
                local WG_IF=$1
                echo -e "\n\e[36m[*] Testing Interface: $WG_IF \e[0m"
                PEER_IP=$(wg show "$WG_IF" allowed-ips 2>/dev/null | awk '{print $2}' | cut -d'/' -f1)
                if [ -n "$PEER_IP" ]; then
                    if ping -c 3 -W 2 "$PEER_IP" > /dev/null 2>&1; then
                        echo -e "\e[1;32m[OK] $WG_IF -> PEER ($PEER_IP) is SUCCESSFUL!\e[0m"
                    else
                        echo -e "\e[1;31m[ERROR] $WG_IF -> PEER ($PEER_IP) FAILED (Timeout)\e[0m"
                    fi
                else
                    echo -e "\e[33mCould not find a Peer IP for $WG_IF (Tunnel might be down).\e[0m"
                fi
            }

            if [[ "$TEST_OPT" == "0" ]]; then
                for IFACE in "${WG_ARRAY[@]}"; do test_single_tunnel "$IFACE"; done
            elif [[ "$TEST_OPT" =~ ^[0-9]+$ ]] && [ "$TEST_OPT" -le "${#WG_ARRAY[@]}" ]; then
                test_single_tunnel "${WG_ARRAY[$((TEST_OPT-1))]}"
            fi
        fi
        read -r -p $'\n\e[1;32m[!] Press ENTER to return to the main menu...\e[0m'

    elif [ "$ROLE" == "6" ]; then
        echo -e "\n\e[1;36m--- Change MTU of an Existing Tunnel ---\e[0m"
        WG_ARRAY=($(ls /etc/wireguard/*.conf 2>/dev/null | awk -F'/' '{print $NF}' | sed 's/.conf//g'))
        
        if [ ${#WG_ARRAY[@]} -eq 0 ]; then
            echo -e "\e[31mNo WireGuard tunnels found.\e[0m"
        else
            for i in "${!WG_ARRAY[@]}"; do
                CURRENT_MTU=$(grep "MTU" "/etc/wireguard/${WG_ARRAY[$i]}.conf" | awk -F'=' '{print $2}' | tr -d ' ')
                echo -e "  \e[33m$((i+1)))\e[0m \e[32m${WG_ARRAY[$i]}\e[0m (Current MTU: ${CURRENT_MTU:-Default})"
            done
            read -r -p "Select the tunnel to modify (or press Enter to cancel): " MTU_OPT
            
            if [[ "$MTU_OPT" =~ ^[0-9]+$ ]] && [ "$MTU_OPT" -ge 1 ] && [ "$MTU_OPT" -le "${#WG_ARRAY[@]}" ]; then
                SELECTED_WG="${WG_ARRAY[$((MTU_OPT-1))]}"
                
                if [[ "$SELECTED_WG" == wg-* ]]; then
                    TUNNEL_NAME="${SELECTED_WG#wg-}"
                    GRE_IF="gre-${TUNNEL_NAME}"
                    SRV_NAME="gre-${TUNNEL_NAME}.service"
                else
                    TUNNEL_NAME="${SELECTED_WG#wg}"
                    GRE_IF="gre${TUNNEL_NAME}"
                    SRV_NAME="gre${TUNNEL_NAME}-tunnel.service"
                fi
                
                read -r -p "Enter NEW MTU for $SELECTED_WG [e.g., 1280 or 1360]: " NEW_MTU
                if [[ "$NEW_MTU" =~ ^[0-9]+$ ]]; then
                    if grep -q "^MTU" "/etc/wireguard/${SELECTED_WG}.conf"; then
                        sed -i "s/^MTU.*/MTU = $NEW_MTU/" "/etc/wireguard/${SELECTED_WG}.conf"
                    else
                        sed -i "/\[Interface\]/a MTU = $NEW_MTU" "/etc/wireguard/${SELECTED_WG}.conf"
                    fi
                    
                    NEW_GRE_MTU=$((NEW_MTU + 60))
                    sed -i "s/mtu [0-9]*/mtu $NEW_GRE_MTU/" /etc/systemd/system/${SRV_NAME}
                    systemctl daemon-reload
                    
                    echo -e "\n\e[33mRestarting services to apply changes...\e[0m"
                    systemctl stop wg-quick@${SELECTED_WG} 2>/dev/null
                    systemctl restart ${SRV_NAME} 2>/dev/null
                    systemctl start wg-quick@${SELECTED_WG} 2>/dev/null
                    
                    echo -e "\e[1;32m[OK] $SELECTED_WG MTU changed to $NEW_MTU and $GRE_IF MTU changed to $NEW_GRE_MTU.\e[0m"
                    echo -e "\e[1;31m(IMPORTANT: Don't forget to run Option 6 on the other server to match the MTU!)\e[0m"
                fi
            fi
        fi
        read -r -p $'\n\e[1;32m[!] Press ENTER to return to the main menu...\e[0m'

    elif [ "$ROLE" == "0" ]; then
        echo -e "\n\e[32mExited gracefully. Have a great day!\e[0m\n"
        exit 0
    else
        echo -e "\e[31mInvalid selection. Please try again.\e[0m"
        sleep 1
    fi
done
