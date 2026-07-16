#!/usr/bin/env bash
set -euo pipefail

echo "=== Installing Netdata ==="
wget -O ~/netdata-kickstart.sh https://get.netdata.cloud/kickstart.sh
TMPDIR=~/netdata-tmp sh ~/netdata-kickstart.sh --non-interactive --stable-channel --disable-telemetry

echo
echo "=== Enabling and starting the Netdata service ==="
sudo systemctl enable --now netdata
sudo systemctl status netdata --no-pager || true

echo
echo "=== Configuring firewall access to the dashboard (port 19999) ==="
if command -v ufw >/dev/null 2>&1; then
    sudo ufw allow 19999/tcp
    echo "Allowed port 19999/tcp through ufw."
else
    echo "ufw not found — skipping firewall configuration."
    echo "If another firewall is in use, manually allow TCP port 19999."
fi

echo
echo "=== Installing custom health alarm (CPU usage above 80%) ==="
CUSTOM_HEALTH_DIR="/etc/netdata/health.d"
sudo mkdir -p "$CUSTOM_HEALTH_DIR"

sudo tee "$CUSTOM_HEALTH_DIR/custom_cpu_usage.conf" > /dev/null << 'INNEREOF'
# Custom alarm: warns when total CPU usage stays above 80% for 1 minute.
template: cpu_usage_high
      on: system.cpu
   class: Utilization
    type: System
component: CPU
  lookup: average -1m unaligned of user,system,softirq,irq,guest
   units: %
   every: 10s
    warn: $this > 80
    crit: $this > 90
   delay: down 5m multiplier 1.5 max 1h
    info: average total CPU utilization over the last minute
      to: sysadmin
INNEREOF

echo "Custom alarm written to $CUSTOM_HEALTH_DIR/custom_cpu_usage.conf"

echo
echo "=== Reloading Netdata health configuration ==="
sudo systemctl restart netdata

echo
echo "=== Done ==="
IP_ADDR=$(hostname -I | awk '{print $1}')
echo "Netdata dashboard should now be available at: http://${IP_ADDR}:19999"
