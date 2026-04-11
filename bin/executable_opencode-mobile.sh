#!/bin/bash
# OpenCode Mobile - Interface web simplifiée pour contrôle depuis mobile
# Compatible avec tout navigateur mobile

set -euo pipefail

PORT="${OPENCODE_MOBILE_PORT:-3000}"
PASSWORD="${OPENCODE_MOBILE_PASSWORD:-}"
PID_FILE="/tmp/opencode-mobile.pid"

# Générer un mot de passe si non défini
if [ -z "$PASSWORD" ]; then
    PASSWORD=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 12)
fi

echo -e "\033[1;36m═══════════════════════════════════════════════════════════════\033[0m"
echo -e "\033[1;32m  OpenCode Mobile Server\033[0m"
echo -e "\033[1;36m═══════════════════════════════════════════════════════════════\033[0m"
echo ""

# Vérifier si déjà en cours
if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
    echo -e "\033[1;33mServeur déjà actif sur le port $PORT\033[0m"
    echo ""
fi

# Obtenir les IPs
IP_LOCAL=$(hostname -I | awk '{print $1}')

echo -e "\033[1;34mDémarrage du serveur web OpenCode...\033[0m"
echo "  Port: $PORT"
echo "  Mot de passe: \033[1;33m$PASSWORD\033[0m"
echo ""

# Lancer opencode web avec les bonnes options
export OPENCODE_SERVER_PASSWORD="$PASSWORD"

# Créer un wrapper qui lance le serveur web
opencode web \
    --port "$PORT" \
    --hostname 0.0.0.0 \
    --mdns \
    --mdns-domain opencode-mobile.local &

PID=$!
echo $PID > "$PID_FILE"

sleep 3

if kill -0 $PID 2>/dev/null; then
    echo -e "\033[1;36m═══════════════════════════════════════════════════════════════\033[0m"
    echo -e "\033[1;32m  ✓ Serveur actif !\033[0m"
    echo -e "\033[1;36m═══════════════════════════════════════════════════════════════\033[0m"
    echo ""
    echo -e "\033[1;33mDepuis ton téléphone (même WiFi) :\033[0m"
    echo ""
    echo "  1. Ouvre le navigateur"
    echo "  2. Va sur :"
    echo -e "     \033[1;32mhttp://$IP_LOCAL:$PORT\033[0m"
    echo ""
    echo "  3. Entre le mot de passe :"
    echo -e "     \033[1;33m$PASSWORD\033[0m"
    echo ""
    echo -e "\033[1;36m═══════════════════════════════════════════════════════════════\033[0m"
    echo ""
    echo -e "\033[0;90mArrêter : kill $PID\033[0m"
    echo ""
    
    # Garder le script actif pour afficher les logs
    wait $PID
else
    echo -e "\033[1;31m✗ Échec du démarrage\033[0m"
    rm -f "$PID_FILE"
    exit 1
fi
