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
    --exclude ".cache/*" --exclude "__pycache__/*"
    --exclude "node_modules/*" --exclude ".venv/*" --exclude "venv/*"
    --exclude "target/*" --exclude "build/*" --exclude "dist/*"
    --exclude "*.pyc" --exclude ".git/*"
    --exclude "dist_electron/*"
)

EXCLUDE_MEDIA=(
    --exclude "*.mp4" --exclude "*.MP4"
    --exclude "*.mov" --exclude "*.MOV"
    --exclude "*.avi" --exclude "*.AVI"
    --exclude "*.mkv" --exclude "*.MKV"
)

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
    $AWS s3 sync "$dir" "s3://cd-work/$name/" \
        "${EXCLUDE_COMMON[@]}" "${EXCLUDE_MEDIA[@]}" \
        --exclude "_backup_*.tar.gz" \
        $STORAGE --quiet 2>/dev/null && printf " ok\n" || printf " FAIL\n"
done
ok "Work ($total dossiers)"

# ══════════════════════════════════════════════
# 2 — /mnt/data hors Work (Personnal, Administrative, Software)
# ══════════════════════════════════════════════
log "2/6 — Personnal + Administrative + Software → $BUCKET/data/"

for dir in Personnal Administrative Software; do
    if [ -d "/mnt/data/$dir" ]; then
        printf "  %s..." "$dir"
        $AWS s3 sync "/mnt/data/$dir/" "$BUCKET/data/$dir/" \
            "${EXCLUDE_COMMON[@]}" $STORAGE --quiet 2>/dev/null && printf " ok\n" || printf " FAIL\n"
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
    2>/dev/null
$AWS s3 cp "$TMPTAR" "$BUCKET/home/credentials-$DATE.tar.gz" $STORAGE --quiet && ok "Credentials (chiffré en tar.gz)" || err "Credentials"
rm -f "$TMPTAR"

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
rm -rf "$CONDA_TMP"

# ══════════════════════════════════════════════
# 6 — System health + monitoring
# ══════════════════════════════════════════════
log "5/5 — System health → $BUCKET/home/system-health/"

$AWS s3 sync ~/system-health/ "$BUCKET/home/system-health/" \
    $STORAGE --quiet 2>/dev/null && ok "System health" || err "System health"

# ══════════════════════════════════════════════
log "Backup S3 terminé — $(date)"
echo ""
echo "  Buckets utilisés:"
echo "    s3://cd-work/          — Work (Glacier)"
echo "    $BUCKET/data/     — Personnal, Admin, Software"
echo "    $BUCKET/home/     — Credentials, Claude, Documents, Conda"
echo ""
