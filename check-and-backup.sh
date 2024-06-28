#!/bin/bash
set -e

# Charger les variables d'environnement du fichier .env
source utils/load-env.sh
source utils/logs.sh

# Fonction pour écrire des messages dans le fichier de log avec la date
log() {
    _log "$1" "check-backup"
}

# Vérifier la présence des variables nécessaires
[ -z "${SERVERS_DIR}" ] && var_notfound "SERVERS_DIR"
[ -z "${PUFFERPANEL_SERVER_ID}" ] && var_notfound "PUFFERPANEL_SERVER_ID"
[ -z "${BACKUP_LOCAL_FOLDER}" ] && var_notfound "BACKUP_LOCAL_FOLDER"
[ -z "${GDRIVE_REMOTE}" ] && var_notfound "GDRIVE_REMOTE"
[ -z "${BACKUP_REMOTE_FOLDER}" ] && var_notfound "BACKUP_REMOTE_FOLDER"

log "Vérification de modification effectuées sur le monde Minecraft."


# Dossier à vérifier
_WORLD_DIR=${SERVERS_DIR}/${PUFFERPANEL_SERVER_ID}

# Vérifie si le dossier cible existe
if [ ! -d "$_WORLD_DIR" ]; then
    log "Erreur : Le dossier cible n'existe pas (${_WORLD_DIR})"
    exit 1
fi

# Générer une nouvelle checksum
NEW_CHECKSUM=$(find "$_WORLD_DIR" -type f -exec sha256sum {} \; | sha256sum | awk '{print $1}')

# Vérifier et créer le fichier de checksum de comparaison s'il n'existe pas
if [ ! -f "$CHECKSUM_FILE" ]; then
    log "Il semble s'agir d'une première exécution, lancement d'une sauvegarde."
    bash "$BACKUP_SCRIPT"
    echo "$NEW_CHECKSUM" > "$CHECKSUM_FILE"
    log "Sauvegarde terminée."
    exit 0
fi

# Lire l'ancienne checksum
OLD_CHECKSUM=$(cat "$CHECKSUM_FILE")

# Comparer les checksums
if [ "$NEW_CHECKSUM" != "$OLD_CHECKSUM" ]; then
    log "Changement détecté. Mise à jour de la checksum et exécution du script de sauvegarde."
    echo "$NEW_CHECKSUM" > "$CHECKSUM_FILE"
    bash "$BACKUP_SCRIPT"
    log "Sauvegarde terminée."
else
    log "Aucun changement détecté. La sauvegarde n'est pas nécessaire."
fi
