#!/bin/bash
set -e

# Dossier à vérifier
TARGET_DIR="/home/opc/minecraft-pufferpanel/servers/dffe1cd5/cornichons/"
# Fichier pour stocker la checksum de comparaison (nouvel emplacement)
CHECKSUM_FILE="/home/opc/minecraft-rclone-gdrive-backup/checksum.sha256"
# Script de sauvegarde
BACKUP_SCRIPT="/home/opc/minecraft-rclone-gdrive-backup/backup-minecraft-server.sh"
# Fichier de log
LOG_FILE="/home/opc/minecraft-rclone-gdrive-backup/check_and_backup.log"

# Fonction pour écrire des messages dans le fichier de log avec la date
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

log "Début du script de vérification et de sauvegarde."

# Générer une nouvelle checksum
log "Génération de la nouvelle checksum pour le dossier : $TARGET_DIR"
NEW_CHECKSUM=$(find "$TARGET_DIR" -type f -exec sha256sum {} \; | sha256sum | awk '{print $1}')
log "Nouvelle checksum générée : $NEW_CHECKSUM"

# Vérifier et créer le fichier de checksum de comparaison s'il n'existe pas
if [ ! -f "$CHECKSUM_FILE" ]; then
    log "Fichier de checksum de comparaison non trouvé. Création du fichier avec la nouvelle checksum."
    echo "$NEW_CHECKSUM" > "$CHECKSUM_FILE"
    log "Checksum sauvegardée dans : $CHECKSUM_FILE"
    # Exécuter le script de sauvegarde car c'est la première exécution
    log "Première exécution détectée, lancement du script de sauvegarde : $BACKUP_SCRIPT"
    bash "$BACKUP_SCRIPT"
    log "Fin du script de vérification et de sauvegarde."
    exit 0
fi

# Lire l'ancienne checksum
log "Lecture de l'ancienne checksum à partir du fichier : $CHECKSUM_FILE"
OLD_CHECKSUM=$(cat "$CHECKSUM_FILE")
log "Ancienne checksum lue : $OLD_CHECKSUM"

# Comparer les checksums
log "Comparaison des checksums."
if [ "$NEW_CHECKSUM" != "$OLD_CHECKSUM" ]; then
    log "Changement détecté. Mise à jour de la checksum et exécution du script de sauvegarde."
    # Stocker la nouvelle checksum
    echo "$NEW_CHECKSUM" > "$CHECKSUM_FILE"
    log "Nouvelle checksum sauvegardée dans : $CHECKSUM_FILE"
    # Exécuter le script de sauvegarde
    log "Lancement du script de sauvegarde : $BACKUP_SCRIPT"
    bash "$BACKUP_SCRIPT"
else
    log "Aucun changement détecté. La sauvegarde n'est pas nécessaire."
fi

log "Fin du script de vérification et de sauvegarde."

