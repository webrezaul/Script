#!/bin/bash
# ─────────────────────────────────────────────
#  Monitor FW Setup — Ubuntu 22.04
#  Based on: PUBLIC MONITORING ZONE architecture
#
#  Firewall Rules (from diagram):
#  ALLOW IN : 3000/tcp ANY        (Grafana — public)
#  ALLOW IN : 22/tcp ADMIN_IP     (SSH — admin only)
#  DENY     : 9090 from public    (Prometheus — restricted)
#  DENY     : ALL OTHER
#
#  Services on Monitor Server:
#  — Grafana        tcp/3000  (public HTTPS)
#  — Prometheus     tcp/9090  (restricted)
#  — Alertmanager   tcp/9093  (internal)
#  — Node Exporter  tcp/9100  (scrape targets)
#  — SSH            tcp/22    (ADMIN_IP only)
#
#  Scrape Targets:
#  — Full Node 1    [HETZNER_IP]:9100, 26660
#  — Full Node 2    [DHAKA_IP]:9100, 26660
#  — Validator      10.0.2.10:9100
#
#  P2P Gossip      tcp/26656  (bi-directional)
#  Sentry → Validator tcp/26656
# ─────────────────────────────────────────────
set -u
set -o pipefail

# ── Colors ────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

LOGFILE="/var/log/monitor_fw.log"

# ─────────────────────────────────────────────
#  CONFIG — EDIT THESE BEFORE RUNNING
# ─────────────────────────────────────────────
ADMIN_IP=""           # Your admin/home IP (SSH access only)
HETZNER_IP=""         # Full Node 1 IP (Hetzner)
DHAKA_IP=""           # Full Node 2 IP (Dhaka)
VALIDATOR_IP=""   # Validator internal IP
SENTRY_IP=""          # Sentry node IP (for tcp/26656)

# ─────────────────────────────────────────────
#  HELPERS
# ─────────────────────────────────────────────

if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}[ERROR] Run as root: sudo ./monitor_fw.sh${NC}"
  exit 1
fi

if ! command -v ufw &>/dev/null; then
  echo -e "${YELLOW}[INFO] Installing UFW...${NC}"
  apt update -qq && apt install -y ufw
fi

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOGFILE"
  echo -e "${GREEN}[LOG]${NC} $1"
}

error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

info() {
  echo -e "${CYAN}[INFO]${NC} $1"
}

banner() {
  echo ""
  echo -e "${BLUE}${BOLD}┌──────────────────────────────────────────────┐${NC}"
  echo -e "${BLUE}${BOLD}│  $1$(printf '%*s' $((45 - ${#1})) '')│${NC}"
  echo -e "${BLUE}${BOLD}└──────────────────────────────────────────────┘${NC}"
}

# Prompt for IPs if not set
collect_ips() {
  banner "IP Configuration"
  echo ""

  if [[ -z "$ADMIN_IP" ]]; then
    read -p "  Enter ADMIN_IP (your SSH access IP): " ADMIN_IP
  fi
  if [[ -z "$HETZNER_IP" ]]; then
    read -p "  Enter HETZNER_IP (Full Node 1): " HETZNER_IP
  fi
  if [[ -z "$DHAKA_IP" ]]; then
    read -p "  Enter DHAKA_IP (Full Node 2): " DHAKA_IP
  fi
  if [[ -z "$SENTRY_IP" ]]; then
    read -p "  Enter SENTRY_IP (Sentry → Validator): " SENTRY_IP
  fi

  echo ""
  echo -e "${CYAN}  Configuration Summary:${NC}"
  echo "  ─────────────────────────────────────────────"
  printf "  %-20s %s\n" "ADMIN_IP:"     "$ADMIN_IP"
  printf "  %-20s %s\n" "HETZNER_IP:"   "$HETZNER_IP"
  printf "  %-20s %s\n" "DHAKA_IP:"     "$DHAKA_IP"
  printf "  %-20s %s\n" "VALIDATOR_IP:" "$VALIDATOR_IP"
  printf "  %-20s %s\n" "SENTRY_IP:"    "$SENTRY_IP"
  echo ""
  read -p "  Confirm and continue? (yes/no): " CONFIRM
  if [[ "$CONFIRM" != "yes" ]]; then
    info "Aborted."
    exit 0
  fi
}

# ─────────────────────────────────────────────
#  CORE FUNCTIONS
# ─────────────────────────────────────────────

# 1. Apply full monitoring zone firewall rules
apply_monitor_fw() {
  banner "Applying Monitor Zone Firewall Rules"
  echo ""

  collect_ips

  info "Resetting UFW to clean state..."
  ufw --force reset

  # ── Defaults ──────────────────────────────
  info "Setting defaults: deny incoming, allow outgoing..."
  ufw default deny incoming
  ufw default allow outgoing

  # ── SSH: ADMIN_IP only ─────────────────────
  info "Allowing SSH (22/tcp) from ADMIN_IP only: $ADMIN_IP"
  ufw allow from "$ADMIN_IP" to any port 22 proto tcp
  log "ALLOW SSH 22/tcp from $ADMIN_IP"

  # ── Grafana: public access ─────────────────
  info "Allowing Grafana (3000/tcp) from ANY..."
  ufw allow 3000/tcp
  log "ALLOW Grafana 3000/tcp from ANY"

  # ── Prometheus: DENY from public ──────────
  # Allow only from admin and scrape target IPs
  info "Restricting Prometheus (9090) — admin & nodes only..."
  ufw allow from "$ADMIN_IP"   to any port 9090 proto tcp
  ufw allow from "$HETZNER_IP" to any port 9090 proto tcp
  ufw allow from "$DHAKA_IP"   to any port 9090 proto tcp
  ufw deny 9090/tcp
  log "ALLOW Prometheus 9090/tcp: $ADMIN_IP, $HETZNER_IP, $DHAKA_IP — DENY public"

  # ── Alertmanager: internal only ───────────
  info "Restricting Alertmanager (9093) — admin only..."
  ufw allow from "$ADMIN_IP" to any port 9093 proto tcp
  ufw deny 9093/tcp
  log "ALLOW Alertmanager 9093/tcp from $ADMIN_IP only"

  # ── Node Exporter: scrape targets only ────
  info "Allowing Node Exporter (9100) from scrape targets only..."
  ufw allow from "$HETZNER_IP"   to any port 9100 proto tcp
  ufw allow from "$DHAKA_IP"     to any port 9100 proto tcp
  ufw allow from "$VALIDATOR_IP" to any port 9100 proto tcp
  ufw allow from "$ADMIN_IP"     to any port 9100 proto tcp
  ufw deny 9100/tcp
  log "ALLOW Node Exporter 9100/tcp: nodes + admin — DENY public"

  # ── P2P Gossip: bi-directional tcp/26656 ──
  info "Allowing P2P Gossip (26656/tcp) bi-directional..."
  ufw allow from "$HETZNER_IP" to any port 26656 proto tcp
  ufw allow from "$DHAKA_IP"   to any port 26656 proto tcp
  ufw allow 26656/tcp
  log "ALLOW P2P Gossip 26656/tcp bi-directional"

  # ── Sentry → Validator tcp/26656 ──────────
  if [[ -n "$SENTRY_IP" ]]; then
    info "Allowing Sentry → Validator (26656/tcp) from $SENTRY_IP..."
    ufw allow from "$SENTRY_IP" to any port 26656 proto tcp
    log "ALLOW Sentry->Validator 26656/tcp from $SENTRY_IP"
  fi

  # ── Enable UFW ─────────────────────────────
  info "Enabling UFW..."
  ufw --force enable

  echo ""
  echo -e "${GREEN}${BOLD}Monitor Zone Firewall applied successfully!${NC}"
  log "Full monitor zone firewall applied."
  echo ""
  ufw status numbered
}

# 2. Show current status
show_status() {
  banner "Current Firewall Status"
  echo ""
  ufw status verbose
  echo ""

  echo -e "${BLUE}  Expected Monitor Zone Rules:${NC}"
  echo "  ─────────────────────────────────────────────────────"
  printf "  ${GREEN}✔${NC}  %-30s %s\n" "3000/tcp ANY"        "Grafana — public"
  printf "  ${YELLOW}⚠${NC}  %-30s %s\n" "22/tcp ADMIN_IP"     "SSH — restricted"
  printf "  ${RED}✘${NC}  %-30s %s\n" "9090 from public"    "Prometheus — blocked"
  printf "  ${YELLOW}⚠${NC}  %-30s %s\n" "9093 ADMIN only"     "Alertmanager — restricted"
  printf "  ${YELLOW}⚠${NC}  %-30s %s\n" "9100 nodes only"     "Node Exporter — restricted"
  printf "  ${GREEN}✔${NC}  %-30s %s\n" "26656/tcp bi-dir"    "P2P Gossip"
  printf "  ${RED}✘${NC}  %-30s %s\n" "ALL OTHER"           "Denied"
  echo ""
}

# 3. Show open ports
show_ports() {
  banner "Listening Ports — Monitor Server"
  echo ""
  printf "  %-10s %-10s %-25s %s\n" "PROTO" "PORT" "ADDRESS" "PROCESS"
  echo "  ──────────────────────────────────────────────────────"
  ss -tulnp | awk 'NR>1 {
    split($5, a, ":")
    port = a[length(a)]
    printf "  %-10s %-10s %-25s %s\n", $1, port, $5, $7
  }' | sort -k2 -n
  echo ""

  echo -e "${BLUE}  Expected services:${NC}"
  for PORT_SVC in "3000:Grafana" "9090:Prometheus" "9093:Alertmanager" "9100:Node-Exporter" "22:SSH" "26656:P2P-Gossip"; do
    PORT="${PORT_SVC%%:*}"
    SVC="${PORT_SVC##*:}"
    if ss -tuln | grep -q ":${PORT} "; then
      echo -e "  ${GREEN}✔${NC}  Port $PORT — $SVC is LISTENING"
    else
      echo -e "  ${RED}✘${NC}  Port $PORT — $SVC NOT listening"
    fi
  done
  echo ""
}

# 4. Test connectivity to scrape targets
test_scrape_targets() {
  banner "Test Scrape Target Connectivity"
  echo ""

  if [[ -z "$HETZNER_IP" || -z "$DHAKA_IP" ]]; then
    collect_ips
  fi

  test_port() {
    local HOST=$1
    local PORT=$2
    local LABEL=$3
    if nc -zw3 "$HOST" "$PORT" 2>/dev/null; then
      echo -e "  ${GREEN}✔${NC}  $LABEL ($HOST:$PORT) — REACHABLE"
    else
      echo -e "  ${RED}✘${NC}  $LABEL ($HOST:$PORT) — UNREACHABLE"
    fi
  }

  echo -e "  ${BLUE}Node Exporter (9100):${NC}"
  test_port "$HETZNER_IP"   "9100" "Full Node 1 (Hetzner)"
  test_port "$DHAKA_IP"     "9100" "Full Node 2 (Dhaka)"
  test_port "$VALIDATOR_IP" "9100" "Validator"

  echo ""
  echo -e "  ${BLUE}P2P Gossip (26660):${NC}"
  test_port "$HETZNER_IP" "26660" "Full Node 1 (Hetzner)"
  test_port "$DHAKA_IP"   "26660" "Full Node 2 (Dhaka)"

  echo ""
  echo -e "  ${BLUE}Local Services:${NC}"
  test_port "127.0.0.1" "3000" "Grafana"
  test_port "127.0.0.1" "9090" "Prometheus"
  test_port "127.0.0.1" "9093" "Alertmanager"
  echo ""
}

# 5. Block an IP quickly
block_ip() {
  banner "Block IP Address"
  echo ""
  read -p "  Enter IP to block: " IP_ADDR
  if [[ ! "$IP_ADDR" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    error "Invalid IP format."
    return
  fi
  ufw deny from "$IP_ADDR" to any
  log "BLOCKED IP: $IP_ADDR"
  echo -e "${RED}IP $IP_ADDR is now BLOCKED.${NC}"
}

# 6. Reset firewall
reset_fw() {
  banner "Reset Firewall"
  echo ""
  warn "This will DELETE all rules!"
  read -p "  Are you sure? (yes/no): " CONFIRM
  if [[ "$CONFIRM" == "yes" ]]; then
    ufw --force reset
    ufw allow 22/tcp
    ufw --force enable
    log "UFW reset. SSH port 22 re-opened."
    echo -e "${GREEN}Reset done. SSH port 22 is open.${NC}"
  else
    info "Cancelled."
  fi
}

# ─────────────────────────────────────────────
#  MAIN MENU
# ─────────────────────────────────────────────
while true; do
  echo ""
  echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}${BOLD}║     Monitor Zone — Firewall Manager          ║${NC}"
  echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  ${BLUE}── Setup ─────────────────────────────────${NC}"
  echo "   1)  Apply full Monitor Zone FW rules"
  echo "   2)  Show current firewall status"
  echo ""
  echo -e "  ${BLUE}── Monitor ───────────────────────────────${NC}"
  echo "   3)  Show listening ports"
  echo "   4)  Test scrape target connectivity"
  echo ""
  echo -e "  ${BLUE}── Manage ────────────────────────────────${NC}"
  echo "   5)  Block an IP address"
  echo "   6)  Reset firewall (keep SSH)"
  echo ""
  echo "   0)  Exit"
  echo ""
  read -p "  Select option [0-6]: " CHOICE

  case $CHOICE in
    1) apply_monitor_fw ;;
    2) show_status ;;
    3) show_ports ;;
    4) test_scrape_targets ;;
    5) block_ip ;;
    6) reset_fw ;;
    0)
      echo -e "${GREEN}Goodbye!${NC}"
      exit 0
      ;;
    *)
      warn "Invalid option. Choose 0–6."
      ;;
  esac
done
