#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════╗
# ║           DaggerConnect — Batch Testing Tool                    ║
# ║                                                                  ║
# ║  تست خودکار حالات گلچین‌شده DaggerConnect بین چند سرور          ║
# ║  ~19 تست هوشمند به جای 18 هزار ترکیب                           ║
# ╚══════════════════════════════════════════════════════════════════╝

# No set -e: we handle errors explicitly

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

# ──────────────────── Defaults ────────────────────
CONF_FILE="servers.conf"
FILTER_IRAN=""
FILTER_KHAREJ=""
FILTER_GROUP=""
QUICK_MODE=false
DRY_RUN=false
VERBOSE=false

# Default settings from conf
PSK="test-dagger-12345"
TUNNEL_PORT=443
TEST_PORT=9999
TEST_DURATION=10

# DaggerConnect paths
DC_BIN="/usr/local/bin/DaggerConnect"
DC_CONFIG_DIR="/etc/DaggerConnect"
DC_SYSTEMD_DIR="/etc/systemd/system"
GITHUB_REPO="https://github.com/itsFLoKi/DaggerConnect"
GITHUB_API="https://api.github.com/repos/itsFLoKi/DaggerConnect/releases/latest"

# Results
declare -a RESULTS=()
RESULTS_CSV=""
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# ──────────────────── Server storage ────────────────────
declare -a IRAN_NAMES=()
declare -a IRAN_IPS=()
declare -a IRAN_PORTS=()
declare -a IRAN_USERS=()
declare -a IRAN_AUTHS=()

declare -a KHAREJ_NAMES=()
declare -a KHAREJ_IPS=()
declare -a KHAREJ_PORTS=()
declare -a KHAREJ_USERS=()
declare -a KHAREJ_AUTHS=()

# ═══════════════════════════════════════════════════
#  ۲۵ CURATED COMBINATORIAL SCENARIOS
# ═══════════════════════════════════════════════════
#
# Format: "group|label|transport|profile|obfus|pool|smux|chunked|kcp"
#
# Logic:
#   - هر ترانسپورت × ۳ سطح obfuscation (off/balanced/max)
#   - httpsmux اضافه: aggressive profile × ۳ obfus
#   - httpmux + httpsmux: chunked=on تست
#   - kcpmux: KCP aggressive تست
#   - httpsmux: smux=cpu-efficient تست
#
# Total: 25 tests per server pair

declare -a SCENARIOS=(
    # ━━━ tcpmux (3 tests) ━━━
    "tcpmux|tcp+obfus=off|tcpmux|balanced|disabled|3|balanced|off|default"
    "tcpmux|tcp+obfus=bal|tcpmux|balanced|balanced|3|balanced|off|default"
    "tcpmux|tcp+obfus=max|tcpmux|balanced|maximum|3|balanced|off|default"

    # ━━━ kcpmux (4 tests) ━━━
    "kcpmux|kcp+obfus=off|kcpmux|balanced|disabled|3|balanced|off|default"
    "kcpmux|kcp+obfus=bal|kcpmux|balanced|balanced|3|balanced|off|default"
    "kcpmux|kcp+obfus=max|kcpmux|balanced|maximum|3|balanced|off|default"
    "kcpmux|kcp+aggressive|kcpmux|balanced|balanced|3|balanced|off|aggressive"

    # ━━━ wsmux (3 tests) ━━━
    "wsmux|ws+obfus=off|wsmux|balanced|disabled|3|balanced|off|default"
    "wsmux|ws+obfus=bal|wsmux|balanced|balanced|3|balanced|off|default"
    "wsmux|ws+obfus=max|wsmux|balanced|maximum|3|balanced|off|default"

    # ━━━ wssmux (3 tests) ━━━
    "wssmux|wss+obfus=off|wssmux|balanced|disabled|3|balanced|off|default"
    "wssmux|wss+obfus=bal|wssmux|balanced|balanced|3|balanced|off|default"
    "wssmux|wss+obfus=max|wssmux|balanced|maximum|3|balanced|off|default"

    # ━━━ httpmux (4 tests) ━━━
    "httpmux|http+obfus=off|httpmux|balanced|disabled|3|balanced|off|default"
    "httpmux|http+obfus=bal|httpmux|balanced|balanced|3|balanced|off|default"
    "httpmux|http+obfus=max|httpmux|balanced|maximum|3|balanced|off|default"
    "httpmux|http+chunked|httpmux|balanced|balanced|3|balanced|on|default"

    # ━━━ httpsmux ⭐ (8 tests) ━━━
    "httpsmux|https+obfus=off|httpsmux|balanced|disabled|3|balanced|off|default"
    "httpsmux|https+obfus=bal|httpsmux|balanced|balanced|3|balanced|off|default"
    "httpsmux|https+obfus=max|httpsmux|balanced|maximum|3|balanced|off|default"
    "httpsmux|https+aggr+off|httpsmux|aggressive|disabled|3|balanced|off|default"
    "httpsmux|https+aggr+bal|httpsmux|aggressive|balanced|3|balanced|off|default"
    "httpsmux|https+aggr+max|httpsmux|aggressive|maximum|3|balanced|off|default"
    "httpsmux|https+chunked|httpsmux|balanced|balanced|3|balanced|on|default"
    "httpsmux|https+smux=eff|httpsmux|balanced|balanced|3|cpu-efficient|off|default"
)

# ══════════════════════════════════════════════════════════════
#  HELP
# ══════════════════════════════════════════════════════════════

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
    echo -e "  ${GREEN}-i, --iran <name>${NC}     فقط سرور ایران خاص"
    echo -e "  ${GREEN}-k, --kharej <name>${NC}   فقط سرور خارج خاص"
    echo -e "  ${GREEN}-c, --config <file>${NC}   مسیر فایل کانفیگ (پیشفرض: servers.conf)"
    echo -e "  ${GREEN}-q, --quick${NC}           فقط تست اتصال (بدون iperf)"
    echo -e "  ${GREEN}    --dry-run${NC}         فقط config نشون بده"
    echo -e "  ${GREEN}-v, --verbose${NC}         جزئیات بیشتر"
    echo -e "  ${GREEN}-h, --help${NC}            نمایش این راهنما"
    echo ""
    echo -e "${WHITE}۲۵ Curated Tests:${NC}"
    echo -e "  ${YELLOW}tcpmux${NC}    (3)  × obfus: off/balanced/maximum"
    echo -e "  ${YELLOW}kcpmux${NC}    (4)  × obfus + KCP aggressive"
    echo -e "  ${YELLOW}wsmux${NC}     (3)  × obfus: off/balanced/maximum"
    echo -e "  ${YELLOW}wssmux${NC}    (3)  × obfus: off/balanced/maximum"
    echo -e "  ${YELLOW}httpmux${NC}   (4)  × obfus + chunked=on"
    echo -e "  ${YELLOW}httpsmux${NC}  (8)  × obfus × profile(bal+aggr) + chunked + smux=eff"
    echo ""
    echo -e "${WHITE}Examples:${NC}"
    echo "  ./dc-test.sh                        # همه ۲۵ تست"
    echo "  ./dc-test.sh -g httpsmux             # فقط ۸ تست httpsmux"
    echo "  ./dc-test.sh -g kcpmux --quick       # فقط kcpmux بدون iperf"
    echo "  ./dc-test.sh -i ir1 -k kh1           # بین ir1 و kh1"
    echo "  ./dc-test.sh --dry-run -v             # فقط config ببین"
    echo ""
}

# ══════════════════════════════════════════════════════════════
#  PARSE ARGUMENTS
# ══════════════════════════════════════════════════════════════

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -g|--group)
                FILTER_GROUP="$2"; shift 2 ;;
            -i|--iran)
                FILTER_IRAN="$2"; shift 2 ;;
            -k|--kharej)
                FILTER_KHAREJ="$2"; shift 2 ;;
            -c|--config)
                CONF_FILE="$2"; shift 2 ;;
            -q|--quick)
                QUICK_MODE=true; shift ;;
            --dry-run)
                DRY_RUN=true; shift ;;
            -v|--verbose)
                VERBOSE=true; shift ;;
            -h|--help)
                show_help; exit 0 ;;
            *)
                echo -e "${RED}❌ Unknown option: $1${NC}"
                show_help; exit 1 ;;
        esac
    done

    if [[ -n "$FILTER_GROUP" ]]; then
        if [[ ! "$FILTER_GROUP" =~ ^(tcpmux|kcpmux|wsmux|wssmux|httpmux|httpsmux)$ ]]; then
            echo -e "${RED}❌ گروه نامعتبر: $FILTER_GROUP${NC}"
            echo "  مقادیر مجاز: tcpmux, kcpmux, wsmux, wssmux, httpmux, httpsmux"
            exit 1
        fi
    fi
}

# ══════════════════════════════════════════════════════════════
#  PARSE servers.conf
# ══════════════════════════════════════════════════════════════

parse_conf() {
    if [[ ! -f "$CONF_FILE" ]]; then
        echo -e "${RED}❌ فایل $CONF_FILE پیدا نشد!${NC}"
        echo -e "  ${CYAN}cp servers.conf.example servers.conf && nano servers.conf${NC}"
        exit 1
    fi

    local section=""
    while IFS= read -r line || [[ -n "$line" ]]; do
        line=$(echo "$line" | sed 's/#.*//' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
        if [[ -z "$line" ]]; then continue; fi

        if [[ "$line" =~ ^\[(.+)\]$ ]]; then
            section="${BASH_REMATCH[1]}"
            continue
        fi

        case "$section" in
            iran|kharej)
                if [[ "$line" =~ ^([a-zA-Z0-9_-]+)[[:space:]]*=[[:space:]]*(.+)$ ]]; then
                    local name="${BASH_REMATCH[1]}"
                    local rest="${BASH_REMATCH[2]}"
                    IFS='|' read -ra parts <<< "$rest"
                    if [[ ${#parts[@]} -lt 4 ]]; then
                        echo -e "${YELLOW}⚠️  خط نامعتبر: $line${NC}"; continue
                    fi
                    local ips_str=$(echo "${parts[0]}" | tr -d ' ')
                    local ssh_port=$(echo "${parts[1]}" | tr -d ' ')
                    local user=$(echo "${parts[2]}" | tr -d ' ')
                    local auth=$(echo "${parts[3]}" | tr -d ' ')

                    if [[ "$section" == "iran" ]]; then
                        IRAN_NAMES+=("$name"); IRAN_IPS+=("$ips_str")
                        IRAN_PORTS+=("$ssh_port"); IRAN_USERS+=("$user"); IRAN_AUTHS+=("$auth")
                    else
                        KHAREJ_NAMES+=("$name"); KHAREJ_IPS+=("$ips_str")
                        KHAREJ_PORTS+=("$ssh_port"); KHAREJ_USERS+=("$user"); KHAREJ_AUTHS+=("$auth")
                    fi
                fi
                ;;
            settings)
                if [[ "$line" =~ ^psk[[:space:]]*=[[:space:]]*(.+)$ ]]; then
                    PSK="${BASH_REMATCH[1]}"
                elif [[ "$line" =~ ^tunnel_port[[:space:]]*=[[:space:]]*([0-9]+)$ ]]; then
                    TUNNEL_PORT="${BASH_REMATCH[1]}"
                elif [[ "$line" =~ ^test_port[[:space:]]*=[[:space:]]*([0-9]+)$ ]]; then
                    TEST_PORT="${BASH_REMATCH[1]}"
                elif [[ "$line" =~ ^test_duration[[:space:]]*=[[:space:]]*([0-9]+)$ ]]; then
                    TEST_DURATION="${BASH_REMATCH[1]}"
                fi
                ;;
        esac
    done < "$CONF_FILE"

    # Apply filters
    if [[ -n "$FILTER_IRAN" ]]; then
        local found=false
        for i in "${!IRAN_NAMES[@]}"; do
            if [[ "${IRAN_NAMES[$i]}" == "$FILTER_IRAN" ]]; then
                local n="${IRAN_NAMES[$i]}" ip="${IRAN_IPS[$i]}" p="${IRAN_PORTS[$i]}" u="${IRAN_USERS[$i]}" a="${IRAN_AUTHS[$i]}"
                IRAN_NAMES=("$n"); IRAN_IPS=("$ip"); IRAN_PORTS=("$p"); IRAN_USERS=("$u"); IRAN_AUTHS=("$a")
                found=true; break
            fi
        done
        if ! $found; then echo -e "${RED}❌ سرور ایران '$FILTER_IRAN' پیدا نشد!${NC}"; exit 1; fi
    fi
    if [[ -n "$FILTER_KHAREJ" ]]; then
        local found=false
        for i in "${!KHAREJ_NAMES[@]}"; do
            if [[ "${KHAREJ_NAMES[$i]}" == "$FILTER_KHAREJ" ]]; then
                local n="${KHAREJ_NAMES[$i]}" ip="${KHAREJ_IPS[$i]}" p="${KHAREJ_PORTS[$i]}" u="${KHAREJ_USERS[$i]}" a="${KHAREJ_AUTHS[$i]}"
                KHAREJ_NAMES=("$n"); KHAREJ_IPS=("$ip"); KHAREJ_PORTS=("$p"); KHAREJ_USERS=("$u"); KHAREJ_AUTHS=("$a")
                found=true; break
            fi
        done
        if ! $found; then echo -e "${RED}❌ سرور خارج '$FILTER_KHAREJ' پیدا نشد!${NC}"; exit 1; fi
    fi

    if [[ ${#IRAN_NAMES[@]} -eq 0 ]]; then echo -e "${RED}❌ هیچ سرور ایرانی تعریف نشده!${NC}"; exit 1; fi
    if [[ ${#KHAREJ_NAMES[@]} -eq 0 ]]; then echo -e "${RED}❌ هیچ سرور خارجی تعریف نشده!${NC}"; exit 1; fi
}

# ══════════════════════════════════════════════════════════════
#  SSH HELPERS
# ══════════════════════════════════════════════════════════════

run_ssh() {
    local ip="$1" port="$2" user="$3" auth="$4"; shift 4
    local cmd="$*"
    local opts="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o LogLevel=ERROR"

    if [[ "$auth" == /* ]]; then
        ssh $opts -i "$auth" -p "$port" "${user}@${ip}" "$cmd" 2>/dev/null
    else
        sshpass -p "$auth" ssh $opts -p "$port" "${user}@${ip}" "$cmd" 2>/dev/null
    fi
}

# ══════════════════════════════════════════════════════════════
#  INSTALL DC + IPERF3
# ══════════════════════════════════════════════════════════════

install_on_server() {
    local label="$1" ip="$2" port="$3" user="$4" auth="$5"

    echo -ne "  ${DIM}[$label] $ip — checking...${NC}"

    local dc_ok=$(run_ssh "$ip" "$port" "$user" "$auth" "test -f $DC_BIN && echo yes || echo no")
    if [[ "$dc_ok" == "yes" ]]; then
        echo -e "\r  ${GREEN}✓${NC} [$label] $ip — DaggerConnect ✔          "
    else
        echo -e "\r  ${YELLOW}⟳${NC} [$label] $ip — Installing DaggerConnect..."
        run_ssh "$ip" "$port" "$user" "$auth" "
            apt-get update -qq >/dev/null 2>&1
            apt-get install -y -qq curl wget jq sshpass >/dev/null 2>&1
            mkdir -p $DC_CONFIG_DIR
            DOWNLOAD_URL=\$(curl -s $GITHUB_API 2>/dev/null | jq -r '.assets[] | select(.name==\"DaggerConnect\") | .browser_download_url' 2>/dev/null)
            if [[ -n \"\$DOWNLOAD_URL\" && \"\$DOWNLOAD_URL\" != \"null\" ]]; then
                wget -q -O $DC_BIN \"\$DOWNLOAD_URL\"
            else
                wget -q -O $DC_BIN ${GITHUB_REPO}/releases/latest/download/DaggerConnect
            fi
            chmod +x $DC_BIN
        " && echo -e "  ${GREEN}✓${NC} [$label] $ip — DaggerConnect installed" \
          || { echo -e "  ${RED}✖${NC} [$label] $ip — install FAILED!"; return 1; }
    fi

    if ! $QUICK_MODE; then
        local iperf_ok=$(run_ssh "$ip" "$port" "$user" "$auth" "which iperf3 >/dev/null 2>&1 && echo yes || echo no")
        if [[ "$iperf_ok" != "yes" ]]; then
            run_ssh "$ip" "$port" "$user" "$auth" "apt-get install -y -qq iperf3 >/dev/null 2>&1"
            echo -e "  ${GREEN}✓${NC} [$label] $ip — iperf3 installed"
        fi
    fi
}

# ══════════════════════════════════════════════════════════════
#  YAML BUILDING BLOCKS
# ══════════════════════════════════════════════════════════════

get_obfus_block() {
    case "$1" in
        disabled) echo 'obfuscation:
  enabled: false' ;;
        light) echo 'obfuscation:
  enabled: true
  min_padding: 8
  max_padding: 256
  min_delay_ms: 2
  max_delay_ms: 20
  burst_chance: 0.1' ;;
        balanced) echo 'obfuscation:
  enabled: true
  min_padding: 16
  max_padding: 512
  min_delay_ms: 5
  max_delay_ms: 50
  burst_chance: 0.15' ;;
        heavy) echo 'obfuscation:
  enabled: true
  min_padding: 64
  max_padding: 2048
  min_delay_ms: 15
  max_delay_ms: 150
  burst_chance: 0.25' ;;
        maximum) echo 'obfuscation:
  enabled: true
  min_padding: 128
  max_padding: 2048
  min_delay_ms: 15
  max_delay_ms: 150
  burst_chance: 0.3' ;;
    esac
}

get_smux_block() {
    case "$1" in
        gaming) echo 'smux:
  keepalive: 2
  max_recv: 16777216
  max_stream: 16777216
  frame_size: 32768
  version: 2' ;;
        aggressive) echo 'smux:
  keepalive: 5
  max_recv: 16777216
  max_stream: 16777216
  frame_size: 32768
  version: 2' ;;
        balanced) echo 'smux:
  keepalive: 8
  max_recv: 8388608
  max_stream: 8388608
  frame_size: 16384
  version: 2' ;;
        cpu-efficient) echo 'smux:
  keepalive: 10
  max_recv: 8388608
  max_stream: 8388608
  frame_size: 8192
  version: 2' ;;
    esac
}

get_kcp_block() {
    case "$1" in
        default) echo 'kcp:
  nodelay: 1
  interval: 10
  resend: 2
  nc: 1
  sndwnd: 256
  rcvwnd: 256
  mtu: 1200' ;;
        aggressive) echo 'kcp:
  nodelay: 1
  interval: 5
  resend: 2
  nc: 1
  sndwnd: 1024
  rcvwnd: 1024
  mtu: 1200' ;;
    esac
}

get_mimicry_block() {
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

# ══════════════════════════════════════════════════════════════
#  GENERATE FULL CONFIGS
# ══════════════════════════════════════════════════════════════

generate_server_yaml() {
    local transport="$1" profile="$2" obfus="$3" smux="$4" chunked="$5" kcp="$6"

    cat <<EOF
mode: "server"
listen: "0.0.0.0:${TUNNEL_PORT}"
transport: "${transport}"
psk: "${PSK}"
profile: "${profile}"
verbose: true
heartbeat: 2
EOF

    # TLS cert
    if [[ "$transport" == "wssmux" || "$transport" == "httpsmux" ]]; then
        echo ""
        echo "cert_file: \"${DC_CONFIG_DIR}/certs/cert.pem\""
        echo "key_file: \"${DC_CONFIG_DIR}/certs/key.pem\""
    fi

    # Port maps
    echo ""
    echo "maps:"
    echo "  - type: tcp"
    echo "    bind: \"0.0.0.0:${TEST_PORT}\""
    echo "    target: \"127.0.0.1:${TEST_PORT}\""
    if ! $QUICK_MODE; then
        echo "  - type: tcp"
        echo "    bind: \"0.0.0.0:5201\""
        echo "    target: \"127.0.0.1:5201\""
    fi

    echo ""
    get_obfus_block "$obfus"
    echo ""
    get_smux_block "$smux"

    # KCP block for kcpmux
    if [[ "$transport" == "kcpmux" ]]; then
        echo ""
        get_kcp_block "$kcp"
    fi

    # HTTP mimicry for http transports
    if [[ "$transport" == "httpmux" || "$transport" == "httpsmux" ]]; then
        echo ""
        get_mimicry_block "$chunked"
    fi

    echo ""
    cat <<'EOF'
advanced:
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
  udp_buffer_size: 262144
EOF
}

generate_client_yaml() {
    local transport="$1" profile="$2" obfus="$3" pool="$4" smux="$5" chunked="$6" kcp="$7" iran_ip="$8"

    cat <<EOF
mode: "client"
psk: "${PSK}"
profile: "${profile}"
verbose: true
heartbeat: 2

paths:
  - transport: "${transport}"
    addr: "${iran_ip}:${TUNNEL_PORT}"
    connection_pool: ${pool}
    aggressive_pool: true
    retry_interval: 1
    dial_timeout: 5
EOF

    echo ""
    get_obfus_block "$obfus"
    echo ""
    get_smux_block "$smux"

    if [[ "$transport" == "kcpmux" ]]; then
        echo ""
        get_kcp_block "$kcp"
    fi

    if [[ "$transport" == "httpmux" || "$transport" == "httpsmux" ]]; then
        echo ""
        get_mimicry_block "$chunked"
    fi

    echo ""
    cat <<'EOF'
advanced:
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
  udp_buffer_size: 262144
EOF
}

# ══════════════════════════════════════════════════════════════
#  SSL CERT
# ══════════════════════════════════════════════════════════════

ensure_ssl_cert() {
    local ip="$1" port="$2" user="$3" auth="$4"
    local exists=$(run_ssh "$ip" "$port" "$user" "$auth" "test -f ${DC_CONFIG_DIR}/certs/cert.pem && echo y || echo n")
    if [[ "$exists" != "y" ]]; then
        run_ssh "$ip" "$port" "$user" "$auth" "
            mkdir -p ${DC_CONFIG_DIR}/certs
            openssl req -x509 -newkey rsa:2048 -keyout ${DC_CONFIG_DIR}/certs/key.pem \
                -out ${DC_CONFIG_DIR}/certs/cert.pem -days 365 -nodes \
                -subj '/CN=www.google.com' 2>/dev/null
        "
    fi
}

# ══════════════════════════════════════════════════════════════
#  DEPLOY + START / STOP
# ══════════════════════════════════════════════════════════════

deploy_and_start() {
    local role="$1" ip="$2" port="$3" user="$4" auth="$5" yaml="$6" transport="$7"

    run_ssh "$ip" "$port" "$user" "$auth" "mkdir -p $DC_CONFIG_DIR; cat > ${DC_CONFIG_DIR}/${role}.yaml << 'DCEOF'
${yaml}
DCEOF"

    if [[ "$role" == "server" && ("$transport" == "wssmux" || "$transport" == "httpsmux") ]]; then
        ensure_ssl_cert "$ip" "$port" "$user" "$auth"
    fi

    run_ssh "$ip" "$port" "$user" "$auth" "
        cat > ${DC_SYSTEMD_DIR}/DaggerConnect-${role}.service << 'SVCEOF'
[Unit]
Description=DaggerConnect ${role}
After=network.target
[Service]
Type=simple
User=root
WorkingDirectory=${DC_CONFIG_DIR}
ExecStart=${DC_BIN} -c ${DC_CONFIG_DIR}/${role}.yaml
Restart=always
RestartSec=3
LimitNOFILE=1048576
[Install]
WantedBy=multi-user.target
SVCEOF
        systemctl daemon-reload
        systemctl stop DaggerConnect-${role} 2>/dev/null || true
        sleep 1
        systemctl start DaggerConnect-${role}
    "
}

stop_dc() {
    local role="$1" ip="$2" port="$3" user="$4" auth="$5"
    run_ssh "$ip" "$port" "$user" "$auth" "systemctl stop DaggerConnect-${role} 2>/dev/null || true"
}

# ══════════════════════════════════════════════════════════════
#  TESTS
# ══════════════════════════════════════════════════════════════

wait_for_tunnel() {
    local ir_ip="$1" ir_p="$2" ir_u="$3" ir_a="$4"
    local kh_ip="$5" kh_p="$6" kh_u="$7" kh_a="$8"
    local w=0

    while [[ $w -lt 20 ]]; do
        local srv=$(run_ssh "$ir_ip" "$ir_p" "$ir_u" "$ir_a" "systemctl is-active DaggerConnect-server 2>/dev/null || echo dead")
        local cli=$(run_ssh "$kh_ip" "$kh_p" "$kh_u" "$kh_a" "systemctl is-active DaggerConnect-client 2>/dev/null || echo dead")

        if [[ "$srv" == "active" && "$cli" == "active" ]]; then
            local ok=$(run_ssh "$kh_ip" "$kh_p" "$kh_u" "$kh_a" "journalctl -u DaggerConnect-client -n 20 --no-pager 2>/dev/null | grep -ci 'session added\|connected\|established' || echo 0")
            if [[ "$ok" -gt 0 ]]; then return 0; fi
        fi
        sleep 1; w=$((w+1))
    done
    return 1
}

measure_latency() {
    local ir_ip="$1" ir_p="$2" ir_u="$3" ir_a="$4" kh_ip="$5"
    local lat=$(run_ssh "$ir_ip" "$ir_p" "$ir_u" "$ir_a" "ping -c 3 -W 3 ${kh_ip} 2>/dev/null | tail -1 | awk -F'/' '{print \$5}'")
    if [[ -n "$lat" && "$lat" != "" ]]; then echo "${lat}ms"; else echo "-"; fi
}

measure_bandwidth() {
    local ir_ip="$1" ir_p="$2" ir_u="$3" ir_a="$4"
    local kh_ip="$5" kh_p="$6" kh_u="$7" kh_a="$8"

    if $QUICK_MODE; then echo "-"; return; fi

    # Start iperf server on kharej
    run_ssh "$kh_ip" "$kh_p" "$kh_u" "$kh_a" "pkill -f 'iperf3 -s' 2>/dev/null; sleep 0.5; iperf3 -s -p 5201 -D 2>/dev/null"
    sleep 2

    # Run iperf client through tunnel on iran
    local bw=$(run_ssh "$ir_ip" "$ir_p" "$ir_u" "$ir_a" "
        iperf3 -c 127.0.0.1 -p 5201 -t ${TEST_DURATION} -P 2 --json 2>/dev/null | \
        python3 -c 'import sys,json;d=json.load(sys.stdin);print(round(d[\"end\"][\"sum_received\"][\"bits_per_second\"]/1e6,1))' 2>/dev/null || echo '-'
    ")

    run_ssh "$kh_ip" "$kh_p" "$kh_u" "$kh_a" "pkill -f 'iperf3 -s' 2>/dev/null"
    if [[ -n "$bw" && "$bw" != "-" ]]; then echo "${bw} Mbps"; else echo "-"; fi
}

# ══════════════════════════════════════════════════════════════
#  RUN ONE SCENARIO
# ══════════════════════════════════════════════════════════════

run_scenario() {
    local scenario="$1"
    local ir_name="$2" ir_ip="$3" ir_p="$4" ir_u="$5" ir_a="$6"
    local kh_name="$7" kh_ip="$8" kh_p="$9" kh_u="${10}" kh_a="${11}"

    IFS='|' read -r group label transport profile obfus pool smux chunked kcp_preset <<< "$scenario"

    local status="❌ FAIL" latency="-" bandwidth="-"

    # DRY RUN
    if $DRY_RUN; then
        echo -e "  ${CYAN}[DRY]${NC} ${BOLD}${label}${NC} — $transport | $profile | obfus=$obfus | pool=$pool | smux=$smux | chunked=$chunked | kcp=$kcp_preset"
        if $VERBOSE; then
            echo "  ─── server.yaml ───"
            generate_server_yaml "$transport" "$profile" "$obfus" "$smux" "$chunked" "$kcp_preset" | head -15
            echo "  ..."
            echo "  ─── client.yaml ───"
            generate_client_yaml "$transport" "$profile" "$obfus" "$pool" "$smux" "$chunked" "$kcp_preset" "$ir_ip" | head -15
            echo "  ..."
        fi
        RESULTS+=("${ir_name}|${kh_name}|${group}|${label}|${ir_ip}|${kh_ip}|🔵 DRY|-|-")
        return
    fi

    echo -ne "  ${DIM}⏳ ${label}...${NC}"

    # Generate YAML
    local srv_yaml=$(generate_server_yaml "$transport" "$profile" "$obfus" "$smux" "$chunked" "$kcp_preset")
    local cli_yaml=$(generate_client_yaml "$transport" "$profile" "$obfus" "$pool" "$smux" "$chunked" "$kcp_preset" "$ir_ip")

    # Stop previous
    stop_dc "server" "$ir_ip" "$ir_p" "$ir_u" "$ir_a"
    stop_dc "client" "$kh_ip" "$kh_p" "$kh_u" "$kh_a"
    sleep 1

    # Deploy
    deploy_and_start "server" "$ir_ip" "$ir_p" "$ir_u" "$ir_a" "$srv_yaml" "$transport"
    deploy_and_start "client" "$kh_ip" "$kh_p" "$kh_u" "$kh_a" "$cli_yaml" "$transport"

    # Wait & test
    if wait_for_tunnel "$ir_ip" "$ir_p" "$ir_u" "$ir_a" "$kh_ip" "$kh_p" "$kh_u" "$kh_a"; then
        status="✅ OK"
        latency=$(measure_latency "$ir_ip" "$ir_p" "$ir_u" "$ir_a" "$kh_ip")
        bandwidth=$(measure_bandwidth "$ir_ip" "$ir_p" "$ir_u" "$ir_a" "$kh_ip" "$kh_p" "$kh_u" "$kh_a")
        echo -e "\r  ${GREEN}✓${NC} ${BOLD}${label}${NC} — ${GREEN}OK${NC}  ping=${CYAN}${latency}${NC}  bw=${YELLOW}${bandwidth}${NC}           "
    else
        local err=$(run_ssh "$kh_ip" "$kh_p" "$kh_u" "$kh_a" "journalctl -u DaggerConnect-client -n 3 --no-pager 2>/dev/null | tail -1 | cut -c1-50" 2>/dev/null || echo "")
        echo -e "\r  ${RED}✖${NC} ${BOLD}${label}${NC} — ${RED}FAIL${NC}  ${DIM}${err}${NC}           "
    fi

    # Stop
    stop_dc "server" "$ir_ip" "$ir_p" "$ir_u" "$ir_a"
    stop_dc "client" "$kh_ip" "$kh_p" "$kh_u" "$kh_a"

    RESULTS+=("${ir_name}|${kh_name}|${group}|${label}|${ir_ip}|${kh_ip}|${status}|${latency}|${bandwidth}")
    sleep 1
}

# ══════════════════════════════════════════════════════════════
#  RESULTS TABLE
# ══════════════════════════════════════════════════════════════

print_results() {
    if [[ ${#RESULTS[@]} -eq 0 ]]; then echo -e "${YELLOW}No results.${NC}"; return; fi

    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                             DaggerConnect Test Results                                   ║${NC}"
    echo -e "${CYAN}╠═══════╤════════╤═════════════╤══════════════════════╤════════════╤════════╤══════════════╣${NC}"
    printf "${CYAN}║${NC} ${BOLD}%-5s${NC} ${CYAN}│${NC} ${BOLD}%-6s${NC} ${CYAN}│${NC} ${BOLD}%-11s${NC} ${CYAN}│${NC} ${BOLD}%-20s${NC} ${CYAN}│${NC} ${BOLD}%-10s${NC} ${CYAN}│${NC} ${BOLD}%-6s${NC} ${CYAN}│${NC} ${BOLD}%-12s${NC} ${CYAN}║${NC}\n" \
        "Iran" "Kharej" "Group" "Test" "Status" "Ping" "Bandwidth"
    echo -e "${CYAN}╠═══════╪════════╪═════════════╪══════════════════════╪════════════╪════════╪══════════════╣${NC}"

    local current_group=""
    for r in "${RESULTS[@]}"; do
        IFS='|' read -ra c <<< "$r"
        local ir="${c[0]}" kh="${c[1]}" grp="${c[2]}" lbl="${c[3]}" irip="${c[4]}" khip="${c[5]}" st="${c[6]}" lat="${c[7]}" bw="${c[8]}"

        # Group separator
        if [[ "$grp" != "$current_group" ]]; then
            if [[ -n "$current_group" ]]; then
                echo -e "${CYAN}╠───────┼────────┼─────────────┼──────────────────────┼────────────┼────────┼──────────────╣${NC}"
            fi
            current_group="$grp"
        fi

        # Color status
        local st_c=""
        if [[ "$st" == *"OK"* ]]; then st_c="${GREEN}${st}${NC}"
        elif [[ "$st" == *"DRY"* ]]; then st_c="${CYAN}${st}${NC}"
        else st_c="${RED}${st}${NC}"; fi

        printf "${CYAN}║${NC} %-5s ${CYAN}│${NC} %-6s ${CYAN}│${NC} %-11s ${CYAN}│${NC} %-20s ${CYAN}│${NC} %-19b ${CYAN}│${NC} %-6s ${CYAN}│${NC} %-12s ${CYAN}║${NC}\n" \
            "$ir" "$kh" "$grp" "$lbl" "$st_c" "$lat" "$bw"
    done

    echo -e "${CYAN}╚═══════╧════════╧═════════════╧══════════════════════╧════════════╧════════╧══════════════╝${NC}"

    # CSV
    RESULTS_CSV="results_${TIMESTAMP}.csv"
    echo "Iran,Kharej,Group,Test,Iran_IP,Kharej_IP,Status,Latency,Bandwidth" > "$RESULTS_CSV"
    for r in "${RESULTS[@]}"; do echo "$r" | tr '|' ','; done >> "$RESULTS_CSV"
    echo ""
    echo -e "${GREEN}📊 Saved: ${RESULTS_CSV}${NC}"

    # Summary
    local total=${#RESULTS[@]}
    local passed=$(printf '%s\n' "${RESULTS[@]}" | grep -c "OK" || true)
    echo -e "${WHITE}Summary:${NC} Total=$total  ${GREEN}Passed=$passed${NC}  ${RED}Failed=$((total-passed))${NC}"
}

# ══════════════════════════════════════════════════════════════
#  BANNER + PLAN
# ══════════════════════════════════════════════════════════════

show_banner() {
    echo -e "${CYAN}"
    echo "  ╔══════════════════════════════════════════════╗"
    echo "  ║   DaggerConnect — Batch Testing Tool         ║"
    echo "  ╚══════════════════════════════════════════════╝"
    echo -e "${NC}"
}

show_plan() {
    # Filter scenarios
    local count=0
    for s in "${SCENARIOS[@]}"; do
        IFS='|' read -r grp rest <<< "$s"
        if [[ -z "$FILTER_GROUP" || "$grp" == "$FILTER_GROUP" ]]; then
            count=$((count+1))
        fi
    done

    # Count server pairs
    local pairs=0
    for ii in "${!IRAN_NAMES[@]}"; do
        IFS=',' read -ra irl <<< "${IRAN_IPS[$ii]}"
        for ki in "${!KHAREJ_NAMES[@]}"; do
            IFS=',' read -ra khl <<< "${KHAREJ_IPS[$ki]}"
            for _ in "${irl[@]}"; do for _ in "${khl[@]}"; do pairs=$((pairs+1)); done; done
        done
    done

    local total=$((count * pairs))

    echo -e "${WHITE}Config:${NC} PSK=${CYAN}${PSK:0:10}...${NC}  Port=${CYAN}${TUNNEL_PORT}${NC}  Quick=${CYAN}${QUICK_MODE}${NC}"
    echo ""
    echo -e "${WHITE}Servers:${NC}"
    for i in "${!IRAN_NAMES[@]}"; do echo -e "  🇮🇷 ${GREEN}${IRAN_NAMES[$i]}${NC}: ${IRAN_IPS[$i]}"; done
    for i in "${!KHAREJ_NAMES[@]}"; do echo -e "  🌍 ${GREEN}${KHAREJ_NAMES[$i]}${NC}: ${KHAREJ_IPS[$i]}"; done
    echo ""
    echo -e "${WHITE}Scenarios: ${YELLOW}${count}${NC} × ${pairs} pair(s) = ${BOLD}${YELLOW}${total} tests${NC}"
    if [[ -n "$FILTER_GROUP" ]]; then
        echo -e "  ${DIM}(filtered: only ${FILTER_GROUP})${NC}"
    fi
    if ! $QUICK_MODE; then
        echo -e "${DIM}  Estimated: ~$((total * (TEST_DURATION + 25) / 60)) minutes${NC}"
    fi
    echo ""
}

# ══════════════════════════════════════════════════════════════
#  MAIN
# ══════════════════════════════════════════════════════════════

main() {
    parse_args "$@"
    show_banner

    # Check sshpass
    if ! command -v sshpass &>/dev/null; then
        echo -e "${YELLOW}⟳ sshpass not found, installing...${NC}"
        apt-get install -y -qq sshpass >/dev/null 2>&1
        if ! command -v sshpass &>/dev/null; then
            echo -e "${RED}❌ sshpass installation failed! Install manually: apt install sshpass${NC}"
            exit 1
        fi
        echo -e "${GREEN}✓ sshpass installed${NC}"
    fi

    parse_conf
    show_plan

    # ── Phase 1: Install ──
    if ! $DRY_RUN; then
        echo -e "${CYAN}══════ Phase 1: Install ══════${NC}"
        declare -A seen=()
        for i in "${!IRAN_NAMES[@]}"; do
            IFS=',' read -ra ips <<< "${IRAN_IPS[$i]}"
            local fip="${ips[0]}"
            if [[ -z "${seen[$fip]+x}" ]]; then
                install_on_server "${IRAN_NAMES[$i]}" "$fip" "${IRAN_PORTS[$i]}" "${IRAN_USERS[$i]}" "${IRAN_AUTHS[$i]}"
                seen[$fip]=1
            fi
        done
        for i in "${!KHAREJ_NAMES[@]}"; do
            IFS=',' read -ra ips <<< "${KHAREJ_IPS[$i]}"
            local fip="${ips[0]}"
            if [[ -z "${seen[$fip]+x}" ]]; then
                install_on_server "${KHAREJ_NAMES[$i]}" "$fip" "${KHAREJ_PORTS[$i]}" "${KHAREJ_USERS[$i]}" "${KHAREJ_AUTHS[$i]}"
                seen[$fip]=1
            fi
        done
        echo ""
    fi

    # ── Phase 2: Test ──
    echo -e "${CYAN}══════ Phase 2: Testing ══════${NC}"

    local current_group=""
    for scenario in "${SCENARIOS[@]}"; do
        IFS='|' read -r grp rest <<< "$scenario"

        # Filter group
        if [[ -n "$FILTER_GROUP" && "$grp" != "$FILTER_GROUP" ]]; then
            continue
        fi

        # Group header
        if [[ "$grp" != "$current_group" ]]; then
            current_group="$grp"
            echo ""
            echo -e "${BOLD}${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            case "$grp" in
                1-transport) echo -e "${BOLD}  📡 Transport Shootout${NC}" ;;
                2-profile)   echo -e "${BOLD}  ⚡ Profile Comparison${NC}" ;;
                3-obfus)     echo -e "${BOLD}  🎭 Obfuscation Levels${NC}" ;;
                4-mimicry)   echo -e "${BOLD}  🌐 HTTP Mimicry Chunked${NC}" ;;
                5-smux)      echo -e "${BOLD}  📊 SMUX Presets${NC}" ;;
                6-kcp)       echo -e "${BOLD}  🚀 KCP Tuning${NC}" ;;
            esac
            echo -e "${BOLD}${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        fi

        # Loop over server pairs
        for ii in "${!IRAN_NAMES[@]}"; do
            IFS=',' read -ra ir_ips <<< "${IRAN_IPS[$ii]}"
            for ki in "${!KHAREJ_NAMES[@]}"; do
                IFS=',' read -ra kh_ips <<< "${KHAREJ_IPS[$ki]}"
                for ir_ip in "${ir_ips[@]}"; do
                    for kh_ip in "${kh_ips[@]}"; do
                        run_scenario "$scenario" \
                            "${IRAN_NAMES[$ii]}" "$ir_ip" "${IRAN_PORTS[$ii]}" "${IRAN_USERS[$ii]}" "${IRAN_AUTHS[$ii]}" \
                            "${KHAREJ_NAMES[$ki]}" "$kh_ip" "${KHAREJ_PORTS[$ki]}" "${KHAREJ_USERS[$ki]}" "${KHAREJ_AUTHS[$ki]}"
                    done
                done
            done
        done
    done

    # ── Phase 3: Results ──
    echo ""
    echo -e "${CYAN}══════ Phase 3: Results ══════${NC}"
    print_results
}

main "$@"
