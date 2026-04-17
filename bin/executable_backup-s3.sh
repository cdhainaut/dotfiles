#!/bin/bash
set -uo pipefail

AWS=~/miniconda/bin/aws
BUCKET="s3://dhainach-backup"
DATE=$(date +%Y-%m-%d)
STORAGE="--storage-class GLACIER"

log() { printf "\n\033[1;36m▶ %s\033[0m\n" "$*"; }
ok()  { printf "\033[1;32m  ✓ %s\033[0m\n" "$*"; }
err() { printf "\033[1;31m  ✗ %s\033[0m\n" "$*"; }

EXCLUDE_COMMON=(
    --exclude "*.tmp" --exclude "*.bak"
    --exclude ".cache/*" --exclude "*/.cache/*"
    --exclude "__pycache__/*" --exclude "*/__pycache__/*"
    --exclude "node_modules/*" --exclude "*/node_modules/*"
    --exclude ".venv/*" --exclude "*/.venv/*"
    --exclude "venv/*" --exclude "*/venv/*"
    --exclude "target/*" --exclude "*/target/*"
    --exclude "build/*" --exclude "*/build/*"
    --exclude "dist/*" --exclude "*/dist/*"
    --exclude "dist_electron/*" --exclude "*/dist_electron/*"
    --exclude "*.pyc"
)

EXCLUDE_DATA=(
    --exclude "*.nc" --exclude "*.grb" --exclude "*.grb2" --exclude "*.grib"
    --exclude "*.dll" --exclude "*.exe"
)

EXCLUDE_MEDIA=(
    --exclude "*.mp4" --exclude "*.MP4"
    --exclude "*.mov" --exclude "*.MOV"
    --exclude "*.avi" --exclude "*.AVI"
    --exclude "*.mkv" --exclude "*.MKV"
)

# ══════════════════════════════════════════════
# Configuration du disque externe (optionnel)
# ══════════════════════════════════════════════
EXTERNAL_MOUNT="/media/charles/Dhainach"
EXTERNAL_BACKUP_ROOT="${EXTERNAL_MOUNT}/backup"
if mountpoint -q "$EXTERNAL_MOUNT" && [ -d "$EXTERNAL_MOUNT" ]; then
    EXTERNAL_ENABLED=1
    log "Disque externe détecté, synchronisation activée vers $EXTERNAL_BACKUP_ROOT"
else
    EXTERNAL_ENABLED=0
    log "Disque externe non monté, synchronisation externe désactivée"
fi

# Fonction pour synchroniser vers le disque externe
sync_external() {
    local src="$1"
    local dst_rel="$2"
    if [ $EXTERNAL_ENABLED -eq 0 ]; then
        return 0
    fi
    local dst="${EXTERNAL_BACKUP_ROOT}/${dst_rel}"
    mkdir -p "$(dirname "$dst")"
    printf "  → externe: %s..." "$dst_rel"
    rsync -av "${EXCLUDE_COMMON[@]}" "${EXCLUDE_DATA[@]}" "${EXCLUDE_MEDIA[@]}" \
        --stats "$src" "$dst" 2>/dev/null && printf " ok\n" || printf " FAIL\n"
}

# Liste des dossiers critiques du home (identique à celle utilisée pour S3)
HOME_CRITICAL=(
    ".ssh"
    ".gnupg"
    ".config/gh"
    ".config/chezmoi"
    ".local/share/chezmoi"
    ".docker"
    ".cdsapirc"
    ".private_keys"
    ".gitlab_wds_token"
    ".aws"
    ".zsh_history"
    ".bash_history"
    ".thunderbird"
    ".mozilla"
    ".config/Signal"
    ".local/share/evolution"
    ".config/evolution"
    "Documents"
    ".claude"
    "system-health"
)

sync_home_critical_external() {
    if [ $EXTERNAL_ENABLED -eq 0 ]; then
        return 0
    fi
    local date=$(date +%Y-%m-%d)
    local dest="${EXTERNAL_BACKUP_ROOT}/home-${date}"
    mkdir -p "$dest"
    log "Synchronisation home critique vers $dest"
    for item in "${HOME_CRITICAL[@]}"; do
        src="/home/charles/$item"
        if [ -e "$src" ]; then
            parent=$(dirname "$item")
            mkdir -p "$dest/$parent"
            printf "  %s..." "$item"
            rsync -av "${EXCLUDE_COMMON[@]}" "${EXCLUDE_DATA[@]}" "${EXCLUDE_MEDIA[@]}" \
                --stats "$src" "$dest/$parent/" 2>/dev/null && printf " ok\n" || printf " FAIL\n"
        else
            printf "  %s... absent\n" "$item"
        fi
    done
    # Fichiers en vrac (PDF, py, md, bib)
    mkdir -p "$dest/loose-files"
    find /home/charles -maxdepth 1 -type f \( -name "*.pdf" -o -name "*.py" -o -name "*.md" -o -name "*.bib" \) -exec cp -v {} "$dest/loose-files/" \; 2>/dev/null
    printf "  loose-files... copiés\n"
    ok "Home critique externe"
}

# ══════════════════════════════════════════════
# 1 — /mnt/data/Work (déjà sur cd-work, on met à jour)
# ══════════════════════════════════════════════
log "1/6 — Work → s3://cd-work/"

dirs=($(ls -d /mnt/data/Work/*/))
total=${#dirs[@]}
i=0

for dir in "${dirs[@]}"; do
    i=$((i + 1))
    name=$(basename "$dir")
    printf "  [%d/%d] %s..." "$i" "$total" "$name"
    # Sync S3
    if $AWS s3 sync "$dir" "s3://cd-work/$name/" \
        "${EXCLUDE_COMMON[@]}" "${EXCLUDE_DATA[@]}" "${EXCLUDE_MEDIA[@]}" \
        --exclude "_backup_*.tar.gz" \
        $STORAGE --quiet 2>/dev/null; then
        printf " ok"
        s3_ok=1
    else
        printf " FAIL"
        s3_ok=0
    fi
    # Sync externe
    sync_external "$dir" "Work/$name/"
    printf "\n"
done
ok "Work ($total dossiers)"

# ══════════════════════════════════════════════
# 2 — /mnt/data hors Work (Personnal, Administrative, Software)
# ══════════════════════════════════════════════
log "2/6 — Personnal + Administrative + Software → $BUCKET/data/"

for dir in Personnal Administrative Software; do
    if [ -d "/mnt/data/$dir" ]; then
        printf "  %s..." "$dir"
        # Sync S3
        if $AWS s3 sync "/mnt/data/$dir/" "$BUCKET/data/$dir/" \
            "${EXCLUDE_COMMON[@]}" $STORAGE --quiet 2>/dev/null; then
            printf " ok"
            s3_ok=1
        else
            printf " FAIL"
            s3_ok=0
        fi
        # Sync externe
        sync_external "/mnt/data/$dir/" "$dir/"
        printf "\n"
    fi
done
ok "Data hors Work"

# ══════════════════════════════════════════════
# 3 — Home critique (clés, configs, Claude)
# ══════════════════════════════════════════════
log "3/5 — Home critique → $BUCKET/home/"

# Tarball des fichiers sensibles (pas en clair sur S3)
TMPTAR=$(mktemp /tmp/home-critical-XXXX.tar.gz)
tar czf "$TMPTAR" \
    -C /home/charles \
    .ssh .gnupg .config/gh .config/chezmoi .docker .cdsapirc .private_keys \
    .gitlab_wds_token .aws \
    .zsh_history .bash_history \
    .config/evolution \
    2>/dev/null
$AWS s3 cp "$TMPTAR" "$BUCKET/home/credentials-$DATE.tar.gz" $STORAGE --quiet && ok "Credentials (chiffré en tar.gz)" || err "Credentials"
rm -f "$TMPTAR"

# Synchronisation home critique vers disque externe
sync_home_critical_external

# Personal IP backup (legal/forensic — STANDARD_IA, pas Glacier)
$AWS s3 sync ~/personal-ip-backup/ "$BUCKET/home/personal-ip-backup/" \
    --storage-class STANDARD_IA --quiet 2>/dev/null && ok "Personal IP backup" || err "Personal IP"

# Claude Code
$AWS s3 sync ~/.claude/ "$BUCKET/home/claude/" \
    "${EXCLUDE_COMMON[@]}" $STORAGE --quiet 2>/dev/null && ok "Claude Code" || err "Claude"

# Documents
$AWS s3 sync ~/Documents/ "$BUCKET/home/Documents/" \
    "${EXCLUDE_COMMON[@]}" $STORAGE --quiet 2>/dev/null && ok "Documents" || err "Documents"

# Chezmoi repo
$AWS s3 sync ~/.local/share/chezmoi/ "$BUCKET/home/chezmoi/" \
    "${EXCLUDE_COMMON[@]}" $STORAGE --quiet 2>/dev/null && ok "Chezmoi repo" || err "Chezmoi"

# Fichiers en vrac
find /home/charles -maxdepth 1 -type f \( -name "*.pdf" -o -name "*.py" -o -name "*.md" -o -name "*.bib" \) -exec \
    $AWS s3 cp {} "$BUCKET/home/loose-files/" $STORAGE --quiet \; 2>/dev/null
ok "Fichiers en vrac"

# ══════════════════════════════════════════════
# 5 — Conda envs (YAML exports)
# ══════════════════════════════════════════════
log "4/5 — Conda envs → $BUCKET/home/conda-envs/"

CONDA_TMP=$(mktemp -d)
for env in $(conda env list --json 2>/dev/null | grep -oP '(?<=envs/)\w+'); do
    conda env export -n "$env" --no-builds > "$CONDA_TMP/$env.yml" 2>/dev/null
done
conda env export -n base --no-builds > "$CONDA_TMP/base.yml" 2>/dev/null
$AWS s3 sync "$CONDA_TMP/" "$BUCKET/home/conda-envs/" $STORAGE --quiet 2>/dev/null
ok "Conda ($(ls "$CONDA_TMP"/*.yml 2>/dev/null | wc -l) envs)"
# Copie vers disque externe
if [ $EXTERNAL_ENABLED -eq 1 ]; then
    mkdir -p "${EXTERNAL_BACKUP_ROOT}/conda-envs"
    cp -v "$CONDA_TMP"/*.yml "${EXTERNAL_BACKUP_ROOT}/conda-envs/" 2>/dev/null
    ok "Conda envs externe"
fi
rm -rf "$CONDA_TMP"

# ══════════════════════════════════════════════
# 6 — System health + monitoring
# ══════════════════════════════════════════════
log "5/5 — System health → $BUCKET/home/system-health/"

$AWS s3 sync ~/system-health/ "$BUCKET/home/system-health/" \
    $STORAGE --quiet 2>/dev/null && ok "System health" || err "System health"
# Synchronisation system health vers disque externe
sync_external ~/system-health/ system-health/

# ══════════════════════════════════════════════
log "Backup S3 terminé — $(date)"
echo ""
echo "  Buckets utilisés:"
echo "    s3://cd-work/          — Work (Glacier)"
echo "    $BUCKET/data/     — Personnal, Admin, Software"
echo "    $BUCKET/home/     — Credentials, Claude, Documents, Conda"
echo ""
