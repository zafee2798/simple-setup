#!/usr/bin/env bash
set -euo pipefail

echo "=== Stopping Netdata service ==="
sudo systemctl stop netdata 2>/dev/null || echo "Netdata service was not running."

echo
echo "=== Uninstalling Netdata ==="
if [ -x /usr/libexec/netdata/netdata-uninstaller.sh ]; then
    sudo /usr/libexec/netdata/netdata-uninstaller.sh --yes --env /etc/netdata/.environment
elif command -v apt >/dev/null 2>&1 && dpkg -l | grep -q '^ii.*netdata'; then
    echo "Detected an APT-installed Netdata package — removing via apt."
    sudo apt remove --purge -y netdata
else
    echo "Could not find the official uninstaller or an APT package."
    echo "If Netdata was installed a different way, remove it manually."
fi

echo
echo "=== Removing leftover Netdata directories ==="
sudo rm -rf /etc/netdata /var/lib/netdata /var/cache/netdata /opt/netdata

echo
echo "=== Removing custom health alarm config ==="
sudo rm -f /etc/netdata/health.d/custom_cpu_usage.conf 2>/dev/null || true

echo
echo "=== Closing firewall port 19999 ==="
if command -v ufw >/dev/null 2>&1; then
    sudo ufw delete allow 19999/tcp 2>/dev/null || echo "No matching ufw rule found (already removed?)."
else
    echo "ufw not found — if another firewall was configured manually, remove the rule for port 19999 yourself."
fi

echo
echo "=== Removing any leftover test load files ==="
rm -f /tmp/netdata-test-diskfile /tmp/netdata-kickstart.sh

echo
echo "=== Cleanup complete. Netdata has been removed from this system. ==="
