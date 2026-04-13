# Linux Practice Scripts 🐧
 
A collection of bash scripts for Linux server administration — built as part of a hands-on Ubuntu 22.04 practice project.
 
## Scripts
 
| Script |           | Description |
| `system_check.sh` | CPU, RAM, disk, network summary report with color-coded thresholds 

Firewall rules  — implemented exactly:
 What the script does: ALLOW IN: 3000/tcp ANY Grafana open to public ALLOW IN: 22/tcp [ADMIN_IP]SSH only from your admin IP DENY: 9090 from public Prometheus blocked publicly, allowed only to ADMIN + node IPs DENY: ALL OTHER ufw default deny incoming P2P Gossip tcp/26656 bi-directional Allowed from Hetzner + Dhaka nodes both ways Sentry → Validator tcp/26656Allowed from SENTRY_IP
