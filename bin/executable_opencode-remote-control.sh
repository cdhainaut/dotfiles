#!/bin/bash
# OpenCode Remote Control - Équivalent Claude Remote Control
# Lance un serveur ACP sécurisé accessible depuis n'importe quel appareil

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$HOME/.config/opencode/remote-control.conf"
LOG_FILE="$HOME/.local/share/opencode/remote-control.log"
PID_FILE="/tmp/opencode-remote.pid"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log() {
    echo -e "${CYAN}[$(date '+%H:%M:%S')] $1${NC}"
}

info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
}

warn() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

error() {
    echo -e "${RED}✗ $1${NC}"
}

# Créer répertoire config
mkdir -p "$HOME/.config/opencode"
mkdir -p "$HOME/.local/share/opencode"

# Générer ou charger le mot de passe
generate_password() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        # Générer un mot de passe aléatoire sécurisé
        REMOTE_PASSWORD=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 16)
        REMOTE_PORT=4096
        cat > "$CONFIG_FILE" << EOF
# OpenCode Remote Control Configuration
REMOTE_PASSWORD=$REMOTE_PASSWORD
REMOTE_PORT=$REMOTE_PORT
EOF
        chmod 600 "$CONFIG_FILE"
    fi
}

# Obtenir l'IP locale
get_local_ip() {
    hostname -I | awk '{print $1}'
}

# Afficher le QR code pour connexion rapide (si qrencode installé)
show_qr() {
    local url=$1
    if command -v qrencode &> /dev/null; then
        echo ""
        log "QR Code pour connexion rapide :"
        qrencode -t ANSI "$url" 2>/dev/null || true
    fi
}

# Commande: start
start_server() {
    generate_password
    source "$CONFIG_FILE"
    
    # Vérifier si déjà en cours
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        warn "Serveur déjà en cours d'exécution (PID: $(cat $PID_FILE))"
        show_status
        return 0
    fi
    
    log "Démarrage d'OpenCode Remote Control..."
    info "Port: $REMOTE_PORT"
    info "Mot de passe: $REMOTE_PASSWORD"
    
    # Lancer le serveur ACP en arrière-plan
    export OPENCODE_SERVER_PASSWORD=$REMOTE_PASSWORD
    
    opencode acp \
        --port $REMOTE_PORT \
        --hostname 0.0.0.0 \
        --mdns \
        --mdns-domain opencode-remote.local \
        > "$LOG_FILE" 2>&1 &
    
    local PID=$!
    echo $PID > "$PID_FILE"
    
    # Attendre que le serveur démarre
    sleep 2
    
    if kill -0 $PID 2>/dev/null; then
        success "Serveur démarré avec succès (PID: $PID)"
        
        LOCAL_IP=$(get_local_ip)
        
        echo ""
        echo "═══════════════════════════════════════════════════════════════"
        echo -e "${GREEN}  OpenCode Remote Control est ACTIF${NC}"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        echo -e "${CYAN}Pour vous connecter depuis un autre terminal :${NC}"
        echo ""
        echo "  1. Sur le même réseau WiFi :"
        echo -e "     ${YELLOW}opencode attach http://$LOCAL_IP:$REMOTE_PORT --password $REMOTE_PASSWORD${NC}"
        echo ""
        echo "  2. Avec mDNS (si supporté) :"
        echo -e "     ${YELLOW}opencode attach http://opencode-remote.local:$REMOTE_PORT --password $REMOTE_PASSWORD${NC}"
        echo ""
        echo "  3. Depuis ce PC (test) :"
        echo -e "     ${YELLOW}opencode attach http://localhost:$REMOTE_PORT --password $REMOTE_PASSWORD${NC}"
        echo ""
        echo "═══════════════════════════════════════════════════════════════"
        
        # Afficher QR code
        show_qr "opencode attach http://$LOCAL_IP:$REMOTE_PORT --password $REMOTE_PASSWORD"
        
        echo ""
        info "Logs: tail -f $LOG_FILE"
        info "Arrêter: ~/bin/opencode-remote-control.sh stop"
        
    else
        error "Échec du démarrage du serveur"
        rm -f "$PID_FILE"
        return 1
    fi
}

# Commande: stop
stop_server() {
    if [ -f "$PID_FILE" ]; then
        local PID=$(cat "$PID_FILE")
        if kill -0 $PID 2>/dev/null; then
            log "Arrêt du serveur OpenCode Remote (PID: $PID)..."
            kill $PID 2>/dev/null || true
            sleep 1
            
            # Forcer si nécessaire
            if kill -0 $PID 2>/dev/null; then
                kill -9 $PID 2>/dev/null || true
            fi
            
            success "Serveur arrêté"
        else
            warn "Serveur non trouvé (PID: $PID)"
        fi
        rm -f "$PID_FILE"
    else
        warn "Aucun serveur en cours d'exécution"
    fi
}

# Commande: status
show_status() {
    if [ -f "$PID_FILE" ]; then
        local PID=$(cat "$PID_FILE")
        if kill -0 $PID 2>/dev/null; then
            source "$CONFIG_FILE" 2>/dev/null || true
            LOCAL_IP=$(get_local_ip)
            
            success "Serveur ACTIF (PID: $PID)"
            info "URL: http://$LOCAL_IP:${REMOTE_PORT:-4096}"
            info "Mot de passe: ${REMOTE_PASSWORD:-(voir $CONFIG_FILE)}"
            info "Logs: $LOG_FILE"
            
            # Afficher les connexions actives
            if [ -f "$LOG_FILE" ]; then
                local RECENT=$(tail -20 "$LOG_FILE" | grep -i "attach\|connect\|session" | tail -5)
                if [ -n "$RECENT" ]; then
                    echo ""
                    log "Activité récente :"
                    echo "$RECENT"
                fi
            fi
        else
            error "Serveur inactif (PID stale: $PID)"
            rm -f "$PID_FILE"
        fi
    else
        warn "Aucun serveur en cours d'exécution"
        info "Démarrer avec: ~/bin/opencode-remote-control.sh start"
    fi
}

# Commande: logs
show_logs() {
    if [ -f "$LOG_FILE" ]; then
        log "Affichage des logs (Ctrl+C pour quitter)..."
        tail -f "$LOG_FILE"
    else
        warn "Aucun log trouvé"
    fi
}

# Commande: regenerate-password
regenerate_password() {
    rm -f "$CONFIG_FILE"
    generate_password
    source "$CONFIG_FILE"
    success "Nouveau mot de passe généré: $REMOTE_PASSWORD"
    warn "Redémarre le serveur pour appliquer: ~/bin/opencode-remote-control.sh restart"
}

# Commande: restart
restart_server() {
    stop_server
    sleep 1
    start_server
}

# Aide
show_help() {
    cat << 'EOF'
OpenCode Remote Control
Équivalent Claude Remote Control pour OpenCode

Usage: opencode-remote-control.sh [commande]

Commandes:
  start                Démarre le serveur remote
  stop                 Arrête le serveur
  restart              Redémarre le serveur
  status               Affiche le statut
  logs                 Affiche les logs en temps réel
  regenerate-password  Génère un nouveau mot de passe
  help                 Affiche cette aide

Exemples:
  # Démarrer le serveur
  ~/bin/opencode-remote-control.sh start

  # Se connecter depuis un autre terminal
  opencode attach http://192.168.1.42:4096 --password <mot-de-passe>

Configuration:
  Fichier: ~/.config/opencode/remote-control.conf
  Logs:    ~/.local/share/opencode/remote-control.log
EOF
}

# Main
case "${1:-}" in
    start)
        start_server
        ;;
    stop)
        stop_server
        ;;
    restart)
        restart_server
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs
        ;;
    regenerate-password)
        regenerate_password
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "OpenCode Remote Control"
        echo ""
        show_status
        echo ""
        echo "Usage: $0 {start|stop|restart|status|logs|regenerate-password|help}"
        ;;
esac
