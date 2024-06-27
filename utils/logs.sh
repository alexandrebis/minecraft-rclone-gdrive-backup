#!/bin/bash

# Fichier de log
LOG_FILE=${LOG_FILE:-./backup.log}

# Fonction pour écrire des messages dans le fichier de log avec la date
_log() {
    SOURCE=${2:-all}
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$2] - $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$2] - $1" >> "$LOG_FILE"
}

var_notfound() {
    log "Error : $1 is not set. Please use .env from .env.dist" && exit 1
}

