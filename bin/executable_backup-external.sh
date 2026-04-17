#!/bin/bash
set -uo pipefail

# Configuration du disque externe
EXTERNAL_MOUNT="/media/charles/Dhainach"
EXTERNAL_BACKUP_ROOT="${EXTERNAL_MOUNT}/backup"
DATE=$(date +%Y-%m-%d)
CONDA=~/miniconda/bin/conda

log() { printf "\n\033[1;36m▶ %s\033[0m\n" "$*"; }
ok()  { printf "\033[1;32m  ✓ %s\033[0m\n" "$*"; }
err() { printf "\033[1;31m  ✗ %s\033[0m\n" "$*"; }

# Exclusions identiques à backup‑s3.sh
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

# Options rsync safe pour NTFS (fuseblk)
RSYNC_OPTS=(-rltD --modify-window=1 --info=progress2)

# Liste des dossiers critiques du home (identique à backup‑s3.sh)
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

# Vérification du montage du disque externe
if ! mountpoint -q "$EXTERNAL_MOUNT" || [ ! -d "$EXTERNAL_MOUNT" ]; then
    err "Le disque externe n'est pas monté sur $EXTERNAL_MOUNT"
    exit 1
fi

log "Démarrage de la sauvegarde vers le disque externe ($EXTERNAL_BACKUP_ROOT)"

# Fonction rsync avec exclusions (NTFS-safe)
sync_to_external() {
    local src="$1"
    local dst_rel="$2"
    local dst="${EXTERNAL_BACKUP_ROOT}/${dst_rel}"
    mkdir -p "$(dirname "$dst")"
    printf "  %s → %s..." "$src" "$dst_rel"
    if rsync "${RSYNC_OPTS[@]}" "${EXCLUDE_COMMON[@]}" "${EXCLUDE_DATA[@]}" "${EXCLUDE_MEDIA[@]}" \
        --stats "$src" "$dst" 2>/dev/null; then
        printf " ok\n"
        return 0
    else
        printf " FAIL\n"
        return 1
    fi
}

# 1 — Work (tous les projets CDxxx)
log "1/4 — Work → $EXTERNAL_BACKUP_ROOT/Work/"
if [ -d "/mnt/data/Work" ]; then
    for dir in /mnt/data/Work/*/; do
        if [ -d "$dir" ]; then
            name=$(basename "$dir")
            sync_to_external "$dir" "Work/$name/"
        fi
    done
    ok "Work"
else
    err "/mnt/data/Work non trouvé"
fi

# 2 — Personnal, Administrative, Software, Media
log "2/4 — Personnal + Administrative + Software + Media → $EXTERNAL_BACKUP_ROOT/"
for subdir in Personnal Administrative Software Media; do
    if [ -d "/mnt/data/$subdir" ]; then
        sync_to_external "/mnt/data/$subdir/" "$subdir/"
    else
        printf "  %s... absent\n" "$subdir"
    fi
done
ok "Données /mnt/data"

# 3 — Home critique (emails, clés, credentials)
log "3/4 — Home critique → $EXTERNAL_BACKUP_ROOT/home-$DATE/"
DEST_HOME="${EXTERNAL_BACKUP_ROOT}/home-${DATE}"
mkdir -p "$DEST_HOME"
for item in "${HOME_CRITICAL[@]}"; do
    src="/home/charles/$item"
    if [ -e "$src" ]; then
        parent=$(dirname "$item")
        mkdir -p "$DEST_HOME/$parent"
        printf "  %s..." "$item"
        if rsync "${RSYNC_OPTS[@]}" "${EXCLUDE_COMMON[@]}" "${EXCLUDE_DATA[@]}" "${EXCLUDE_MEDIA[@]}" \
            --stats "$src" "$DEST_HOME/$parent/" 2>/dev/null; then
            printf " ok\n"
        else
            printf " FAIL\n"
        fi
    else
        printf "  %s... absent\n" "$item"
    fi
done
# Fichiers en vrac (PDF, py, md, bib)
mkdir -p "$DEST_HOME/loose-files"
find /home/charles -maxdepth 1 -type f \( -name "*.pdf" -o -name "*.py" -o -name "*.md" -o -name "*.bib" \) -exec cp -v {} "$DEST_HOME/loose-files/" \; 2>/dev/null
printf "  loose-files... copiés\n"
ok "Home critique"

# 4 — Environnements Conda
log "4/4 — Conda envs → $EXTERNAL_BACKUP_ROOT/conda-envs/"
CONDA_TMP=$(mktemp -d)
for env in $(${CONDA} env list --json 2>/dev/null | grep -oP '(?<=envs/)\w+'); do
    ${CONDA} env export -n "$env" --no-builds > "$CONDA_TMP/$env.yml" 2>/dev/null
done
${CONDA} env export -n base --no-builds > "$CONDA_TMP/base.yml" 2>/dev/null
mkdir -p "${EXTERNAL_BACKUP_ROOT}/conda-envs"
cp -v "$CONDA_TMP"/*.yml "${EXTERNAL_BACKUP_ROOT}/conda-envs/" 2>/dev/null
ok "Conda ($(ls "$CONDA_TMP"/*.yml 2>/dev/null | wc -l) envs)"
rm -rf "$CONDA_TMP"

# 5 — System health (optionnel)
if [ -d "$HOME/system-health" ]; then
    sync_to_external "$HOME/system-health/" "system-health/"
fi

log "Sauvegarde externe terminée — $(date)"
echo ""
echo "  Dossier de destination : $EXTERNAL_BACKUP_ROOT"
echo "    - Work/               — Projets CDxxx"
echo "    - Personnal/          — Données personnelles"
echo "    - Administrative/     — Documents administratifs"
echo "    - Software/           — Installateurs"
echo "    - Media/              — Médias"
echo "    - home-$DATE/         — Home critique (emails, clés, configs)"
echo "    - conda-envs/         — Environnements Conda (YAML)"
echo "    - system-health/      — Rapports de santé système"
echo ""