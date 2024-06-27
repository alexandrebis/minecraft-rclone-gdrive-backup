#!/bin/bash
set -e

source utils/load-env.sh
source utils/logs.sh

# Fonction pour écrire des messages dans le fichier de log avec la date
log() {
    _log "$1" "deploy-backup"
}

log "Début du déploiement de la sauvegarde"

# Chemins
BACKUP_ARCHIVE=$1
TARGET_DIR="${TARGET_DIR:-/home/opc/minecraft-pufferpanel/servers}"

# Vérifier si l'archive de sauvegarde est spécifiée
if [ -z "$BACKUP_ARCHIVE" ]; then
    log "Erreur : Aucune archive de sauvegarde spécifiée"
    exit 1
fi

# Vérifier si l'archive de sauvegarde existe
if [ ! -f "$BACKUP_ARCHIVE" ]; then
    log "Erreur : Archive de sauvegarde non trouvée : $BACKUP_ARCHIVE"
    exit 1
fi

# Déployer la sauvegarde
tar -xzf "$BACKUP_ARCHIVE" -C "$TARGET_DIR"
log "Archive dézippée : $BACKUP_ARCHIVE"

# Lire le fichier backup.info pour déterminer la plateforme
platform=$(jq -r '.platform' "$TARGET_DIR/backup.info")

# Fonction pour déployer une sauvegarde spécifique à PufferPanel
deploy_pufferpanel_backup() {
    identifier=$(jq -r '.pufferpanel.identifier' "$TARGET_DIR/backup.info")

    # Vérifier la présence de l'entrée dans la base de données
    exists=$(sqlite3 /home/opc/minecraft-pufferpanel/pufferpanel.db "SELECT 1 FROM servers WHERE identifier='$identifier';")

    if [ -z "$exists" ]; then
        name=$(jq -r '.name' "$TARGET_DIR/backup.info")
        ip=$(jq -r '.ip' "$TARGET_DIR/backup.info")
        port=$(jq -r '.port' "$TARGET_DIR/backup.info")
        type=$(jq -r '.type' "$TARGET_DIR/backup.info")

        sqlite3 /home/opc/minecraft-pufferpanel/pufferpanel.db <<EOF
INSERT INTO servers (name, identifier, ip, port, type, created_at, updated_at) 
VALUES ('$name', '$identifier', '$ip', $port, '$type', datetime('now'), datetime('now'));
EOF
        log "Ajouté serveur: $name ($identifier)"
    fi

    # Déplacer le dossier dézippé et le fichier JSON associé
    mv "$TARGET_DIR/$identifier" "/home/opc/minecraft-pufferpanel/servers/"
    mv "$TARGET_DIR/$identifier.json" "/home/opc/minecraft-pufferpanel/servers/"

    log "Sauvegarde PufferPanel déployée : $identifier"
}

# Déployer en fonction de la plateforme
case $platform in
    "pufferpanel")
        deploy_pufferpanel_backup
        ;;
    *)
        log "Erreur : Plateforme inconnue : $platform"
        exit 1
        ;;
esac

log "Déploiement de la sauvegarde terminé depuis $BACKUP_ARCHIVE"

