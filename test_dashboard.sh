#!/usr/bin/env bash
#
# test_dashboard.sh - Put load on the system and verify Netdata is capturing it.
#
# What it does:
#   1. Installs stress-ng if it isn't already present (best-effort, needs a package manager).
#   2. Generates CPU, memory, and disk I/O load for a configurable duration.
#   3. While load is running, queries the local Netdata REST API to pull live
#      values for CPU and memory so you can see the numbers move, right from the terminal.
#   4. Prints the dashboard URL so you can watch the charts update in your browser
#      at the same time.
#
# Usage:
#   ./test_dashboard.sh [duration_seconds]
#   (default duration: 60 seconds)
#
set -euo pipefail

DURATION="${1:-60}"
NETDATA_URL="http://206.81.9.66:19999"

log()  { echo -e "[test] $*"; }
err()  { echo -e "[test][ERROR] $*" >&2; }

# ---------------------------------------------------------------------------
# 0. Sanity checks
# ---------------------------------------------------------------------------
if ! curl -sf "${NETDATA_URL}/api/v1/info" >/dev/null 2>&1; then
  err "Cannot reach Netdata at ${NETDATA_URL}. Is it installed and running? (run setup.sh first)"
  exit 1
fi
log "Netdata is reachable at ${NETDATA_URL}"

# ---------------------------------------------------------------------------
# 1. Ensure stress-ng is available
# ---------------------------------------------------------------------------
if ! command -v stress-ng >/dev/null 2>&1; then
  log "stress-ng not found, attempting to install it..."
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update -y && apt-get install -y stress-ng
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y stress-ng
  elif command -v yum >/dev/null 2>&1; then
    yum install -y stress-ng
  elif command -v pacman >/dev/null 2>&1; then
    pacman -Sy --noconfirm stress-ng
  else
    err "No supported package manager found. Please install stress-ng manually and re-run."
    exit 1
  fi
fi

CPU_CORES=$(nproc)
log "Detected ${CPU_CORES} CPU core(s)."
log "Generating load for ${DURATION}s: CPU workers, memory (VM) workers, and disk I/O..."

# ---------------------------------------------------------------------------
# 2. Generate load in the background
#    --cpu N          spin up N CPU stressors
#    --vm 2 --vm-bytes generate memory pressure
#    --hdd 1 --hdd-bytes  generate disk I/O in a temp file
# ---------------------------------------------------------------------------
WORKDIR=$(mktemp -d)
stress-ng \
  --cpu "${CPU_CORES}" \
  --vm 2 --vm-bytes 256M --vm-keep \
  --hdd 1 --hdd-bytes 512M --temp-path "${WORKDIR}" \
  --timeout "${DURATION}s" \
  --metrics-brief &
STRESS_PID=$!

log "stress-ng running (pid ${STRESS_PID}). Open this in your browser to watch it live:"
log "  ${NETDATA_URL}"

# ---------------------------------------------------------------------------
# 3. Poll the Netdata API a few times while load is running
# ---------------------------------------------------------------------------
SAMPLES=5
INTERVAL=$(( DURATION / SAMPLES ))
[[ $INTERVAL -lt 5 ]] && INTERVAL=5

for i in $(seq 1 "$SAMPLES"); do
  sleep "$INTERVAL"
  CPU_VAL=$(curl -s "${NETDATA_URL}/api/v1/data?chart=system.cpu&points=1&after=-1&format=json" \
    | grep -oE '"user":[0-9.]+|"system":[0-9.]+' | head -n 1 || true)
  MEM_VAL=$(curl -s "${NETDATA_URL}/api/v1/data?chart=system.ram&points=1&after=-1&format=json" \
    | grep -oE '"used":[0-9.]+' | head -n 1 || true)
  log "sample ${i}/${SAMPLES} -> ${CPU_VAL:-cpu:n/a}  ${MEM_VAL:-mem:n/a}"
done

wait "$STRESS_PID" 2>/dev/null || true
rm -rf "$WORKDIR"

log "Load test complete."
log "Check the Netdata dashboard (${NETDATA_URL}) and the 'cpu_usage_high' alarm"
log "(Alarms tab) to confirm it triggered a warning/critical state during the test."
