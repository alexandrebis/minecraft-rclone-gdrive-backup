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
[ -z "${WORLD_DIR}" ] && var_notfound "WORLD_DIR"
[ -z "${BACKUP_LOCAL_FOLDER}" ] && var_notfound "BACKUP_LOCAL_FOLDER"
[ -z "${GDRIVE_REMOTE}" ] && var_notfound "GDRIVE_REMOTE"
[ -z "${BACKUP_REMOTE_FOLDER}" ] && var_notfound "BACKUP_REMOTE_FOLDER"

log "Vérification de modification effectuées sur le monde Minecraft."

# Dossier à vérifier
TARGET_DIR="${WORLD_DIR}"
# Fichier pour stocker la checksum de comparaison (nouvel emplacement)
CHECKSUM_FILE="${CHECKSUM_FILE}"
# Script de sauvegarde
BACKUP_SCRIPT="${BACKUP_SCRIPT}"

# Vérifie si le dossier cible existe
if [ ! -d "$TARGET_DIR" ]; then
    log "Erreur : Le dossier cible n'existe pas (${TARGET_DIR})"
    exit 1
fi

# Générer une nouvelle checksum
NEW_CHECKSUM=$(find "$TARGET_DIR" -type f -exec sha256sum {} \; | sha256sum | awk '{print $1}')

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
