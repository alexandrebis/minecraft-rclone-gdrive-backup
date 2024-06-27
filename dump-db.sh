#!/bin/bash
set -e

source utils/load-env.sh
source utils/logs.sh

# Fonction pour écrire des messages dans le fichier de log avec la date
log() {
    _log "$1" "dump-db"
}

log "Début du dump de la base de données"

# Chemins
PUFFERPANEL_DB="${PUFFERPANEL_DB:-/home/opc/minecraft-pufferpanel/pufferpanel.db}"
DUMP_FILE="${DUMP_FILE:-/home/opc/minecraft-pufferpanel/dump.sql}"

# Faire un dump de la base de données
sqlite3 "$PUFFERPANEL_DB" .dump > "$DUMP_FILE"
log "Dump de la base de données créé : $DUMP_FILE"

