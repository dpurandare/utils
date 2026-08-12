#!/usr/bin/env bash
# Display system information, CPU details, and RAM (including speed).
# RAM speed requires root (dmidecode reads SMBIOS data) — run with sudo for full info.

set -euo pipefail

hr() { printf '%s\n' "----------------------------------------"; }

echo "=== System Information ==="
echo "Hostname:       $(hostname)"
echo "OS:             $(source /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" || uname -s)"
echo "Kernel:         $(uname -r)"
echo "Architecture:   $(uname -m)"
echo "Uptime:         $(uptime -p 2>/dev/null || uptime)"
hr

echo "=== CPU Information ==="
if command -v lscpu >/dev/null 2>&1; then
    lscpu | grep -E '^(Model name|Architecture|CPU\(s\)|Thread|Core|Socket|CPU max MHz|CPU min MHz|CPU MHz)' || true
else
    grep -m1 'model name' /proc/cpuinfo
    nproc_count=$(nproc)
    echo "CPU(s):         $nproc_count"
fi
hr

echo "=== RAM Information ==="
free -h
echo
echo "--- RAM Speed & Module Details ---"
if command -v dmidecode >/dev/null 2>&1; then
    if [ "$EUID" -ne 0 ]; then
        echo "Note: run this script with sudo to see RAM speed (requires dmidecode/root)."
    else
        dmidecode -t memory | awk '
            /^Memory Device$/ { if (locator) print "" ; locator="" }
            /^\t(Locator|Size|Type|Speed|Configured Memory Speed|Manufacturer): / {
                sub(/^\t/, ""); print
            }
            /^\tLocator: / { locator=1 }
        ' | grep -v 'No Module Installed'
    fi
else
    echo "dmidecode not found. Install it (e.g. 'sudo apt install dmidecode') to see RAM speed."
fi
hr

echo "=== Disk Usage ==="
df -hT --total -x tmpfs -x devtmpfs -x squashfs
hr

echo "=== GPU Information ==="
if command -v lspci >/dev/null 2>&1; then
    lspci | grep -iE 'vga|3d|display' || echo "No GPU found via lspci."
else
    echo "lspci not found. Install it (e.g. 'sudo apt install pciutils') to see GPU info."
fi
if command -v nvidia-smi >/dev/null 2>&1; then
    echo
    echo "--- NVIDIA GPU Details ---"
    nvidia-smi --query-gpu=name,memory.total,memory.used,temperature.gpu,utilization.gpu,clocks.sm --format=csv
fi
hr
