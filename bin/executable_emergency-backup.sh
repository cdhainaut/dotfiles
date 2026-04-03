#!/bin/bash
set -uo pipefail

DEST="/media/charles/Dhainach/backup"
DATE=$(date +%Y-%m-%d)

log() { printf "\n\033[1;36m▶ %s\033[0m\n" "$*"; }
ok()  { printf "\033[1;32m  ✓ %s\033[0m\n" "$*"; }
err() { printf "\033[1;31m  ✗ %s\033[0m\n" "$*"; }
info(){ printf "\033[0;33m    %s\033[0m\n" "$*"; }

# NTFS-safe rsync (pas de permissions/owner, tolérance timestamps)
RS=(-rltD --modify-window=1 -v --info=progress2)

# Vérifier que le disque est monté
if [ ! -d "$DEST" ]; then
    err "Disque externe non monté ($DEST)"
    exit 1
fi

# ══════════════════════════════════════════════
# PHASE 1 — Fichiers critiques de ~
# ══════════════════════════════════════════════
log "Phase 1 — Fichiers critiques (clés, credentials, configs)"

HOME_BACKUP="$DEST/home-$DATE"
mkdir -p "$HOME_BACKUP"

# SSH + GPG
# SSH + GPG
rsync "${RS[@]}" ~/.ssh/ "$HOME_BACKUP/.ssh/" && ok "Clés SSH" || err "SSH copy failed"
rsync "${RS[@]}" ~/.gnupg/ "$HOME_BACKUP/.gnupg/" && ok "Clés GPG" || err "GPG copy failed"

# Credentials
mkdir -p "$HOME_BACKUP/.config"
rsync "${RS[@]}" ~/.config/gh/ "$HOME_BACKUP/.config/gh/" 2>/dev/null && ok "GitHub CLI" || true
rsync "${RS[@]}" ~/.docker/ "$HOME_BACKUP/.docker/" 2>/dev/null && ok "Docker" || true
cp ~/.cdsapirc "$HOME_BACKUP/" 2>/dev/null && ok "CDS API" || true
cp ~/.private_keys "$HOME_BACKUP/" 2>/dev/null && ok "Private keys" || true

# Claude Code (settings, projects, mémoires, hooks)
rsync "${RS[@]}" --copy-links ~/.claude/ "$HOME_BACKUP/.claude/" && ok "Claude Code ($(du -sh ~/.claude/ | cut -f1))" || err "Claude copy failed"

# Shell history
cp ~/.zsh_history "$HOME_BACKUP/" 2>/dev/null && ok "Zsh history" || true
cp ~/.bash_history "$HOME_BACKUP/" 2>/dev/null && ok "Bash history" || true

# Documents perso
rsync "${RS[@]}" ~/Documents/ "$HOME_BACKUP/Documents/" 2>/dev/null && ok "Documents ($(du -sh ~/Documents/ | cut -f1))" || true

# Fichiers en vrac dans ~ (PDFs, scripts, configs)
mkdir -p "$HOME_BACKUP/loose-files"
find /home/charles -maxdepth 1 -type f \( -name "*.pdf" -o -name "*.py" -o -name "*.png" -o -name "*.md" -o -name "*.rdp" -o -name "*.bib" -o -name "*.txt" \) -exec cp {} "$HOME_BACKUP/loose-files/" \; 2>/dev/null
ok "Fichiers en vrac (~/ PDFs, scripts, etc.)"

# Téléchargements
rsync "${RS[@]}" ~/Téléchargements/ "$HOME_BACKUP/Téléchargements/" 2>/dev/null && ok "Téléchargements ($(du -sh ~/Téléchargements/ | cut -f1))" || true

# Images
rsync "${RS[@]}" ~/Images/ "$HOME_BACKUP/Images/" 2>/dev/null && ok "Images" || true

# Zotero
rsync "${RS[@]}" ~/Zotero/ "$HOME_BACKUP/Zotero/" 2>/dev/null && ok "Zotero" || true

# System health reports
rsync "${RS[@]}" ~/system-health/ "$HOME_BACKUP/system-health/" 2>/dev/null && ok "System health" || true

# Conda environments (export YAML)
CONDA_EXPORT="$DEST/conda-envs"
mkdir -p "$CONDA_EXPORT"
if command -v conda &>/dev/null; then
    for env in $(conda env list --json 2>/dev/null | grep -oP '(?<=envs/)\w+'); do
        conda env export -n "$env" --no-builds > "$CONDA_EXPORT/$env.yml" 2>/dev/null
    done
    conda env export -n base --no-builds > "$CONDA_EXPORT/base.yml" 2>/dev/null
    ok "Conda envs ($(ls "$CONDA_EXPORT"/*.yml 2>/dev/null | wc -l) environnements)"
fi

# ══════════════════════════════════════════════
# PHASE 2 — Chezmoi (vérif + backup du repo)
# ══════════════════════════════════════════════
log "Phase 2 — Chezmoi dotfiles"

CHEZMOI_STATUS=$(cd ~/.local/share/chezmoi && git status --porcelain)
if [ -z "$CHEZMOI_STATUS" ]; then
    ok "Chezmoi repo clean — à jour sur GitHub"
else
    err "Chezmoi a des modifs non commitées !"
    (cd ~/.local/share/chezmoi && git status --short)
fi
rsync "${RS[@]}" ~/.local/share/chezmoi/ "$HOME_BACKUP/chezmoi-repo/" && ok "Chezmoi repo copié" || err "Chezmoi copy failed"

# ══════════════════════════════════════════════
# PHASE 3 — Repos git avec travail non pushé
# ══════════════════════════════════════════════
log "Phase 3 — Repos git avec travail non pushé"

DIRTY_REPOS=0
check_and_warn_repo() {
    local repo_dir="$1"
    local name=$(basename "$repo_dir")
    local parent=$(basename "$(dirname "$repo_dir")")
    local label="$parent/$name"

    local uncommitted=$(git -C "$repo_dir" status --porcelain 2>/dev/null | wc -l)
    local unpushed=$(git -C "$repo_dir" log --oneline @{upstream}..HEAD 2>/dev/null | wc -l)

    if [ "$uncommitted" -gt 0 ] || [ "$unpushed" -gt 0 ]; then
        err "$label : $uncommitted fichiers modifiés, $unpushed commits non pushés"
        DIRTY_REPOS=$((DIRTY_REPOS + 1))
    fi
}

while IFS= read -r gitdir; do
    repo=$(dirname "$gitdir")
    check_and_warn_repo "$repo"
done < <(find /mnt/data/Work -maxdepth 4 -name ".git" -type d 2>/dev/null)

if [ "$DIRTY_REPOS" -eq 0 ]; then
    ok "Tous les repos sont propres"
else
    err "$DIRTY_REPOS repo(s) avec du travail non sauvegardé — pense à commit+push !"
fi

# ══════════════════════════════════════════════
# PHASE 4 — Rsync /mnt/data (backup principal)
# ══════════════════════════════════════════════
log "Phase 4 — Rsync /mnt/data → disque externe"

EXCLUDE_FILE="/media/charles/Dhainach/backup/exclude-list.txt"
RSYNC_OPTS=("${RS[@]}" --stats)
RSYNC_OPTS+=(--exclude="node_modules/" --exclude="__pycache__/" --exclude=".venv/" --exclude="venv/" --exclude="target/" --exclude="build/" --exclude="dist/" --exclude="*.pyc")
if [ -f "$EXCLUDE_FILE" ]; then
    RSYNC_OPTS+=(--exclude-from="$EXCLUDE_FILE")
fi

for dir in Work Personnal Administrative Software Media; do
    if [ -d "/mnt/data/$dir" ]; then
        src_count=$(ls -1A "/mnt/data/$dir" 2>/dev/null | wc -l)
        if [ "$src_count" -lt 2 ]; then
            err "SKIP $dir — source quasi vide ($src_count entrées), suspect"
            continue
        fi
        log "  Sync $dir..."
        rsync "${RSYNC_OPTS[@]}" "/mnt/data/$dir/" "$DEST/$dir/"
        ok "$dir"
    fi
done

# ══════════════════════════════════════════════
# PHASE 5 — Apps lourdes de ~
# ══════════════════════════════════════════════
log "Phase 5 — Apps lourdes (Thunderbird, Firefox, Signal)"

APPS_BACKUP="$HOME_BACKUP/apps"
mkdir -p "$APPS_BACKUP"

rsync "${RS[@]}" ~/.thunderbird/ "$APPS_BACKUP/thunderbird/" 2>/dev/null && ok "Thunderbird ($(du -sh ~/.thunderbird/ | cut -f1))" || true
rsync "${RS[@]}" ~/.mozilla/ "$APPS_BACKUP/mozilla/" 2>/dev/null && ok "Firefox ($(du -sh ~/.mozilla/ | cut -f1))" || true
rsync "${RS[@]}" ~/.config/Signal/ "$APPS_BACKUP/Signal/" 2>/dev/null && ok "Signal ($(du -sh ~/.config/Signal/ | cut -f1))" || true

# ══════════════════════════════════════════════
# Résumé
# ══════════════════════════════════════════════
log "Backup terminé"
echo ""
echo "  Disque externe : $(df -h /media/charles/Dhainach/ | tail -1 | awk '{print $4}') restant"
echo "  Home backup    : $HOME_BACKUP"
echo "  Date           : $DATE"
if [ "$DIRTY_REPOS" -gt 0 ]; then
    echo ""
    err "ATTENTION: $DIRTY_REPOS repo(s) avec du travail non pushé !"
fi
echo ""
