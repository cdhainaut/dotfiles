#!/bin/bash
# Surveillance santé PC — ThinkPad E16 Gen 3
# Lancé par systemd timer (root), génère un rapport dans ~USER/system-health/

TARGET_USER="${SUDO_USER:-${USER}}"
TARGET_HOME=$(eval echo "~$TARGET_USER")

REPORT_DIR="$TARGET_HOME/system-health"
mkdir -p "$REPORT_DIR"
TIMESTAMP=$(date +%Y-%m-%d_%H%M)
REPORT="$REPORT_DIR/report-$TIMESTAMP.md"
LATEST="$REPORT_DIR/latest.md"
BASELINE="$REPORT_DIR/.baseline"
ALERTS=""

add_alert() { ALERTS="${ALERTS}\n- **$1**"; }

cat > "$REPORT" <<EOF
# Rapport santé PC — $(date '+%A %d %B %Y, %H:%M')
EOF

# ── SMART NVMe ──
echo -e "\n## Disque NVMe" >> "$REPORT"
NVME_DEV=$(lsblk -dno NAME,TYPE 2>/dev/null | awk '$2=="disk" && /nvme/{print "/dev/"$1; exit}')
if [ -n "$NVME_DEV" ] && command -v smartctl &>/dev/null; then
    SMART=$(smartctl -a "$NVME_DEV" 2>&1)
    HEALTH=$(echo "$SMART" | grep "SMART overall-health" | awk -F': ' '{print $2}')
    INTEGRITY=$(echo "$SMART" | grep "Media and Data Integrity" | awk '{print $NF}')
    UNSAFE=$(echo "$SMART" | grep "Unsafe Shutdowns" | awk '{print $NF}')
    PCT_USED=$(echo "$SMART" | grep "Percentage Used" | awk '{print $NF}' | tr -d '%')
    TEMP_NVME=$(echo "$SMART" | grep "^Temperature:" | awk '{print $2}')
    SPARE=$(echo "$SMART" | grep "Available Spare:" | head -1 | awk '{print $NF}' | tr -d '%')

    echo "| Indicateur | Valeur |" >> "$REPORT"
    echo "|---|---|" >> "$REPORT"
    echo "| Health | $HEALTH |" >> "$REPORT"
    echo "| Media Integrity Errors | $INTEGRITY |" >> "$REPORT"
    echo "| Unsafe Shutdowns | $UNSAFE |" >> "$REPORT"
    echo "| Percentage Used | ${PCT_USED}% |" >> "$REPORT"
    echo "| Available Spare | ${SPARE}% |" >> "$REPORT"
    echo "| Temperature | ${TEMP_NVME}°C |" >> "$REPORT"

    # Comparer les integrity errors avec le baseline
    if [ -f "$BASELINE" ]; then
        PREV_INTEGRITY=$(grep "^integrity=" "$BASELINE" | cut -d= -f2)
        if [ "$INTEGRITY" -gt "$PREV_INTEGRITY" ] 2>/dev/null; then
            add_alert "DISQUE: Media Integrity Errors a augmenté ! $PREV_INTEGRITY -> $INTEGRITY"
        fi
    fi

    [ "$HEALTH" != "PASSED" ] && add_alert "DISQUE: SMART health = $HEALTH"
    [ "$TEMP_NVME" -gt 70 ] 2>/dev/null && add_alert "DISQUE: Température élevée (${TEMP_NVME}°C)"
    [ "$SPARE" -lt 20 ] 2>/dev/null && add_alert "DISQUE: Available Spare faible (${SPARE}%)"

    # Sauver le baseline
    echo "integrity=$INTEGRITY" > "$BASELINE"
    echo "unsafe=$UNSAFE" >> "$BASELINE"
    echo "date=$TIMESTAMP" >> "$BASELINE"
else
    echo "smartctl ou NVMe non disponible" >> "$REPORT"
fi

# ── Filesystems ──
echo -e "\n## Filesystems" >> "$REPORT"
echo '```' >> "$REPORT"
df -h -x tmpfs -x efivarfs 2>/dev/null >> "$REPORT"
echo '```' >> "$REPORT"

# Alerter si une partition dépasse 90%
while read -r pct mount; do
    pct_num=${pct%\%}
    [ "$pct_num" -gt 90 ] 2>/dev/null && add_alert "ESPACE: $mount rempli à ${pct}"
done < <(df -h -x tmpfs -x efivarfs --output=pcent,target 2>/dev/null | tail -n +2)

# État filesystem (si dumpe2fs disponible)
if command -v dumpe2fs &>/dev/null; then
    for part in $(lsblk -lno NAME,FSTYPE 2>/dev/null | awk '$2=="ext4"{print "/dev/"$1}'); do
        state=$(dumpe2fs -h "$part" 2>/dev/null | grep "Filesystem state:" | awk '{print $NF}')
        echo "- $part state: **${state:-unknown}**" >> "$REPORT"
        [ -n "$state" ] && [ "$state" != "clean" ] && add_alert "FILESYSTEM: $part n'est pas clean ($state)"
    done
fi

# ── Températures ──
echo -e "\n## Températures" >> "$REPORT"
if command -v sensors &>/dev/null; then
    CPU_TEMP=$(sensors 2>/dev/null | grep "Tctl:" | awk '{print $2}' | tr -d '+°C')
    GPU_TEMP=$(sensors 2>/dev/null | grep "edge:" | awk '{print $2}' | tr -d '+°C')
    echo "- CPU (k10temp): **${CPU_TEMP:-n/a}°C**" >> "$REPORT"
    echo "- GPU (amdgpu): **${GPU_TEMP:-n/a}°C**" >> "$REPORT"
    echo "- NVMe: **${TEMP_NVME:-n/a}°C**" >> "$REPORT"

    CPU_INT=${CPU_TEMP%.*}
    GPU_INT=${GPU_TEMP%.*}
    [ "$CPU_INT" -gt 85 ] 2>/dev/null && add_alert "TEMP: CPU à ${CPU_TEMP}°C"
    [ "$GPU_INT" -gt 85 ] 2>/dev/null && add_alert "TEMP: GPU à ${GPU_TEMP}°C"
else
    echo "lm-sensors non installé" >> "$REPORT"
fi

# ── RAM ──
echo -e "\n## Mémoire" >> "$REPORT"
echo '```' >> "$REPORT"
free -h >> "$REPORT"
echo '```' >> "$REPORT"

# ── Erreurs kernel récentes ──
echo -e "\n## Erreurs kernel (boot actuel)" >> "$REPORT"
KERR=$(dmesg --level=err,crit,alert,emerg 2>/dev/null | grep -viE "ACPI Error.*thinkpad|kvm_intel|ucsi_acpi" | tail -10)
if [ -n "$KERR" ]; then
    echo '```' >> "$REPORT"
    echo "$KERR" >> "$REPORT"
    echo '```' >> "$REPORT"
    add_alert "KERNEL: erreurs détectées (voir rapport)"
else
    echo "Aucune erreur critique." >> "$REPORT"
fi

# ── Services failed ──
echo -e "\n## Services en erreur" >> "$REPORT"
FAILED=$(systemctl --failed --no-legend 2>/dev/null)
if [ -n "$FAILED" ]; then
    echo '```' >> "$REPORT"
    echo "$FAILED" >> "$REPORT"
    echo '```' >> "$REPORT"
    add_alert "SYSTEMD: services en erreur"
else
    echo "Aucun." >> "$REPORT"
fi

# ── SysRq ──
SYSRQ=$(cat /proc/sys/kernel/sysrq)
echo -e "\n## Divers" >> "$REPORT"
echo "- SysRq: **$SYSRQ** $([ "$SYSRQ" = "1" ] && echo '(OK)' || echo '(ATTENTION: pas à 1)')" >> "$REPORT"
echo "- Kernel: **$(uname -r)**" >> "$REPORT"
echo "- Uptime: **$(uptime -p)**" >> "$REPORT"

# ── Bilan ──
echo -e "\n---\n## Alertes" >> "$REPORT"
if [ -n "$ALERTS" ]; then
    echo -e "$ALERTS" >> "$REPORT"
else
    echo "Aucune alerte. Tout est OK." >> "$REPORT"
fi

# Lien vers le dernier rapport
ln -sf "$REPORT" "$LATEST"
chown -R "$TARGET_USER":"$TARGET_USER" "$REPORT_DIR"

# ── Notification desktop si alertes ──
if [ -n "$ALERTS" ]; then
    ALERT_PLAIN=$(echo -e "$ALERTS" | sed 's/\*\*//g; s/^- /• /')
    TARGET_UID=$(id -u "$TARGET_USER")
    DBUS_ADDR="unix:path=/run/user/${TARGET_UID}/bus"
    sudo -u "$TARGET_USER" \
        DISPLAY=:0 \
        DBUS_SESSION_BUS_ADDRESS="$DBUS_ADDR" \
        notify-send -u critical -i dialog-warning \
        "Santé PC — Alertes détectées" \
        "$ALERT_PLAIN\n\nDétails : ~/system-health/latest.md" 2>/dev/null || true
fi

echo "Rapport généré : $REPORT"
