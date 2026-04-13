#!/bin/bash
# ─────────────────────────────────────────────
#  System Resource Check — Ubuntu 22.04
#  Checks: CPU · RAM · Disk · Network · Uptime
# ─────────────────────────────────────────────
set -e
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

# ── Optional: log to file ─────────────────────
LOGFILE="/var/log/system_check.log"
REPORT_DATE=$(date '+%Y-%m-%d %H:%M:%S')

# ── Thresholds (%) ────────────────────────────
CPU_WARN=70
CPU_CRIT=90
RAM_WARN=75
RAM_CRIT=90
DISK_WARN=75
DISK_CRIT=90

# ─────────────────────────────────────────────
#  HELPER FUNCTIONS
# ─────────────────────────────────────────────

# Print section header
header() {
  echo ""
  echo -e "${BLUE}${BOLD}┌──────────────────────────────────────────┐${NC}"
  echo -e "${BLUE}${BOLD}│  $1$(printf '%*s' $((41 - ${#1})) '')│${NC}"
  echo -e "${BLUE}${BOLD}└──────────────────────────────────────────┘${NC}"
}

# Print a labeled value with status color
print_stat() {
  local LABEL="$1"
  local VALUE="$2"
  local STATUS="$3"   # ok | warn | crit | info

  case $STATUS in
    ok)   COLOR=$GREEN  ; ICON="✔" ;;
    warn) COLOR=$YELLOW ; ICON="⚠" ;;
    crit) COLOR=$RED    ; ICON="✘" ;;
    *)    COLOR=$CYAN   ; ICON="●" ;;
  esac

  printf "  ${COLOR}${ICON}${NC}  %-24s ${COLOR}%s${NC}\n" "$LABEL" "$VALUE"
}

# Determine status based on percentage
get_status() {
  local VAL=$1
  local WARN=$2
  local CRIT=$3
  if   [ "$VAL" -ge "$CRIT" ]; then echo "crit"
  elif [ "$VAL" -ge "$WARN" ]; then echo "warn"
  else echo "ok"
  fi
}

# Draw a simple ASCII bar (width 30)
draw_bar() {
  local PCT=$1
  local FILLED=$(( PCT * 30 / 100 ))
  local EMPTY=$(( 30 - FILLED ))
  local STATUS=$(get_status "$PCT" "$CPU_WARN" "$CPU_CRIT")

  case $STATUS in
    ok)   COLOR=$GREEN  ;;
    warn) COLOR=$YELLOW ;;
    crit) COLOR=$RED    ;;
  esac

  printf "  ${COLOR}["
  printf '%0.s█' $(seq 1 $FILLED)
  printf '%0.s░' $(seq 1 $EMPTY)
  printf "] %d%%${NC}\n" "$PCT"
}

# ─────────────────────────────────────────────
#  TOP BANNER
# ─────────────────────────────────────────────
clear
echo ""
echo -e "${BOLD}${CYAN}  ╔═══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}  ║       SYSTEM RESOURCE REPORT              ║${NC}"
echo -e "${BOLD}${CYAN}  ║       $REPORT_DATE          ║${NC}"
echo -e "${BOLD}${CYAN}  ╚═══════════════════════════════════════════╝${NC}"

# ─────────────────────────────────────────────
#  SYSTEM INFO
# ─────────────────────────────────────────────
header "System Info"

HOSTNAME=$(hostname)
OS=$(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')
KERNEL=$(uname -r)
UPTIME=$(uptime -p)
LOAD=$(uptime | awk -F'load average:' '{print $2}' | xargs)
LOGGED_USERS=$(who | wc -l)

print_stat "Hostname"      "$HOSTNAME"      "info"
print_stat "OS"            "$OS"            "info"
print_stat "Kernel"        "$KERNEL"        "info"
print_stat "Uptime"        "$UPTIME"        "info"
print_stat "Load Average"  "$LOAD"          "info"
print_stat "Logged Users"  "$LOGGED_USERS"  "info"

# ─────────────────────────────────────────────
#  CPU
# ─────────────────────────────────────────────
header "CPU"

CPU_MODEL=$(lscpu | grep 'Model name' | awk -F: '{print $2}' | xargs)
CPU_CORES=$(nproc)
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d. -f1)
CPU_STATUS=$(get_status "$CPU_USAGE" "$CPU_WARN" "$CPU_CRIT")

print_stat "Model"         "$CPU_MODEL"     "info"
print_stat "Cores/Threads" "$CPU_CORES"     "info"
print_stat "Usage"         "${CPU_USAGE}%"  "$CPU_STATUS"
draw_bar "$CPU_USAGE"

# ─────────────────────────────────────────────
#  RAM / MEMORY
# ─────────────────────────────────────────────
header "RAM / Memory"

TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
USED_RAM=$(free -m  | awk '/^Mem:/{print $3}')
FREE_RAM=$(free -m  | awk '/^Mem:/{print $4}')
AVAIL_RAM=$(free -m | awk '/^Mem:/{print $7}')
RAM_PCT=$(awk "BEGIN {printf \"%d\", ($USED_RAM/$TOTAL_RAM)*100}")
RAM_STATUS=$(get_status "$RAM_PCT" "$RAM_WARN" "$RAM_CRIT")

TOTAL_SWAP=$(free -m | awk '/^Swap:/{print $2}')
USED_SWAP=$(free -m  | awk '/^Swap:/{print $3}')

print_stat "Total RAM"     "${TOTAL_RAM} MB"  "info"
print_stat "Used"          "${USED_RAM} MB"   "$RAM_STATUS"
print_stat "Free"          "${FREE_RAM} MB"   "info"
print_stat "Available"     "${AVAIL_RAM} MB"  "info"
print_stat "Usage"         "${RAM_PCT}%"       "$RAM_STATUS"
draw_bar "$RAM_PCT"
print_stat "Swap Total"    "${TOTAL_SWAP} MB" "info"
print_stat "Swap Used"     "${USED_SWAP} MB"  "info"

# ─────────────────────────────────────────────
#  DISK
# ─────────────────────────────────────────────
header "Disk Usage"

echo ""
printf "  %-20s %-8s %-8s %-8s %-6s %s\n" "MOUNT" "TOTAL" "USED" "FREE" "USE%" "STATUS"
echo "  ──────────────────────────────────────────────────────"

df -h --output=target,size,used,avail,pcent | tail -n +2 | while read -r MOUNT SIZE USED AVAIL PCT; do
  PCT_NUM=${PCT%%%}
  DISK_STATUS=$(get_status "$PCT_NUM" "$DISK_WARN" "$DISK_CRIT")
  case $DISK_STATUS in
    ok)   COLOR=$GREEN  ; ICON="✔" ;;
    warn) COLOR=$YELLOW ; ICON="⚠" ;;
    crit) COLOR=$RED    ; ICON="✘" ;;
  esac
  printf "  ${COLOR}${ICON}${NC}  %-18s %-8s %-8s %-8s ${COLOR}%-6s${NC}\n" \
    "$MOUNT" "$SIZE" "$USED" "$AVAIL" "$PCT"
done

# ─────────────────────────────────────────────
#  NETWORK
# ─────────────────────────────────────────────
header "Network"

echo ""
printf "  %-12s %-20s %s\n" "INTERFACE" "IP ADDRESS" "STATE"
echo "  ──────────────────────────────────────────"

ip -o addr show | awk '{print $2, $4, $9}' 2>/dev/null | while read -r IFACE ADDR STATE; do
  # fallback if STATE column missing
  LINK_STATE=$(cat /sys/class/net/"$IFACE"/operstate 2>/dev/null || echo "unknown")
  if [ "$LINK_STATE" = "up" ]; then
    COLOR=$GREEN ; ICON="✔"
  else
    COLOR=$YELLOW ; ICON="○"
  fi
  printf "  ${COLOR}${ICON}${NC}  %-12s %-20s ${COLOR}%s${NC}\n" "$IFACE" "$ADDR" "$LINK_STATE"
done

# Active connections count
CONN=$(ss -tn state established 2>/dev/null | tail -n +2 | wc -l)
echo ""
print_stat "Active TCP connections" "$CONN" "info"

# DNS check
DNS_CHECK=$(nslookup google.com 2>/dev/null | grep -c "Address" || echo "0")
if [ "$DNS_CHECK" -gt 0 ]; then
  print_stat "DNS resolution"   "Working" "ok"
else
  print_stat "DNS resolution"   "Failed"  "crit"
fi

# Internet check
if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
  print_stat "Internet"         "Reachable" "ok"
else
  print_stat "Internet"         "Unreachable" "crit"
fi

# ─────────────────────────────────────────────
#  TOP 5 PROCESSES (by CPU)
# ─────────────────────────────────────────────
header "Top 5 Processes by CPU"

echo ""
printf "  %-8s %-20s %-8s %s\n" "PID" "NAME" "CPU%" "MEM%"
echo "  ──────────────────────────────────────────"
ps aux --sort=-%cpu | awk 'NR>1 && NR<=6 {printf "  %-8s %-20s %-8s %s\n", $2, $11, $3, $4}'

# ─────────────────────────────────────────────
#  SUMMARY STATUS
# ─────────────────────────────────────────────
header "Overall Summary"

echo ""
ISSUES=0

check_summary() {
  local LABEL=$1
  local PCT=$2
  local WARN=$3
  local CRIT=$4
  local STATUS
  STATUS=$(get_status "$PCT" "$WARN" "$CRIT")
  if [ "$STATUS" = "crit" ]; then
    print_stat "$LABEL (${PCT}%)" "CRITICAL — take action" "crit"
    ISSUES=$((ISSUES + 1))
  elif [ "$STATUS" = "warn" ]; then
    print_stat "$LABEL (${PCT}%)" "WARNING — monitor closely" "warn"
    ISSUES=$((ISSUES + 1))
  else
    print_stat "$LABEL (${PCT}%)" "OK" "ok"
  fi
}

check_summary "CPU"  "$CPU_USAGE" "$CPU_WARN" "$CPU_CRIT"
check_summary "RAM"  "$RAM_PCT"   "$RAM_WARN" "$RAM_CRIT"

# Disk summary (root partition)
ROOT_PCT=$(df / | awk 'NR==2{print $5}' | tr -d '%')
check_summary "Disk (/)" "$ROOT_PCT" "$DISK_WARN" "$DISK_CRIT"

echo ""
if [ "$ISSUES" -eq 0 ]; then
  echo -e "  ${GREEN}${BOLD}All systems healthy. No issues detected.${NC}"
else
  echo -e "  ${RED}${BOLD}${ISSUES} issue(s) detected. Review the sections above.${NC}"
fi

# ─────────────────────────────────────────────
#  SAVE REPORT TO LOG
# ─────────────────────────────────────────────
echo ""
echo -e "  ${CYAN}Report saved to: ${LOGFILE}${NC}"
{
  echo "=============================="
  echo " SYSTEM REPORT — $REPORT_DATE"
  echo "=============================="
  echo "Host     : $HOSTNAME"
  echo "OS       : $OS"
  echo "CPU Usage: ${CPU_USAGE}%"
  echo "RAM Usage: ${RAM_PCT}%"
  echo "Disk /   : ${ROOT_PCT}%"
  echo "Issues   : $ISSUES"
  echo ""
} >> "$LOGFILE" 2>/dev/null || true

echo ""
echo -e "${BOLD}${CYAN}  ╔═══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}  ║          END OF REPORT                    ║${NC}"
echo -e "${BOLD}${CYAN}  ╚═══════════════════════════════════════════╝${NC}"
echo ""
