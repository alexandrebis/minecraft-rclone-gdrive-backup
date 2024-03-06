#!/bin/bash

MINECRAFT_SERVER_SAVES_FOLDER_LOCAL="${MINECRAFT_SERVER_SAVES_FOLDER:-/home/opc/minecraft-cornichons/saves}"
GDRIVE_REMOTE="${GDRIVE_REMOTE:-gcloud}"
MINECRAFT_SERVER_SAVES_FOLDER_GDRIVE="${MINECRAFT_SERVER_SAVES_FOLDER_GDRIVE:-/Cornichons-Minecraft/backups}"
NUM_BACKUPS_TO_KEEP="${NUM_BACKUPS_TO_KEEP:-3}"

# Obtient la date actuelle au format AAAA-MM-JJ_HH-MM-SS
CURRENT_DATE=$(date +"%Y-%m-%d_%H-%M-%S")

# Vérifie si la sauvegarde actuelle existe
if [ ! -f "${MINECRAFT_SERVER_SAVES_FOLDER_LOCAL}/lastsave.dat" ]; then
    echo "Erreur : La sauvegarde actuelle (${MINECRAFT_SERVER_SAVES_FOLDER_LOCAL}/lastsave.dat) n'existe pas."
    exit 1
fi

# Copie la sauvegarde actuelle avec la date dans le nom de fichier
if rclone copyto --progress "${MINECRAFT_SERVER_SAVES_FOLDER_LOCAL}/lastsave.dat" "${GDRIVE_REMOTE}:${MINECRAFT_SERVER_SAVES_FOLDER_GDRIVE}/backup-${CURRENT_DATE}.zip"; then
    echo "Copie de la sauvegarde actuelle avec succès vers backup-${CURRENT_DATE}.zip"
else
    echo "Erreur : La copie de la sauvegarde actuelle a échoué."
    exit 1
fi

# Supprime les sauvegardes les plus anciennes si elles existent
rclone lsf --format "tsp" "${GDRIVE_REMOTE}:${MINECRAFT_SERVER_SAVES_FOLDER_GDRIVE}" | grep -v '/$' | sort -n | head -n -$((NUM_BACKUPS_TO_KEEP)) | while read -r LINE; do
    OLDEST_BACKUP=$(echo "$LINE" | awk -F ';' '{print $3}')
    if [ -n "$OLDEST_BACKUP" ]; then
        rclone deletefile "${GDRIVE_REMOTE}:${MINECRAFT_SERVER_SAVES_FOLDER_GDRIVE}/${OLDEST_BACKUP}"
        echo "Suppression de la sauvegarde la plus ancienne : $OLDEST_BACKUP"
    fi
done

# Déplace les sauvegardes existantes vers la sauvegarde suivante
rclone lsf --format "tsp" "${GDRIVE_REMOTE}:${MINECRAFT_SERVER_SAVES_FOLDER_GDRIVE}" | grep -v '/$' | sort -n -r | head -n -$((NUM_BACKUPS_TO_KEEP)) | while read -r LINE; do
    FILE=$(echo "$LINE" | awk -F ';' '{print $3}')
    if [[ "$FILE" =~ ^backup-([0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}).zip$ ]]; then
        PREVIOUS_DATE="${BASH_REMATCH[1]}"
        rclone move --progress "${GDRIVE_REMOTE}:${MINECRAFT_SERVER_SAVES_FOLDER_GDRIVE}/$FILE" "${GDRIVE_REMOTE}:${MINECRAFT_SERVER_SAVES_FOLDER_GDRIVE}/backup-$PREVIOUS_DATE.zip"
        echo "Déplacement de la sauvegarde $FILE vers backup-$PREVIOUS_DATE.zip"
    fi
done

