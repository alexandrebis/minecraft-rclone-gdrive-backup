#!/bin/bash
set -e

# Charger les variables d'environnement du fichier .env
source utils/load-env.sh
source utils/logs.sh

# Fonction pour écrire des messages dans le fichier de log avec la date
log() {
    _log "$1" "deploy-backup"
}

# Vérifier la présence des variables nécessaires
[ -z "${TMP_DIR}" ] && log "Erreur : Variable TMP_DIR non définie dans le fichier .env" && exit 1
[ -z "${SERVERS_DIR}" ] && log "Erreur : Variable SERVERS_DIR non définie dans le fichier .env" && exit 1

BACKUP_FILE=$1
OVERWRITE=false
if [[ "$2" == "--overwrite" ]]; then
    OVERWRITE=true
fi

# Vérification de la présence du fichier de backup
if [ ! -f "${BACKUP_FILE}" ]; then
    log "Erreur : Fichier de backup non trouvé (${BACKUP_FILE})"
    exit 1
fi

# Décompression de l'archive de backup
log "Décompression de l'archive de backup : ${BACKUP_FILE}"
tar -xzf "${BACKUP_FILE}" -C "${TMP_DIR}"

# Extraction de l'identifiant du server
IDENTIFIER=$(basename "${BACKUP_FILE}" .tar.gz | sed 's/^backup-//')

# Vérification de la présence des fichiers nécessaires dans l'archive
REQUIRED_FILES=("backup.info" "${IDENTIFIER}/" "${IDENTIFIER}.json" "${IDENTIFIER}.md5")
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -e "${TMP_DIR}/${file}" ]; then
        log "Erreur : Fichier requis ${file} non trouvé dans l'archive"
        exit 1
    fi
done

# Génération du fichier .md5 si manquant
if [ ! -f "${TMP_DIR}/${IDENTIFIER}.md5" ]; then
    log "Fichier .md5 manquant, génération en cours"
    find "${TMP_DIR}/${IDENTIFIER}" -type f -exec md5sum {} \; | sort -k 2 | md5sum | awk '{print $1}' > "${TMP_DIR}/${IDENTIFIER}.md5"
fi

# Vérification de la présence d'un dossier avec cet identifier dans SERVERS_DIR
if [ -d "${SERVERS_DIR}/${IDENTIFIER}" ]; then
    log "Dossier ${IDENTIFIER} déjà présent dans ${SERVERS_DIR}"

    # Comparaison des checksums
    EXISTING_MD5=$(cat "${SERVERS_DIR}/${IDENTIFIER}.md5")
    NEW_MD5=$(cat "${TMP_DIR}/${IDENTIFIER}.md5")

    if [ "$EXISTING_MD5" == "$NEW_MD5" ]; then
        if [ "$OVERWRITE" = true ]; then
            cp "${TMP_DIR}/${IDENTIFIER}.json" "${SERVERS_DIR}/${IDENTIFIER}.json"
            log "Checksum identique. Mise à jour non-interactive des fichiers de configuration."
        else
            read -p "Checksum identique. Voulez-vous mettre à jour l'entrée en base et le fichier JSON? (y/N): " response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                cp "${TMP_DIR}/${IDENTIFIER}.json" "${SERVERS_DIR}/${IDENTIFIER}.json"
                log "Mise à jour de l'entrée en base et du fichier JSON effectuée."
            else
                log "Aucune mise à jour effectuée."
            fi
        fi
    else
        if [ "$OVERWRITE" = true ]; then
            rm -rf "${SERVERS_DIR:?}/${IDENTIFIER}"
            cp -r "${TMP_DIR}/${IDENTIFIER}" "${SERVERS_DIR}/${IDENTIFIER}"
            cp "${TMP_DIR}/${IDENTIFIER}.json" "${SERVERS_DIR}/${IDENTIFIER}.json"
            log "Checksum différente. Remplacement non-interactive du dossier et des fichiers de configuration."
        else
            read -p "Checksum différente. Voulez-vous remplacer le dossier existant? (y/N): " response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                rm -rf "${SERVERS_DIR:?}/${IDENTIFIER}"
                cp -r "${TMP_DIR}/${IDENTIFIER}" "${SERVERS_DIR}/${IDENTIFIER}"
                cp "${TMP_DIR}/${IDENTIFIER}.json" "${SERVERS_DIR}/${IDENTIFIER}.json"
                log "Dossier et fichiers de configuration remplacés."
            else
                log "Aucun remplacement effectué."
            fi
        fi
    fi
else
    log "Aucune entrée trouvée dans SERVERS_DIR. Création de la nouvelle entrée."
    cp -r "${TMP_DIR}/${IDENTIFIER}" "${SERVERS_DIR}/${IDENTIFIER}"
    cp "${TMP_DIR}/${IDENTIFIER}.json" "${SERVERS_DIR}/${IDENTIFIER}.json"
    cp "${TMP_DIR}/${IDENTIFIER}.md5" "${SERVERS_DIR}/${IDENTIFIER}.md5"
    log "Nouvelle entrée créée dans SERVERS_DIR."
fi

log "Déploiement de la backup terminé."
