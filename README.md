
# Bash Scripts Collection for Linux Server Administration

This repository contains a collection of bash scripts designed for server administration, built as part of a hands-on Ubuntu 22.04 practice project. These scripts are intended to help automate and simplify various administrative tasks on a Linux server, focusing on monitoring system health, managing firewall rules, and other essential server configurations.

Table of Contents
Scripts Overview
System Check Script
Firewall Rules Script
Usage Instructions
Contributing
License
Scripts Overview
1. system_check.sh
Description: This script provides a detailed summary of your system's health by displaying CPU, RAM, disk usage, and network statistics. It uses color-coding to indicate thresholds for each resource, providing an at-a-glance overview of the system's status.
Features:
Color-coded output for CPU, RAM, Disk, and Network.
Displays percentage usage and overall system health.
Thresholds are defined for each resource to help identify potential issues.
2. firewall_rules.sh
Description: This script sets up a set of custom firewall rules using ufw (Uncomplicated Firewall) to manage access control on your server. The rules are configured specifically to manage access to ports like Grafana, SSH, Prometheus, and others, with strict security configurations.
Implemented Firewall Rules:
ALLOW IN: 3000/tcp - Open Grafana port to the public.
ALLOW IN: 22/tcp [ADMIN_IP] - SSH access restricted to a specific admin IP.
DENY: 9090/tcp - Block public access to Prometheus (allowed only to ADMIN and node IPs).
DENY: ALL OTHER - Default deny rule for incoming traffic.
P2P Gossip (tcp/26656) - Bi-directional communication allowed between Hetzner and Dhaka nodes.
Sentry → Validator (tcp/26656) - Communication allowed from SENTRY_IP.
System Check Script (system_check.sh)

This script monitors key system resources and generates a report with color-coded thresholds to help you keep an eye on your server's health. The report includes:

CPU Usage: Displays current usage and whether it's above an acceptable threshold.
RAM Usage: Shows memory usage and provides a warning if usage is too high.
Disk Usage: Provides details on disk space, highlighting any partitions that are nearing capacity.
Network Usage: Displays information on active network connections, bandwidth usage, and identifies any unusual activity.
Example Output
CPU Usage: 45% [Normal]
RAM Usage: 75% [Warning]
Disk Usage: 85% [Critical]
Network: 10Mbps [Normal]
Usage
./system_check.sh
Firewall Rules Script (firewall_rules.sh)

This script configures essential firewall rules using ufw to protect your server from unauthorized access. The rules implemented ensure that only authorized traffic is allowed based on specific IP addresses and ports.

Rules Explained:
Grafana: Public access on port 3000/tcp for monitoring.
SSH: SSH access is restricted to only the admin IP ([ADMIN_IP]).
Prometheus: The Prometheus port (9090) is blocked for public access but allowed only for admin and node IPs.
P2P Gossip: This rule allows bi-directional communication on port 26656 between Hetzner and Dhaka nodes.
Sentry → Validator: A secure communication port (26656) is allowed only from the SENTRY_IP.
Usage
./firewall_rules.sh
Usage Instructions

To use these scripts, follow the steps below:

Clone the repository:

git clone (https://github.com/webrezaul/Script)
cd bash-scripts-linux-admin
Run the scripts:

Make sure the scripts are executable:

chmod +x system_check.sh firewall_rules.sh

Execute the desired script:

./system_check.sh
./firewall_rules.sh

Customize for Your Setup:
Update the [ADMIN_IP] placeholder in firewall_rules.sh to reflect your actual admin IP.
Adjust any thresholds or ports according to your specific server configuration.
Contributing

If you'd like to contribute to this project, feel free to fork the repository and submit a pull request with any improvements or additional scripts. Please ensure that your contributions follow the coding standards used in the project.
