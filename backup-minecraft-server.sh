#!/bin/bash
set -e

MINECRAFT_SERVER_SAVES_FOLDER_LOCAL="/home/opc/minecraft-pufferpanel/servers/dffe1cd5"
BACKUP_FOLDER="/home/opc/minecraft-backups"
GDRIVE_REMOTE="gdrive"
MINECRAFT_SERVER_SAVES_FOLDER_GDRIVE="/Cornichons-Minecraft/backups"
NUM_BACKUPS_TO_KEEP="3"
CURRENT_DATE=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_NAME=backup-${CURRENT_DATE}.tar.gz
BACKUP_PATH=${BACKUP_FOLDER}/${BACKUP_NAME}


# Vérifie si le dossier de sauvegarde existe
if [ ! -d "${MINECRAFT_SERVER_SAVES_FOLDER_LOCAL}" ]; then
    echo "Erreur : Dossier de sauvegarde du serveur non trouvé (${MINECRAFT_SERVER_SAVES_FOLDER_LOCAL})"
    exit 1
fi

# Création d'une backup
mkdir -p ${BACKUP_FOLDER}
if [ -f "${BACKUP_PATH}" ]; then
    echo "Warning : Backup déjà existante. Utilisation de celle-ci (${BACKUP_PATH})"
else
    echo "Création d'une backup du serveur à partir de ${MINECRAFT_SERVER_SAVES_FOLDER_LOCAL}"
    tar -czvf ${BACKUP_PATH} ${MINECRAFT_SERVER_SAVES_FOLDER_LOCAL}/*
    # pv version : tar cf - ${MINECRAFT_SERVER_SAVES_FOLDER_LOCAL}/* -P | pv -s $(du -sb ${MINECRAFT_SERVER_SAVES_FOLDER_LOCAL}/* | awk '{print $1}') | gzip > ${BACKUP_PATH}
    echo "Backup créée : ${BACKUP_PATH}"
fi

# Copie la backup sur Google Drive
if [ ! -f "${BACKUP_PATH}" ]; then
    echo "Erreur : Backup non trouvée ${BACKUP_PATH}. Fin du script"
    exit 1
fi

if rclone copyto --progress "${BACKUP_PATH}" "${GDRIVE_REMOTE}:${MINECRAFT_SERVER_SAVES_FOLDER_GDRIVE}/${BACKUP_NAME}"; then
    echo "Copie de la backup avec succès vers le cloud : ${GDRIVE_REMOTE}:${MINECRAFT_SERVER_SAVES_FOLDER_GDRIVE}/${BACKUP_NAME}"
else
    echo "Erreur : La copie de la backup vers le cloud a échoué."
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
    if [[ "$FILE" =~ ^backup-([0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}).tar.gz$ ]]; then
        PREVIOUS_DATE="${BASH_REMATCH[1]}"
        rclone move --progress "${GDRIVE_REMOTE}:${MINECRAFT_SERVER_SAVES_FOLDER_GDRIVE}/$FILE" "${GDRIVE_REMOTE}:${MINECRAFT_SERVER_SAVES_FOLDER_GDRIVE}/backup-$PREVIOUS_DATE.tar.gz"
        echo "Déplacement de la sauvegarde $FILE vers backup-$PREVIOUS_DATE.tar.gz"
    fi
done

echo "Résultat final du dossier de backup distant :"
rclone ls ${GDRIVE_REMOTE}:

