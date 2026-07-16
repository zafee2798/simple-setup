# Netdata Monitoring Dashboard Project

## Project URL
https://github.com/zafee2798/simple-setup

## Files
- `setup.sh` — installs Netdata, enables the service, and adds a custom
  "CPU > 80%" alert.
- `test_dashboard.sh` — installs `stress-ng` and generates CPU/memory/disk
  load for a set duration, sampling the live Netdata API while it runs.
- `cleanup.sh` — stops the service and fully uninstalls Netdata + its config.

## Manual walkthrough (do this once, by hand, to understand each piece)

1. **Install**
```bash
   curl -Ss https://get.netdata.cloud/kickstart.sh | sh
```
   This installs the agent, starts it as a `systemd` service, and by default
   already collects CPU, memory, disk I/O, network, and dozens of other
   metrics every second — no extra config needed for the basics.

2. **Access the dashboard**
   Open `http://<server-ip>:19999` in a browser. If it's a remote box, make
   sure port 19999 is allowed through the firewall/security group.

3. **Customize a chart**
   Easiest built-in customization: on any chart, use the gear icon to change
   its type (line/area/stacked), or click-drag to zoom a time range and pin
   it. For something more hands-on, add a **custom chart definition** via a
   Python collector (`/etc/netdata/python.d/`) or, simplest of all, add a
   **custom dashboard info line** by editing `/etc/netdata/netdata.conf`
   under `[web]` → `custom dashboard_info.js` to tweak titles/descriptions.
   The scripts here take the simplest reliable route: a **custom alarm**
   (below) plus resizing/re-ordering charts in the browser, which persists
   in your browser's local dashboard layout.

4. **Set an alert**
   Netdata alerts live as small text files in `/etc/netdata/health.d/`.
   `setup.sh` drops in `custom-cpu-alert.conf`, which warns at 80% average
   CPU over 1 minute and goes critical at 95%. Health config is reloaded
   without restarting all of Netdata using `netdatacli reload-health`.

5. **Test it**
   Run `test_dashboard.sh` (needs root or sudo for installing `stress-ng`
   the first time) to spike CPU/memory/disk and watch the "cpu_usage_high"
   alarm move from clear → warning → (optionally) critical in the
   dashboard's Alarms tab.

6. **Clean up**
   `cleanup.sh` stops the service and removes the agent, its config, and
   data directories, using Netdata's own uninstaller when present.

## Order of operations
```bash
sudo ./setup.sh
./test_dashboard.sh 90        # 90-second load test
sudo ./cleanup.sh              # when you're done
```


## Project Page
https://github.com/zafee2798/simple-setup
