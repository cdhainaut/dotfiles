#!/usr/bin/env bash
# Vérification post-recovery : credentials, services, connectivité
# Lancer après RECOVERY.md étapes 1-8 pour valider que tout est en place
set -uo pipefail

PASS=0
FAIL=0
WARN=0

ok()   { printf "\033[1;32m  ✓ %-20s\033[0m %s\n" "$1" "$2"; PASS=$((PASS + 1)); }
fail() { printf "\033[1;31m  ✗ %-20s\033[0m %s\n" "$1" "$2"; FAIL=$((FAIL + 1)); }
warn() { printf "\033[0;33m  ? %-20s\033[0m %s\n" "$1" "$2"; WARN=$((WARN + 1)); }

echo "=== Vérification post-recovery ==="

# ── Credentials ──
echo ""
echo "--- Clés & credentials ---"

# SSH
if [ -f "$HOME/.ssh/id_ed25519" ]; then
    perms=$(stat -c %a "$HOME/.ssh/id_ed25519")
    if [ "$perms" = "600" ]; then
        ok "SSH key" "id_ed25519 (perms $perms)"
    else
        fail "SSH key" "id_ed25519 exists mais perms=$perms (devrait être 600)"
    fi
else
    fail "SSH key" "~/.ssh/id_ed25519 manquant"
fi

# SSH connectivity
if timeout 5 ssh -T git@github.com 2>&1 | grep -qi "success\|authenticated\|Hi "; then
    ok "SSH → GitHub" "connecté"
else
    warn "SSH → GitHub" "pas de connexion (normal si offline)"
fi

# GPG
if [ -d "$HOME/.gnupg" ] && [ "$(stat -c %a "$HOME/.gnupg")" = "700" ]; then
    gpg_keys=$(gpg --list-secret-keys 2>/dev/null | grep -c "sec" || echo "0")
    ok "GPG keyring" "$gpg_keys clé(s) privée(s)"
else
    fail "GPG keyring" "~/.gnupg manquant ou mauvaises perms"
fi

# GitHub CLI
if [ -f "$HOME/.config/gh/hosts.yml" ]; then
    if gh auth status 2>&1 | grep -q "Logged in"; then
        ok "GitHub CLI" "authentifié ($(gh auth status 2>&1 | grep -oP 'account \K\S+'))"
    else
        fail "GitHub CLI" "config présente mais pas authentifié — lancer: gh auth login"
    fi
else
    fail "GitHub CLI" "~/.config/gh/ manquant"
fi

# Docker
if [ -d "$HOME/.docker" ]; then
    ok "Docker config" "présent"
else
    warn "Docker config" "~/.docker manquant (ok si Docker pas utilisé)"
fi

# Claude Code
if [ -f "$HOME/.claude/settings.json" ]; then
    ok "Claude settings" "présent"
else
    fail "Claude settings" "~/.claude/settings.json manquant"
fi

if [ -x "$HOME/.claude/hooks/notify.sh" ]; then
    ok "Claude hook" "notify.sh exécutable"
else
    fail "Claude hook" "~/.claude/hooks/notify.sh manquant ou non exécutable"
fi

if [ -d "$HOME/.claude/projects" ]; then
    proj_count=$(ls -1d "$HOME/.claude/projects"/*/ 2>/dev/null | wc -l)
    ok "Claude projects" "$proj_count projets/mémoires"
else
    warn "Claude projects" "~/.claude/projects/ manquant (normal si première install)"
fi

# API credentials
[ -f "$HOME/.cdsapirc" ] && ok "CDS API" ".cdsapirc présent" || warn "CDS API" ".cdsapirc manquant"

# ── Data ──
echo ""
echo "--- Données ---"

if mountpoint -q /mnt/data 2>/dev/null; then
    ok "/mnt/data" "monté ($(df -h /mnt/data --output=used | tail -1 | xargs) utilisés)"
else
    fail "/mnt/data" "pas monté — vérifier fstab"
fi

[ -d "/mnt/data/Work" ] && ok "Work" "$(ls -1d /mnt/data/Work/*/ 2>/dev/null | wc -l) dossiers" || fail "Work" "manquant"
[ -d "/mnt/data/Media" ] && ok "Media" "présent" || warn "Media" "manquant"
[ -d "/mnt/data/Personnal" ] && ok "Personnal" "présent" || warn "Personnal" "manquant"

# ── Apps ──
echo ""
echo "--- Applications ---"

[ -d "$HOME/.thunderbird" ] && ok "Thunderbird" "profil présent" || warn "Thunderbird" "~/.thunderbird manquant"
[ -d "$HOME/.mozilla" ] && ok "Firefox" "profil présent" || warn "Firefox" "~/.mozilla manquant"
[ -d "$HOME/.config/Signal" ] && ok "Signal" "config présente" || warn "Signal" "manquant"

# ── Services ──
echo ""
echo "--- Services ---"

if systemctl is-active system-monitor.timer &>/dev/null; then
    next=$(systemctl show system-monitor.timer --property=NextElapseUSecRealtime --value 2>/dev/null)
    ok "Monitoring timer" "actif (next: $next)"
else
    fail "Monitoring timer" "inactif — lancer: sudo systemctl enable --now system-monitor.timer"
fi

sysrq=$(cat /proc/sys/kernel/sysrq 2>/dev/null)
[ "$sysrq" = "1" ] && ok "SysRq" "activé ($sysrq)" || fail "SysRq" "valeur=$sysrq (devrait être 1)"

# ── Conda ──
echo ""
echo "--- Conda ---"

if command -v conda &>/dev/null; then
    env_count=$(conda env list 2>/dev/null | grep -c "envs/" || echo "0")
    ok "Conda" "$env_count environnements"
else
    warn "Conda" "pas dans le PATH (relancer le shell ?)"
fi

# ── Résumé ──
echo ""
echo "=== Résultat: $PASS ok, $FAIL erreurs, $WARN avertissements ==="

if [ "$FAIL" -gt 0 ]; then
    echo ""
    echo "Corriger les erreurs ci-dessus, puis relancer: ~/bin/verify-recovery.sh"
    exit 1
fi
exit 0
