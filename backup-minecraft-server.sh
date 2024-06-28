#!/bin/bash
set -e

source utils/load-env.sh
source utils/logs.sh


# Fonction pour écrire des messages dans le fichier de log avec la date
log() {
    _log "$1" "backup"
}

[ -z "${SERVERS_DIR}" ] && var_notfound "SERVERS_DIR"
[ -z "${PUFFERPANEL_SERVER_ID}" ] && var_notfound "PUFFERPANEL_SERVER_ID"
[ -z "${BACKUP_LOCAL_FOLDER}" ] && var_notfound "BACKUP_LOCAL_FOLDER"
[ -z "${GDRIVE_REMOTE}" ] && var_notfound "GDRIVE_REMOTE"
[ -z "${BACKUP_REMOTE_FOLDER}" ] && var_notfound "BACKUP_REMOTE_FOLDER"

NUM_BACKUPS_TO_KEEP="3"
_CURRENT_DATE=$(date +"%Y-%m-%d_%H-%M-%S")
_BACKUP_NAME=backup-${_CURRENT_DATE}.tar.gz
_BACKUP_LOCAL_PATH=${BACKUP_LOCAL_FOLDER}/${_BACKUP_NAME}
_WORLD_DIR=${SERVERS_DIR}/${PUFFERPANEL_SERVER_ID}


# Vérifie si le dossier de sauvegarde existe
if [ ! -d "${_WORLD_DIR}" ]; then
    log "Erreur : Dossier de sauvegarde du serveur non trouvé (${_WORLD_DIR})"
    exit 1
fi

# Création d'une backup
mkdir -p ${BACKUP_LOCAL_FOLDER}
if [ -f "${_BACKUP_LOCAL_PATH}" ]; then
    log "Warning : Backup déjà existante. Utilisation de celle-ci (${_BACKUP_LOCAL_PATH})"
else
    log "Création d'une backup du monde Minecraft à partir de ${_WORLD_DIR}"
    tar -czf ${_BACKUP_LOCAL_PATH} -C ${_WORLD_DIR} .
    # pv version : tar cf - ${_WORLD_DIR}/* -P | pv -s $(du -sb ${_WORLD_DIR}/* | awk '{print $1}') | gzip > ${_BACKUP_LOCAL_PATH}
fi

# Copie la backup sur Google Drive
if [ ! -f "${_BACKUP_LOCAL_PATH}" ]; then
    log "Erreur : Backup non trouvée ${_BACKUP_LOCAL_PATH}. Fin du script"
    exit 1
fi
log "Upload de la backuo vers le cloud..."
if rclone copyto --progress "${_BACKUP_LOCAL_PATH}" "${GDRIVE_REMOTE}:${BACKUP_REMOTE_FOLDER}/${_BACKUP_NAME}"; then
    log "Upload de la backup vers le cloud réussie : ${GDRIVE_REMOTE}:${BACKUP_REMOTE_FOLDER}/${_BACKUP_NAME}"
    rm ${_BACKUP_LOCAL_PATH}
else
    log "Erreur : La copie de la backup vers le cloud a échoué."
    exit 1
fi

# Supprime les sauvegardes les plus anciennes si elles existent
rclone lsf --format "tsp" "${GDRIVE_REMOTE}:${BACKUP_REMOTE_FOLDER}" | grep -v '/$' | sort -n | head -n -$((NUM_BACKUPS_TO_KEEP)) | while read -r LINE; do
    _OLDEST_BACKUP=$(echo "$LINE" | awk -F ';' '{print $3}')
    if [ -n "$_OLDEST_BACKUP" ]; then
        rclone deletefile "${GDRIVE_REMOTE}:${BACKUP_REMOTE_FOLDER}/${_OLDEST_BACKUP}"
        log "Suppression de la sauvegarde la plus ancienne : $_OLDEST_BACKUP"
    fi
done

# Déplace les sauvegardes existantes vers la sauvegarde suivante
rclone lsf --format "tsp" "${GDRIVE_REMOTE}:${BACKUP_REMOTE_FOLDER}" | grep -v '/$' | sort -n -r | head -n -$((NUM_BACKUPS_TO_KEEP)) | while read -r LINE; do
    _FILE=$(echo "$LINE" | awk -F ';' '{print $3}')
    if [[ "$_FILE" =~ ^backup-([0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}).tar.gz$ ]]; then
        _PREVIOUS_DATE="${BASH_REMATCH[1]}"
        rclone move --progress "${GDRIVE_REMOTE}:${BACKUP_REMOTE_FOLDER}/$_FILE" "${GDRIVE_REMOTE}:${BACKUP_REMOTE_FOLDER}/backup-$_PREVIOUS_DATE.tar.gz"
        log "Déplacement de la sauvegarde $_FILE vers backup-$_PREVIOUS_DATE.tar.gz"
    fi
done
result=$(rclone ls ${GDRIVE_REMOTE}:)
log "Résultat final du dossier de backup distant : $result"

