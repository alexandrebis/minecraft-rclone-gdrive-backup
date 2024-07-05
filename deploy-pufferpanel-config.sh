#!/bin/bash
set -e

source utils/load-env.sh
source utils/logs.sh

# Fonction pour écrire des messages dans le fichier de log avec la date
log() {
    _log "$1" "deploy-pufferpanel-config"
}

log "Début du déploiement de la configuration PufferPanel"

# Chemins
PUFFERPANEL_DB="${PUFFERPANEL_DB:-/home/opc/minecraft-pufferpanel/pufferpanel.db}"
PUFFERPANEL_BINARY="${PUFFERPANEL_BINARY:-/home/opc/minecraft-pufferpanel/pufferpanel}"
CONFIG_JSON="${CONFIG_JSON:-/home/opc/minecraft-pufferpanel/deploy-pufferpanel.json}"

# Fonction pour initialiser la base de données si elle n'existe pas
initialize_db() {
    if [ ! -f "$PUFFERPANEL_DB" ]; then
        log "Base de données non trouvée. Initialisation..."
        "$PUFFERPANEL_BINARY" > /dev/null 2>&1 &
        sleep 1
        pkill -f "$PUFFERPANEL_BINARY"
    fi
}

# Fonction pour ajouter les serveurs à la base de données à partir du fichier JSON
add_servers() {
    jq -c '.servers[]' "$CONFIG_JSON" | while read -r server; do
        name=$(echo "$server" | jq -r '.name')
        identifier=$(echo "$server" | jq -r '.identifier')
        ip=$(echo "$server" | jq -r '.ip')
        port=$(echo "$server" | jq -r '.port')
        type=$(echo "$server" | jq -r '.type')

        sqlite3 "$PUFFERPANEL_DB" <<EOF
INSERT INTO servers (name, identifier, ip, port, type, created_at, updated_at) 
VALUES ('$name', '$identifier', '$ip', $port, '$type', datetime('now'), datetime('now'));
EOF
        log "Ajouté serveur: $name ($identifier)"
    done
}

# Initialiser la base de données si elle n'existe pas
initialize_db

# Ajouter les serveurs à la base de données
add_servers

log "Déploiement de la configuration PufferPanel terminé"

