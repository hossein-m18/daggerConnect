#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════╗
# ║           DaggerConnect — Batch Testing Tool                    ║
# ║                                                                  ║
# ║  ۲۵ تست ترکیبی گلچین‌شده برای مقایسه حالات مختلف              ║
# ║  هر ترانسپورت با تنظیمات مختص خودش تست میشه                   ║
# ╚══════════════════════════════════════════════════════════════════╝
#
# منطق گلچین:
#   ─ هر ۶ ترانسپورت × ۳ سطح obfuscation = ۱۸ تست پایه
#   ─ httpsmux (اصلی‌ترین) + aggressive profile × ۳ obfus = ۳ تست
#   ─ httpmux + httpsmux با chunked=on = ۲ تست
#   ─ kcpmux با KCP aggressive = ۱ تست
#   ─ httpsmux با smux=cpu-efficient = ۱ تست
#   ─ Total: ۲۵ تست

set -euo pipefail

# ──────────────────── Colors ────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ──────────────────── Config ────────────────────
CONF_FILE="servers.conf"
FILTER_IRAN=""
FILTER_KHAREJ=""
FILTER_GROUP=""
QUICK_MODE=false
DRY_RUN=false
VERBOSE=false

PSK="test-dagger-12345"
TUNNEL_PORT=443
TEST_PORT=9999
TEST_DURATION=10

DC_BIN="/usr/local/bin/DaggerConnect"
DC_CONF="/etc/DaggerConnect"
DC_SYS="/etc/systemd/system"
GH_REPO="https://github.com/itsFLoKi/DaggerConnect"
GH_API="https://api.github.com/repos/itsFLoKi/DaggerConnect/releases/latest"

declare -a RESULTS=()
TS=$(date +%Y%m%d_%H%M%S)

declare -a IR_N=() IR_IP=() IR_P=() IR_U=() IR_A=()
declare -a KH_N=() KH_IP=() KH_P=() KH_U=() KH_A=()

# ══════════════════════════════════════════════════════
#  ۲۵ CURATED SCENARIOS
# ══════════════════════════════════════════════════════
#
# Format: "group|label|transport|profile|obfus|pool|smux|chunked|kcp"
#
# تمام transport-specific تنظیمات اعمال میشه:
#   - chunked فقط برای httpmux/httpsmux معنی داره
#   - kcp فقط برای kcpmux معنی داره
#   - ssl cert فقط برای wssmux/httpsmux ساخته میشه

declare -a SCENARIOS=(
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    # tcpmux — ساده و سریع (3 تست)
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    "tcpmux|tcp+obfus=off|tcpmux|balanced|disabled|3|balanced|off|default"
    "tcpmux|tcp+obfus=bal|tcpmux|balanced|balanced|3|balanced|off|default"
    "tcpmux|tcp+obfus=max|tcpmux|balanced|maximum|3|balanced|off|default"

    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    # kcpmux — UDP، سریع + KCP tuning (4 تست)
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    "kcpmux|kcp+obfus=off|kcpmux|balanced|disabled|3|balanced|off|default"
    "kcpmux|kcp+obfus=bal|kcpmux|balanced|balanced|3|balanced|off|default"
    "kcpmux|kcp+obfus=max|kcpmux|balanced|maximum|3|balanced|off|default"
    "kcpmux|kcp+aggressive|kcpmux|balanced|balanced|3|balanced|off|aggressive"

    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    # wsmux — WebSocket (3 تست)
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    "wsmux|ws+obfus=off|wsmux|balanced|disabled|3|balanced|off|default"
    "wsmux|ws+obfus=bal|wsmux|balanced|balanced|3|balanced|off|default"
    "wsmux|ws+obfus=max|wsmux|balanced|maximum|3|balanced|off|default"

    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    # wssmux — WebSocket + TLS (3 تست)
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    "wssmux|wss+obfus=off|wssmux|balanced|disabled|3|balanced|off|default"
    "wssmux|wss+obfus=bal|wssmux|balanced|balanced|3|balanced|off|default"
    "wssmux|wss+obfus=max|wssmux|balanced|maximum|3|balanced|off|default"

    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    # httpmux — HTTP Mimicry + chunked (4 تست)
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    "httpmux|http+obfus=off|httpmux|balanced|disabled|3|balanced|off|default"
    "httpmux|http+obfus=bal|httpmux|balanced|balanced|3|balanced|off|default"
    "httpmux|http+obfus=max|httpmux|balanced|maximum|3|balanced|off|default"
    "httpmux|http+chunked|httpmux|balanced|balanced|3|balanced|on|default"

    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    # httpsmux — ⭐ اصلی: TLS+Mimicry + profile/chunked/smux (8 تست)
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    # balanced profile × 3 obfus
    "httpsmux|https+obfus=off|httpsmux|balanced|disabled|3|balanced|off|default"
    "httpsmux|https+obfus=bal|httpsmux|balanced|balanced|3|balanced|off|default"
    "httpsmux|https+obfus=max|httpsmux|balanced|maximum|3|balanced|off|default"
    # aggressive profile × 3 obfus
    "httpsmux|https+aggr+obfus=off|httpsmux|aggressive|disabled|3|balanced|off|default"
    "httpsmux|https+aggr+obfus=bal|httpsmux|aggressive|balanced|3|balanced|off|default"
    "httpsmux|https+aggr+obfus=max|httpsmux|aggressive|maximum|3|balanced|off|default"
    # chunked on
    "httpsmux|https+chunked|httpsmux|balanced|balanced|3|balanced|on|default"
    # smux cpu-efficient
    "httpsmux|https+smux=eff|httpsmux|balanced|balanced|3|cpu-efficient|off|default"
)
# Total: 3 + 4 + 3 + 3 + 4 + 8 = 25 tests

# ══════════════════════════════════════════════════════
#  HELP
# ══════════════════════════════════════════════════════

show_help() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          DaggerConnect — Batch Testing Tool                 ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}Usage:${NC}  ./dc-test.sh [options]"
    echo ""
    echo -e "${WHITE}Options:${NC}"
    echo -e "  ${GREEN}-g, --group <name>${NC}    فقط یه ترانسپورت خاص تست شه"
    echo -e "                       tcpmux | kcpmux | wsmux | wssmux | httpmux | httpsmux"
    echo -e "  ${GREEN}-i, --iran <name>${NC}     فیلتر سرور ایران"
    echo -e "  ${GREEN}-k, --kharej <name>${NC}   فیلتر سرور خارج"
    echo -e "  ${GREEN}-c, --config <file>${NC}   فایل کانفیگ (پیشفرض: servers.conf)"
    echo -e "  ${GREEN}-q, --quick${NC}           بدون iperf (فقط اتصال + ping)"
    echo -e "  ${GREEN}    --dry-run${NC}         فقط config نشون بده"
    echo -e "  ${GREEN}-v, --verbose${NC}         جزئیات بیشتر"
    echo -e "  ${GREEN}-h, --help${NC}            نمایش این راهنما"
    echo ""
    echo -e "${WHITE}۲۵ Test Scenarios:${NC}"
    echo -e "  ${YELLOW}tcpmux${NC}    (3)  obfus: off/balanced/maximum"
    echo -e "  ${YELLOW}kcpmux${NC}    (4)  obfus: off/balanced/maximum + KCP aggressive"
    echo -e "  ${YELLOW}wsmux${NC}     (3)  obfus: off/balanced/maximum"
    echo -e "  ${YELLOW}wssmux${NC}    (3)  obfus: off/balanced/maximum"
    echo -e "  ${YELLOW}httpmux${NC}   (4)  obfus: off/balanced/maximum + chunked=on"
    echo -e "  ${YELLOW}httpsmux${NC}  (8)  obfus × profile(balanced+aggressive) + chunked=on + smux=efficient"
    echo ""
    echo -e "${WHITE}Examples:${NC}"
    echo "  ./dc-test.sh                        # همه ۲۵ تست"
    echo "  ./dc-test.sh -g httpsmux             # فقط ۸ تست httpsmux"
    echo "  ./dc-test.sh -g kcpmux --quick       # فقط kcpmux بدون iperf"
    echo "  ./dc-test.sh -i ir1 -k kh1           # فقط بین ir1 و kh1"
    echo "  ./dc-test.sh --dry-run -v             # نمایش config بدون اجرا"
    echo ""
}

# ══════════════════════════════════════════════════════
#  PARSE ARGS
# ══════════════════════════════════════════════════════

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -g|--group)   FILTER_GROUP="$2"; shift 2 ;;
            -i|--iran)    FILTER_IRAN="$2"; shift 2 ;;
            -k|--kharej)  FILTER_KHAREJ="$2"; shift 2 ;;
            -c|--config)  CONF_FILE="$2"; shift 2 ;;
            -q|--quick)   QUICK_MODE=true; shift ;;
            --dry-run)    DRY_RUN=true; shift ;;
            -v|--verbose) VERBOSE=true; shift ;;
            -h|--help)    show_help; exit 0 ;;
            *) echo -e "${RED}❌ Unknown: $1${NC}"; show_help; exit 1 ;;
        esac
    done
}

# ══════════════════════════════════════════════════════
#  PARSE servers.conf
# ══════════════════════════════════════════════════════

parse_conf() {
    [[ ! -f "$CONF_FILE" ]] && { echo -e "${RED}❌ $CONF_FILE not found! cp servers.conf.example servers.conf${NC}"; exit 1; }

    local sec=""
    while IFS= read -r line || [[ -n "$line" ]]; do
        line=$(echo "$line" | sed 's/#.*//' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^\[(.+)\]$ ]] && { sec="${BASH_REMATCH[1]}"; continue; }

        case "$sec" in
            iran|kharej)
                if [[ "$line" =~ ^([a-zA-Z0-9_-]+)[[:space:]]*=[[:space:]]*(.+)$ ]]; then
                    local nm="${BASH_REMATCH[1]}" rest="${BASH_REMATCH[2]}"
                    IFS='|' read -ra p <<< "$rest"
                    [[ ${#p[@]} -lt 4 ]] && continue
                    local ips=$(echo "${p[0]}" | tr -d ' ')
                    local port=$(echo "${p[1]}" | tr -d ' ')
                    local usr=$(echo "${p[2]}" | tr -d ' ')
                    local auth=$(echo "${p[3]}" | tr -d ' ')
                    if [[ "$sec" == "iran" ]]; then
                        IR_N+=("$nm"); IR_IP+=("$ips"); IR_P+=("$port"); IR_U+=("$usr"); IR_A+=("$auth")
                    else
                        KH_N+=("$nm"); KH_IP+=("$ips"); KH_P+=("$port"); KH_U+=("$usr"); KH_A+=("$auth")
                    fi
                fi ;;
            settings)
                [[ "$line" =~ ^psk[[:space:]]*=[[:space:]]*(.+)$ ]] && PSK="${BASH_REMATCH[1]}"
                [[ "$line" =~ ^tunnel_port[[:space:]]*=[[:space:]]*([0-9]+)$ ]] && TUNNEL_PORT="${BASH_REMATCH[1]}"
                [[ "$line" =~ ^test_port[[:space:]]*=[[:space:]]*([0-9]+)$ ]] && TEST_PORT="${BASH_REMATCH[1]}"
                [[ "$line" =~ ^test_duration[[:space:]]*=[[:space:]]*([0-9]+)$ ]] && TEST_DURATION="${BASH_REMATCH[1]}"
                ;;
        esac
    done < "$CONF_FILE"

    # Filters
    if [[ -n "$FILTER_IRAN" ]]; then
        local f=false
        for i in "${!IR_N[@]}"; do
            if [[ "${IR_N[$i]}" == "$FILTER_IRAN" ]]; then
                local n="${IR_N[$i]}" ip="${IR_IP[$i]}" p="${IR_P[$i]}" u="${IR_U[$i]}" a="${IR_A[$i]}"
                IR_N=("$n"); IR_IP=("$ip"); IR_P=("$p"); IR_U=("$u"); IR_A=("$a"); f=true; break
            fi
        done
        $f || { echo -e "${RED}❌ Iran '$FILTER_IRAN' not found${NC}"; exit 1; }
    fi
    if [[ -n "$FILTER_KHAREJ" ]]; then
        local f=false
        for i in "${!KH_N[@]}"; do
            if [[ "${KH_N[$i]}" == "$FILTER_KHAREJ" ]]; then
                local n="${KH_N[$i]}" ip="${KH_IP[$i]}" p="${KH_P[$i]}" u="${KH_U[$i]}" a="${KH_A[$i]}"
                KH_N=("$n"); KH_IP=("$ip"); KH_P=("$p"); KH_U=("$u"); KH_A=("$a"); f=true; break
            fi
        done
        $f || { echo -e "${RED}❌ Kharej '$FILTER_KHAREJ' not found${NC}"; exit 1; }
    fi

    [[ ${#IR_N[@]} -eq 0 ]] && { echo -e "${RED}❌ No Iran servers${NC}"; exit 1; }
    [[ ${#KH_N[@]} -eq 0 ]] && { echo -e "${RED}❌ No Kharej servers${NC}"; exit 1; }
}

# ══════════════════════════════════════════════════════
#  SSH
# ══════════════════════════════════════════════════════

run_ssh() {
    local ip="$1" port="$2" user="$3" auth="$4"; shift 4
    local opts="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o LogLevel=ERROR"
    if [[ "$auth" == /* ]]; then
        ssh $opts -i "$auth" -p "$port" "${user}@${ip}" "$*" 2>/dev/null
    else
        sshpass -p "$auth" ssh $opts -p "$port" "${user}@${ip}" "$*" 2>/dev/null
    fi
}

# ══════════════════════════════════════════════════════
#  INSTALL
# ══════════════════════════════════════════════════════

install_on() {
    local lbl="$1" ip="$2" port="$3" user="$4" auth="$5"
    echo -ne "  ${DIM}[$lbl] $ip...${NC}"

    local ok=$(run_ssh "$ip" "$port" "$user" "$auth" "test -f $DC_BIN && echo y || echo n")
    if [[ "$ok" == "y" ]]; then
        echo -e "\r  ${GREEN}✓${NC} [$lbl] $ip — DC ✔            "
    else
        echo -e "\r  ${YELLOW}⟳${NC} [$lbl] $ip — Installing DC..."
        run_ssh "$ip" "$port" "$user" "$auth" "
            apt-get update -qq >/dev/null 2>&1
            apt-get install -y -qq curl wget jq sshpass >/dev/null 2>&1
            mkdir -p $DC_CONF
            URL=\$(curl -s $GH_API 2>/dev/null | jq -r '.assets[]|select(.name==\"DaggerConnect\")|.browser_download_url' 2>/dev/null)
            [[ -n \"\$URL\" && \"\$URL\" != \"null\" ]] && wget -q -O $DC_BIN \"\$URL\" || wget -q -O $DC_BIN ${GH_REPO}/releases/latest/download/DaggerConnect
            chmod +x $DC_BIN
        " && echo -e "  ${GREEN}✓${NC} [$lbl] $ip — DC installed" \
          || { echo -e "  ${RED}✖${NC} [$lbl] $ip — FAILED!"; return 1; }
    fi

    if ! $QUICK_MODE; then
        local iok=$(run_ssh "$ip" "$port" "$user" "$auth" "which iperf3 >/dev/null 2>&1 && echo y || echo n")
        [[ "$iok" != "y" ]] && {
            run_ssh "$ip" "$port" "$user" "$auth" "apt-get install -y -qq iperf3 >/dev/null 2>&1"
            echo -e "  ${GREEN}✓${NC} [$lbl] $ip — iperf3 ✔"
        }
    fi
}

# ══════════════════════════════════════════════════════
#  YAML BLOCKS
# ══════════════════════════════════════════════════════

obfus_yaml() {
    case "$1" in
        disabled) echo "obfuscation:
  enabled: false" ;;
        balanced) echo "obfuscation:
  enabled: true
  min_padding: 16
  max_padding: 512
  min_delay_ms: 5
  max_delay_ms: 50
  burst_chance: 0.15" ;;
        maximum) echo "obfuscation:
  enabled: true
  min_padding: 128
  max_padding: 2048
  min_delay_ms: 15
  max_delay_ms: 150
  burst_chance: 0.3" ;;
    esac
}

smux_yaml() {
    case "$1" in
        balanced) echo "smux:
  keepalive: 8
  max_recv: 8388608
  max_stream: 8388608
  frame_size: 16384
  version: 2" ;;
        cpu-efficient) echo "smux:
  keepalive: 10
  max_recv: 8388608
  max_stream: 8388608
  frame_size: 8192
  version: 2" ;;
    esac
}

kcp_yaml() {
    case "$1" in
        default) echo "kcp:
  nodelay: 1
  interval: 10
  resend: 2
  nc: 1
  sndwnd: 256
  rcvwnd: 256
  mtu: 1200" ;;
        aggressive) echo "kcp:
  nodelay: 1
  interval: 5
  resend: 2
  nc: 1
  sndwnd: 1024
  rcvwnd: 1024
  mtu: 1200" ;;
    esac
}

mimicry_yaml() {
    local chunked="$1"
    echo "http_mimic:
  fake_domain: \"www.google.com\"
  fake_path: \"/search\"
  user_agent: \"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36\"
  chunked_encoding: ${chunked}
  session_cookie: true
  custom_headers:
    - \"Accept-Language: en-US,en;q=0.9\"
    - \"Accept-Encoding: gzip, deflate, br\""
}

advanced_yaml() {
    echo "advanced:
  tcp_nodelay: true
  tcp_keepalive: 3
  tcp_read_buffer: 32768
  tcp_write_buffer: 32768
  cleanup_interval: 1
  session_timeout: 15
  connection_timeout: 20
  stream_timeout: 45
  max_connections: 300
  max_udp_flows: 150
  udp_flow_timeout: 90
  udp_buffer_size: 262144"
}

# ══════════════════════════════════════════════════════
#  GENERATE CONFIGS
# ══════════════════════════════════════════════════════

gen_server() {
    local tr="$1" prof="$2" obf="$3" smx="$4" ch="$5" kp="$6"

    echo "mode: \"server\"
listen: \"0.0.0.0:${TUNNEL_PORT}\"
transport: \"${tr}\"
psk: \"${PSK}\"
profile: \"${prof}\"
verbose: true
heartbeat: 2"

    [[ "$tr" == "wssmux" || "$tr" == "httpsmux" ]] && echo "
cert_file: \"${DC_CONF}/certs/cert.pem\"
key_file: \"${DC_CONF}/certs/key.pem\""

    echo "
maps:
  - type: tcp
    bind: \"0.0.0.0:${TEST_PORT}\"
    target: \"127.0.0.1:${TEST_PORT}\""
    $QUICK_MODE || echo "  - type: tcp
    bind: \"0.0.0.0:5201\"
    target: \"127.0.0.1:5201\""

    echo ""
    obfus_yaml "$obf"
    echo ""
    smux_yaml "$smx"
    [[ "$tr" == "kcpmux" ]] && { echo ""; kcp_yaml "$kp"; }
    [[ "$tr" == "httpmux" || "$tr" == "httpsmux" ]] && { echo ""; mimicry_yaml "$ch"; }
    echo ""
    advanced_yaml
}

gen_client() {
    local tr="$1" prof="$2" obf="$3" pool="$4" smx="$5" ch="$6" kp="$7" iran_ip="$8"

    echo "mode: \"client\"
psk: \"${PSK}\"
profile: \"${prof}\"
verbose: true
heartbeat: 2

paths:
  - transport: \"${tr}\"
    addr: \"${iran_ip}:${TUNNEL_PORT}\"
    connection_pool: ${pool}
    aggressive_pool: true
    retry_interval: 1
    dial_timeout: 5"

    echo ""
    obfus_yaml "$obf"
    echo ""
    smux_yaml "$smx"
    [[ "$tr" == "kcpmux" ]] && { echo ""; kcp_yaml "$kp"; }
    [[ "$tr" == "httpmux" || "$tr" == "httpsmux" ]] && { echo ""; mimicry_yaml "$ch"; }
    echo ""
    advanced_yaml
}

# ══════════════════════════════════════════════════════
#  DEPLOY / STOP
# ══════════════════════════════════════════════════════

ensure_cert() {
    local ip="$1" p="$2" u="$3" a="$4"
    local ok=$(run_ssh "$ip" "$p" "$u" "$a" "test -f ${DC_CONF}/certs/cert.pem && echo y || echo n")
    [[ "$ok" != "y" ]] && run_ssh "$ip" "$p" "$u" "$a" "
        mkdir -p ${DC_CONF}/certs
        openssl req -x509 -newkey rsa:2048 -keyout ${DC_CONF}/certs/key.pem \
            -out ${DC_CONF}/certs/cert.pem -days 365 -nodes -subj '/CN=www.google.com' 2>/dev/null"
}

deploy() {
    local role="$1" ip="$2" p="$3" u="$4" a="$5" yaml="$6" tr="$7"

    run_ssh "$ip" "$p" "$u" "$a" "mkdir -p $DC_CONF; cat > ${DC_CONF}/${role}.yaml << 'DCEOF'
${yaml}
DCEOF"

    [[ "$role" == "server" && ("$tr" == "wssmux" || "$tr" == "httpsmux") ]] && ensure_cert "$ip" "$p" "$u" "$a"

    run_ssh "$ip" "$p" "$u" "$a" "
        cat > ${DC_SYS}/DaggerConnect-${role}.service << 'EOF'
[Unit]
Description=DaggerConnect ${role}
After=network.target
[Service]
Type=simple
ExecStart=${DC_BIN} -c ${DC_CONF}/${role}.yaml
Restart=always
RestartSec=3
LimitNOFILE=1048576
[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl stop DaggerConnect-${role} 2>/dev/null || true
        sleep 1
        systemctl start DaggerConnect-${role}"
}

stop_dc() {
    local role="$1" ip="$2" p="$3" u="$4" a="$5"
    run_ssh "$ip" "$p" "$u" "$a" "systemctl stop DaggerConnect-${role} 2>/dev/null || true"
}

# ══════════════════════════════════════════════════════
#  TESTING
# ══════════════════════════════════════════════════════

wait_tunnel() {
    local w=0
    while [[ $w -lt 20 ]]; do
        local s=$(run_ssh "$1" "$2" "$3" "$4" "systemctl is-active DaggerConnect-server 2>/dev/null || echo x")
        local c=$(run_ssh "$5" "$6" "$7" "$8" "systemctl is-active DaggerConnect-client 2>/dev/null || echo x")
        if [[ "$s" == "active" && "$c" == "active" ]]; then
            local n=$(run_ssh "$5" "$6" "$7" "$8" "journalctl -u DaggerConnect-client -n 20 --no-pager 2>/dev/null | grep -ci 'session added\|connected\|established' || echo 0")
            [[ "$n" -gt 0 ]] && return 0
        fi
        sleep 1; w=$((w+1))
    done
    return 1
}

get_latency() {
    local lat=$(run_ssh "$1" "$2" "$3" "$4" "ping -c 3 -W 3 $5 2>/dev/null | tail -1 | awk -F'/' '{print \$5}'")
    [[ -n "$lat" ]] && echo "${lat}ms" || echo "-"
}

get_bandwidth() {
    $QUICK_MODE && { echo "-"; return; }

    run_ssh "$5" "$6" "$7" "$8" "pkill -f 'iperf3 -s' 2>/dev/null; sleep 0.5; iperf3 -s -p 5201 -D 2>/dev/null"
    sleep 2

    local bw=$(run_ssh "$1" "$2" "$3" "$4" "
        iperf3 -c 127.0.0.1 -p 5201 -t ${TEST_DURATION} -P 2 --json 2>/dev/null | \
        python3 -c 'import sys,json;d=json.load(sys.stdin);print(round(d[\"end\"][\"sum_received\"][\"bits_per_second\"]/1e6,1))' 2>/dev/null || echo '-'
    ")

    run_ssh "$5" "$6" "$7" "$8" "pkill -f 'iperf3 -s' 2>/dev/null"
    [[ -n "$bw" && "$bw" != "-" ]] && echo "${bw}Mbps" || echo "-"
}

# ══════════════════════════════════════════════════════
#  RUN ONE SCENARIO
# ══════════════════════════════════════════════════════

run_one() {
    local sc="$1"
    local in="$2" iip="$3" ip="$4" iu="$5" ia="$6"
    local kn="$7" kip="$8" kp="$9" ku="${10}" ka="${11}"

    IFS='|' read -r grp lbl tr prof obf pool smx ch kcp_p <<< "$sc"

    local status="❌ FAIL" lat="-" bw="-"

    if $DRY_RUN; then
        echo -e "  ${CYAN}[DRY]${NC} ${BOLD}${lbl}${NC}  ${DIM}(${tr} prof=${prof} obf=${obf} pool=${pool} smux=${smx} ch=${ch} kcp=${kcp_p})${NC}"
        $VERBOSE && { echo "--- server.yaml ---"; gen_server "$tr" "$prof" "$obf" "$smx" "$ch" "$kcp_p" | head -12; echo "..."; }
        RESULTS+=("${in}|${kn}|${grp}|${lbl}|${iip}|${kip}|🔵DRY|-|-")
        return
    fi

    echo -ne "  ${DIM}⏳ ${lbl}...${NC}"

    local sy=$(gen_server "$tr" "$prof" "$obf" "$smx" "$ch" "$kcp_p")
    local cy=$(gen_client "$tr" "$prof" "$obf" "$pool" "$smx" "$ch" "$kcp_p" "$iip")

    stop_dc "server" "$iip" "$ip" "$iu" "$ia"
    stop_dc "client" "$kip" "$kp" "$ku" "$ka"
    sleep 1

    deploy "server" "$iip" "$ip" "$iu" "$ia" "$sy" "$tr"
    deploy "client" "$kip" "$kp" "$ku" "$ka" "$cy" "$tr"

    if wait_tunnel "$iip" "$ip" "$iu" "$ia" "$kip" "$kp" "$ku" "$ka"; then
        status="✅ OK"
        lat=$(get_latency "$iip" "$ip" "$iu" "$ia" "$kip")
        bw=$(get_bandwidth "$iip" "$ip" "$iu" "$ia" "$kip" "$kp" "$ku" "$ka")
        echo -e "\r  ${GREEN}✓${NC} ${BOLD}${lbl}${NC} — ${GREEN}OK${NC}  ${CYAN}${lat}${NC}  ${YELLOW}${bw}${NC}              "
    else
        local err=$(run_ssh "$kip" "$kp" "$ku" "$ka" "journalctl -u DaggerConnect-client -n 2 --no-pager 2>/dev/null | tail -1 | cut -c1-50" 2>/dev/null || echo "")
        echo -e "\r  ${RED}✖${NC} ${BOLD}${lbl}${NC} — ${RED}FAIL${NC}  ${DIM}${err}${NC}              "
    fi

    stop_dc "server" "$iip" "$ip" "$iu" "$ia"
    stop_dc "client" "$kip" "$kp" "$ku" "$ka"

    RESULTS+=("${in}|${kn}|${grp}|${lbl}|${iip}|${kip}|${status}|${lat}|${bw}")
    sleep 1
}

# ══════════════════════════════════════════════════════
#  RESULTS TABLE
# ══════════════════════════════════════════════════════

print_results() {
    [[ ${#RESULTS[@]} -eq 0 ]] && return

    echo ""
    echo -e "${CYAN}╔══════╤════════╤═══════════╤══════════════════════╤══════════╤═════════╤══════════╗${NC}"
    printf "${CYAN}║${NC}${BOLD}%-6s${NC}${CYAN}│${NC}${BOLD}%-8s${NC}${CYAN}│${NC}${BOLD}%-11s${NC}${CYAN}│${NC}${BOLD}%-22s${NC}${CYAN}│${NC}${BOLD}%-10s${NC}${CYAN}│${NC}${BOLD}%-9s${NC}${CYAN}│${NC}${BOLD}%-10s${NC}${CYAN}║${NC}\n" \
        " Iran" " Kharej" " Group" " Test" " Status" " Ping" " BW"
    echo -e "${CYAN}╠══════╪════════╪═══════════╪══════════════════════╪══════════╪═════════╪══════════╣${NC}"

    local cg=""
    for r in "${RESULTS[@]}"; do
        IFS='|' read -ra c <<< "$r"
        local g="${c[2]}"

        [[ "$g" != "$cg" && -n "$cg" ]] && echo -e "${CYAN}╟──────┼────────┼───────────┼──────────────────────┼──────────┼─────────┼──────────╢${NC}"
        cg="$g"

        local sc=""
        [[ "${c[6]}" == *"OK"* ]] && sc="${GREEN}${c[6]}${NC}" || sc="${RED}${c[6]}${NC}"

        printf "${CYAN}║${NC} %-5s${CYAN}│${NC} %-7s${CYAN}│${NC} %-10s${CYAN}│${NC} %-21s${CYAN}│${NC} %-17b${CYAN}│${NC} %-8s${CYAN}│${NC} %-9s${CYAN}║${NC}\n" \
            "${c[0]}" "${c[1]}" "${c[2]}" "${c[3]}" "$sc" "${c[7]}" "${c[8]}"
    done
    echo -e "${CYAN}╚══════╧════════╧═══════════╧══════════════════════╧══════════╧═════════╧══════════╝${NC}"

    # CSV
    local csv="results_${TS}.csv"
    echo "Iran,Kharej,Group,Test,Iran_IP,Kharej_IP,Status,Latency,Bandwidth" > "$csv"
    for r in "${RESULTS[@]}"; do echo "$r" | tr '|' ','; done >> "$csv"
    echo -e "\n${GREEN}📊 Saved: ${csv}${NC}"

    local t=${#RESULTS[@]}
    local p=$(printf '%s\n' "${RESULTS[@]}" | grep -c "OK" || true)
    echo -e "${WHITE}Total=${t}  ${GREEN}Pass=${p}${NC}  ${RED}Fail=$((t-p))${NC}"
}

# ══════════════════════════════════════════════════════
#  MAIN
# ══════════════════════════════════════════════════════

main() {
    parse_args "$@"

    echo -e "${CYAN}"
    echo "  ╔══════════════════════════════════════════════╗"
    echo "  ║   DaggerConnect — Batch Testing Tool         ║"
    echo "  ╚══════════════════════════════════════════════╝"
    echo -e "${NC}"

    parse_conf

    # Count filtered scenarios
    local cnt=0
    for s in "${SCENARIOS[@]}"; do
        IFS='|' read -r g _ <<< "$s"
        [[ -z "$FILTER_GROUP" || "$g" == "$FILTER_GROUP" ]] && cnt=$((cnt+1))
    done

    # Count pairs
    local pairs=0
    for ii in "${!IR_N[@]}"; do
        IFS=',' read -ra il <<< "${IR_IP[$ii]}"
        for ki in "${!KH_N[@]}"; do
            IFS=',' read -ra kl <<< "${KH_IP[$ki]}"
            for _ in "${il[@]}"; do for _ in "${kl[@]}"; do pairs=$((pairs+1)); done; done
        done
    done

    echo -e "${WHITE}Servers:${NC}"
    for i in "${!IR_N[@]}"; do echo -e "  🇮🇷 ${GREEN}${IR_N[$i]}${NC}: ${IR_IP[$i]}"; done
    for i in "${!KH_N[@]}"; do echo -e "  🌍 ${GREEN}${KH_N[$i]}${NC}: ${KH_IP[$i]}"; done
    echo ""
    echo -e "${WHITE}Tests: ${YELLOW}${cnt}${NC} scenarios × ${pairs} pair(s) = ${BOLD}${YELLOW}$((cnt*pairs))${NC} total"
    [[ -n "$FILTER_GROUP" ]] && echo -e "  ${DIM}(filter: ${FILTER_GROUP})${NC}"
    echo ""

    # Install
    if ! $DRY_RUN; then
        echo -e "${CYAN}══════ Install ══════${NC}"
        declare -A seen=()
        for i in "${!IR_N[@]}"; do
            IFS=',' read -ra ips <<< "${IR_IP[$i]}"; local fip="${ips[0]}"
            [[ -z "${seen[$fip]+x}" ]] && { install_on "${IR_N[$i]}" "$fip" "${IR_P[$i]}" "${IR_U[$i]}" "${IR_A[$i]}"; seen[$fip]=1; }
        done
        for i in "${!KH_N[@]}"; do
            IFS=',' read -ra ips <<< "${KH_IP[$i]}"; local fip="${ips[0]}"
            [[ -z "${seen[$fip]+x}" ]] && { install_on "${KH_N[$i]}" "$fip" "${KH_P[$i]}" "${KH_U[$i]}" "${KH_A[$i]}"; seen[$fip]=1; }
        done
        echo ""
    fi

    # Test
    echo -e "${CYAN}══════ Testing ══════${NC}"
    local cg=""
    for sc in "${SCENARIOS[@]}"; do
        IFS='|' read -r grp _ <<< "$sc"
        [[ -n "$FILTER_GROUP" && "$grp" != "$FILTER_GROUP" ]] && continue

        if [[ "$grp" != "$cg" ]]; then
            cg="$grp"
            echo ""
            echo -e "${BOLD}${WHITE}━━━━━ ${YELLOW}${grp}${WHITE} ━━━━━${NC}"
        fi

        for ii in "${!IR_N[@]}"; do
            IFS=',' read -ra il <<< "${IR_IP[$ii]}"
            for ki in "${!KH_N[@]}"; do
                IFS=',' read -ra kl <<< "${KH_IP[$ki]}"
                for iip in "${il[@]}"; do
                    for kip in "${kl[@]}"; do
                        run_one "$sc" \
                            "${IR_N[$ii]}" "$iip" "${IR_P[$ii]}" "${IR_U[$ii]}" "${IR_A[$ii]}" \
                            "${KH_N[$ki]}" "$kip" "${KH_P[$ki]}" "${KH_U[$ki]}" "${KH_A[$ki]}"
                    done
                done
            done
        done
    done

    # Results
    echo ""
    echo -e "${CYAN}══════ Results ══════${NC}"
    print_results
}

main "$@"
