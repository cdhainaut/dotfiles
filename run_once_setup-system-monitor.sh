#!/bin/bash
set -euo pipefail

# Setup surveillance santé PC
# Installe smartmontools, le timer systemd, et configure sysrq
# Skip dans un container (CI/Docker)

in_container() { [ -f /.dockerenv ] || grep -qa 'container=' /proc/1/environ 2>/dev/null; }
if in_container; then
    echo "system-monitor: skip (container détecté)"
    exit 0
fi

SUDO="sudo"
command -v sudo >/dev/null 2>&1 || SUDO=""

# ── Dépendances ──
if ! command -v smartctl &>/dev/null; then
    $SUDO apt-get install -y smartmontools
fi

# ── SysRq (activer tous les magic keys) ──
if [ "$(cat /proc/sys/kernel/sysrq 2>/dev/null)" != "1" ]; then
    echo 1 | $SUDO tee /proc/sys/kernel/sysrq >/dev/null 2>&1 || true
fi
if [ ! -f /etc/sysctl.d/99-sysrq.conf ]; then
    echo "kernel.sysrq = 1" | $SUDO tee /etc/sysctl.d/99-sysrq.conf >/dev/null
fi

# ── Service systemd ──
$SUDO tee /etc/systemd/system/system-monitor.service >/dev/null << EOF
[Unit]
Description=Surveillance santé PC

[Service]
Type=oneshot
ExecStart=$HOME/bin/system-monitor.sh
EOF

$SUDO tee /etc/systemd/system/system-monitor.timer >/dev/null << EOF
[Unit]
Description=Surveillance santé PC — hebdomadaire

[Timer]
OnCalendar=Mon 09:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

$SUDO systemctl daemon-reload
$SUDO systemctl enable --now system-monitor.timer

echo "system-monitor: timer activé (lundi 9h)"
