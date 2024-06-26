#!/bin/bash
set -e

# Verify presence of .env.dist and .env. Copy if does not exist
if [ ! -f ".env" ]; then
  if [ ! -f ".env.dist" ]; then
    log "Error : No .env.dist file found" && exit 1
  fi
  cp .env.dist .env
fi

set -a
source .env
set +a

# Fonction pour écrire des messages dans le fichier de log avec la date
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [backup] - $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [backup] - $1" >> "$LOG_FILE"
}

var_notfound() {
    log "Error : $1 is not set. Please use .env from .env.dist" && exit 1
}


[ -z "${WORLD_DIR}" ] && var_notfound "WORLD_DIR"
[ -z "${BACKUP_LOCAL_FOLDER}" ] && var_notfound "BACKUP_LOCAL_FOLDER"
[ -z "${GDRIVE_REMOTE}" ] && var_notfound "GDRIVE_REMOTE"
[ -z "${BACKUP_REMOTE_FOLDER}" ] && var_notfound "BACKUP_REMOTE_FOLDER"

NUM_BACKUPS_TO_KEEP="3"
_CURRENT_DATE=$(date +"%Y-%m-%d_%H-%M-%S")
_BACKUP_NAME=backup-${_CURRENT_DATE}.tar.gz
_BACKUP_LOCAL_PATH=${BACKUP_LOCAL_FOLDER}/${_BACKUP_NAME}

# Fonction pour écrire des messages dans le fichier de log avec la date
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [backup] - $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [backup] - $1" >> "$LOG_FILE"
}

var_notfound() {
    log "Error : $1 is not set. Please use .env from .env.dist" && exit 1
}


# Vérifie si le dossier de sauvegarde existe
if [ ! -d "${WORLD_DIR}" ]; then
    log "Erreur : Dossier de sauvegarde du serveur non trouvé (${WORLD_DIR})"
    exit 1
fi

# Création d'une backup
mkdir -p ${BACKUP_LOCAL_FOLDER}
if [ -f "${_BACKUP_LOCAL_PATH}" ]; then
    log "Warning : Backup déjà existante. Utilisation de celle-ci (${_BACKUP_LOCAL_PATH})"
else
    log "Création d'une backup ${_BACKUP_LOCAL_PATH} du serveur à partir de ${WORLD_DIR}"
    tar -czf ${_BACKUP_LOCAL_PATH} -C ${WORLD_DIR} .
    # pv version : tar cf - ${WORLD_DIR}/* -P | pv -s $(du -sb ${WORLD_DIR}/* | awk '{print $1}') | gzip > ${_BACKUP_LOCAL_PATH}
    log "Backup créée : ${_BACKUP_LOCAL_PATH}"
fi

# Copie la backup sur Google Drive
if [ ! -f "${_BACKUP_LOCAL_PATH}" ]; then
    log "Erreur : Backup non trouvée ${_BACKUP_LOCAL_PATH}. Fin du script"
    exit 1
fi

if rclone copyto --progress "${_BACKUP_LOCAL_PATH}" "${GDRIVE_REMOTE}:${BACKUP_REMOTE_FOLDER}/${_BACKUP_NAME}"; then
    log "Copie de la backup avec succès vers le cloud : ${GDRIVE_REMOTE}:${BACKUP_REMOTE_FOLDER}/${_BACKUP_NAME}"
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

log "Résultat final du dossier de backup distant :"
rclone ls ${GDRIVE_REMOTE}:

