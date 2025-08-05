#!/bin/bash
##############################
#      CONSTANTES            #
##############################

DOCKER_WG_DIR="$HOME/docker-wireguard"
DOCKER_COMPOSE_FILE="$DOCKER_WG_DIR/docker-compose.yml"
WG_CONF_DIR="$DOCKER_WG_DIR/config"

# Fonction pour vérifier et créer le dossier avec les bonnes permissions
ensure_docker_dir() {
    if [[ ! -d "$DOCKER_WG_DIR" ]]; then
        echo "📁 Création du répertoire docker-wireguard..."
        if ! mkdir -p "$DOCKER_WG_DIR" 2>/dev/null; then
            log_error "Impossible de créer le répertoire $DOCKER_WG_DIR" 2>/dev/null || echo "ERREUR: Impossible de créer $DOCKER_WG_DIR"
            echo "❌ Permissions insuffisantes pour créer le répertoire"
            echo "💡 Veuillez créer manuellement le répertoire et ajuster les permissions :"
            echo "   mkdir -p \"$DOCKER_WG_DIR\""
            echo "   chown -R $USER:$USER \"$DOCKER_WG_DIR\""
            echo "   chmod -R 755 \"$DOCKER_WG_DIR\""
            return 1
        fi
    fi
    
    # Vérifier les permissions d'écriture
    if [[ ! -w "$DOCKER_WG_DIR" ]]; then
        log_error "Pas de droits d'écriture sur $DOCKER_WG_DIR" 2>/dev/null || echo "ERREUR: Pas de droits d'écriture sur $DOCKER_WG_DIR"
        echo "❌ Permissions insuffisantes"
        echo "💡 Veuillez ajuster les permissions manuellement :"
        echo "   chown -R $USER:$USER \"$DOCKER_WG_DIR\""
        echo "   chmod -R 755 \"$DOCKER_WG_DIR\""
        return 1
    fi
    
    # Créer le sous-dossier config
    if [[ ! -d "$WG_CONF_DIR" ]]; then
        if ! mkdir -p "$WG_CONF_DIR" 2>/dev/null; then
            log_error "Impossible de créer $WG_CONF_DIR" 2>/dev/null || echo "ERREUR: Impossible de créer $WG_CONF_DIR"
            return 1
        fi
    fi
    
    return 0
}

# Vérifier et créer le dossier
if ! ensure_docker_dir; then
    echo "❌ Impossible de configurer le répertoire docker-wireguard"
    echo "Vérifiez vos permissions ou contactez l'administrateur système"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF_FILE="$SCRIPT_DIR/config/wg-easy.conf"

# S'assurer que conf.sh est chargé
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/conf.sh"

##############################
#        VERSION MODULE      #
##############################

DOCKER_VERSION="1.1.0"

##############################
#   CONFIGURATION PRINCIPALE #
##############################
cancel_config() {
    trap - SIGINT
    echo -e "\n\e[1;31mConfiguration annulée par l'utilisateur.\e[0m"
    if [[ "$DOCKER_COMPOSE_CREATED" == "1" && -f "$DOCKER_COMPOSE_FILE" ]]; then
        read -p $'Voulez-vous supprimer le fichier docker-compose.yml créé ? (o/N) : ' CONFIRM_DEL
        if [[ "$CONFIRM_DEL" =~ ^[oO]$ ]]; then
            rm -rf "$DOCKER_COMPOSE_FILE" ${DOCKER_WG_DIR}/config
            echo -e "\e[1;31mLe fichier docker-compose.yml créé a été supprimé.\e[0m"
        else
            echo -e "\e[1;33mLe fichier docker-compose.yml a été conservé.\e[0m"
        fi
    fi
    ...
    exit 1
}

configure_values() {
    # Fonction d'annulation (Ctrl+C) pendant la création
    trap cancel_config SIGINT

    # Vérifier les permissions avant de commencer
    if ! ensure_docker_dir; then
        msg_error "Impossible d'accéder au répertoire docker-wireguard"
        return 1
    fi

    # Sauvegarde de l'état initial
    if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
        if ! cp "$DOCKER_COMPOSE_FILE" "$DOCKER_COMPOSE_FILE.bak" 2>/dev/null; then
            msg_error "Impossible de créer une sauvegarde - permissions insuffisantes"
            return 1
        fi
    fi

    # Création du fichier si absent
    if [[ ! -f "$DOCKER_COMPOSE_FILE" ]]; then
        trap cancel_config SIGINT
        DOCKER_COMPOSE_CREATED=1
        echo "Création de la configuration de Wireguard..."
        
        # Vérifier qu'on peut écrire dans le répertoire
        if [[ ! -w "$DOCKER_WG_DIR" ]]; then
            msg_error "Pas de droits d'écriture dans $DOCKER_WG_DIR"
            return 1
        fi
        
        mkdir -p ${DOCKER_WG_DIR}/config
        cat <<EOF > "$DOCKER_COMPOSE_FILE"
services:
  wg-easy:
    environment:
    - PORT=51821
    - INSECURE=false
    image: ghcr.io/wg-easy/wg-easy:${WG_EASY_VERSION}
    container_name: wg-easy
    networks:
      wg:
        ipv4_address: 10.42.42.42
        ipv6_address: fdcc:ad94:bacf:61a3::2a
    volumes:
      - ${DOCKER_WG_DIR}/config:/etc/wireguard
      - /lib/modules:/lib/modules:ro
    ports:
      - "51820:51820/udp"
      - "51821:51821/tcp"
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    sysctls:
      - net.ipv4.ip_forward=1
      - net.ipv4.conf.all.src_valid_mark=1
      - net.ipv6.conf.all.disable_ipv6=0
      - net.ipv6.conf.all.forwarding=1
      - net.ipv6.conf.default.forwarding=1

networks:
  wg:
    driver: bridge
    enable_ipv6: true
    ipam:
      driver: default
      config:
        - subnet: 10.42.42.0/24
        - subnet: fdcc:ad94:bacf:61a3::/64
EOF
        echo "Fichier docker-compose.yml créé avec succès."
        trap - SIGINT
    else
        DOCKER_COMPOSE_CREATED=0
    fi

    # Modification du port
    CURRENT_PORT=$(grep 'PORT=' "$DOCKER_COMPOSE_FILE" | cut -d '=' -f 2)
    msg_info "Port actuel pour PORT : $CURRENT_PORT"
    read -p $'Voulez-vous modifier le port PORT ? (o/N, ctrl+c pour annuler) : ' MODIFY_PORT
    if [[ "${MODIFY_PORT,,}" == "o" ]]; then
        while true; do
            read -p $'Entrez le nouveau port PORT (1-65535, par défaut : '"$CURRENT_PORT"', ctrl+c pour annuler) : ' NEW_PORT
            NEW_PORT=${NEW_PORT:-$CURRENT_PORT}
            if validate_port "$NEW_PORT"; then
                break
            else
                msg_error "Veuillez entrer un nombre entre 1 et 65535."
            fi
        done
        sed -i "s#PORT=.*#PORT=$NEW_PORT#" "$DOCKER_COMPOSE_FILE"
        msg_success "Le port PORT a été modifié avec succès."
    else
        msg_warn "Aucune modification apportée au port PORT."
    fi

    # Sécurité interface web
    read -p $'L\'interface web sera-t-elle exposée côté internet ? (o/N, ctrl+c pour annuler) : ' EXPOSE_WEB
    if [[ "${EXPOSE_WEB,,}" == "o" ]]; then
        sed -i "s#INSECURE=.*#INSECURE=false#" "$DOCKER_COMPOSE_FILE"
        msg_success "L'interface web a été configurée pour ne pas être exposée de manière non sécurisée."
    else
        sed -i "s#INSECURE=.*#INSECURE=true#" "$DOCKER_COMPOSE_FILE"
        msg_warn "L'interface web reste configurée comme non sécurisée."
    fi
}

update_wireguard_container() {
    if [[ "$WG_EASY_UPDATE_AVAILABLE" == "1" ]]; then
        echo -e "\e[35mUne nouvelle version du container Wireguard Easy est disponible : $WG_EASY_VERSION_DISTANT (actuelle : $WG_EASY_VERSION_LOCAL)\e[0m"
        # Sauvegarde avant toute modification
        BACKUP_DIR="$HOME/wg-easy-backup-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$BACKUP_DIR"
        cp -r "$DOCKER_WG_DIR" "$BACKUP_DIR/" 2>/dev/null
        echo -e "\e[32mBackup complet du dossier docker-wireguard et config réalisé dans $BACKUP_DIR\e[0m"
        # Mise à jour du container
        sed -i "s|image: ghcr.io/wg-easy/wg-easy:.*|image: ghcr.io/wg-easy/wg-easy:$WG_EASY_VERSION_DISTANT|" "$DOCKER_COMPOSE_FILE"
        echo -e "\e[32mLe docker-compose.yml a été mis à jour avec la version $WG_EASY_VERSION_DISTANT.\e[0m"
        echo -e "\e[34mTéléchargement de la nouvelle image Docker...\e[0m"
        docker pull ghcr.io/wg-easy/wg-easy:$WG_EASY_VERSION_DISTANT
        echo -e "\e[34mRedémarrage du service Wireguard...\e[0m"
        docker compose -f "$DOCKER_COMPOSE_FILE" down
        docker compose -f "$DOCKER_COMPOSE_FILE" pull
        docker compose -f "$DOCKER_COMPOSE_FILE" up -d
        echo -e "\e[32mService Wireguard relancé avec la nouvelle version !\e[0m"
        # Mise à jour du fichier WG_EASY_VERSION local
        WG_EASY_VERSION_FILE="$SCRIPT_DIR/../WG_EASY_VERSION"
        echo "$WG_EASY_VERSION_DISTANT" > "$WG_EASY_VERSION_FILE"
        echo -e "\e[32mLe fichier WG_EASY_VERSION local a été mis à jour avec la version $WG_EASY_VERSION_DISTANT.\e[0m"
    else
        echo -e "\e[33mAucune mise à jour disponible ou variable non définie.\e[0m"
    fi
}
##############################
#   RÉINITIALISATION CONFIG  #
##############################

# Fonction pour nettoyer les volumes Docker conflictuels
clean_docker_volumes() {
    echo "🧹 Nettoyage des volumes Docker conflictuels..."
    
    # Arrêter le conteneur s'il est en cours d'exécution
    if docker ps -q --filter "name=wg-easy" | grep -q .; then
        echo "📦 Arrêt du conteneur wg-easy..."
        docker stop wg-easy 2>/dev/null || true
    fi
    
    # Supprimer le conteneur s'il existe
    if docker ps -a -q --filter "name=wg-easy" | grep -q .; then
        echo "🗑️  Suppression du conteneur wg-easy..."
        docker rm wg-easy 2>/dev/null || true
    fi
    
    # Nettoyer les volumes orphelins liés à docker-wireguard
    echo "🧽 Nettoyage des volumes Docker..."
    docker volume ls -q | grep -E "(docker-wireguard|wireguard)" | xargs -r docker volume rm 2>/dev/null || true
    
    # Nettoyer les réseaux orphelins
    echo "🌐 Nettoyage des réseaux Docker..."
    docker network ls -q --filter "name=docker-wireguard" | xargs -r docker network rm 2>/dev/null || true
    
    echo "✅ Nettoyage terminé"
}

# Fonction pour résoudre les conflits de volumes Docker
fix_docker_volume_conflicts() {
    echo "🔧 Résolution des conflits de volumes Docker..."
    
    msg_warn "⚠️  Cette action va arrêter temporairement le service Wireguard"
    read -p $'Voulez-vous continuer ? (o/N) : ' CONFIRM_FIX
    if [[ ! "$CONFIRM_FIX" =~ ^[oO]$ ]]; then
        msg_warn "Résolution annulée."
        return
    fi
    
    # Sauvegarder la configuration actuelle
    if [[ -d "$WG_CONF_DIR" ]]; then
        BACKUP_DIR="$HOME/wg-config-backup-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$BACKUP_DIR"
        cp -r "$WG_CONF_DIR" "$BACKUP_DIR/" 2>/dev/null
        msg_success "Sauvegarde de la configuration dans $BACKUP_DIR"
    fi
    
    # Nettoyer les volumes conflictuels
    clean_docker_volumes
    
    # Redémarrer le service avec la nouvelle configuration
    if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
        echo "🚀 Redémarrage du service Wireguard..."
        docker compose -f "$DOCKER_COMPOSE_FILE" up -d
        msg_success "Service Wireguard redémarré avec succès"
    else
        msg_error "Fichier docker-compose.yml introuvable"
    fi
}

RAZ_docker_compose() {
    if ! ask_tech_password; then
        msg_error "Réinitialisation annulée."
        return
    fi
    
    # Vérifier les permissions avant de procéder
    if [[ -f "$DOCKER_COMPOSE_FILE" && ! -w "$DOCKER_COMPOSE_FILE" ]]; then
        msg_error "Pas de droits d'écriture sur $DOCKER_COMPOSE_FILE"
        msg_error "Permissions insuffisantes - impossible de continuer"
        return 1
    fi
    
    msg_warn "⚠️  Cette action supprimera toutes les configurations existantes."
    read -p $'Confirmez-vous vouloir réinitialiser la configuration ? (o/N) : ' CONFIRM_RAZ
    if [[ ! "$CONFIRM_RAZ" =~ ^[oO]$ ]]; then
        msg_warn "Réinitialisation annulée."
        return
    fi
    
    # Nettoyer les volumes Docker conflictuels
    clean_docker_volumes
    
    if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
        if rm -f "$DOCKER_COMPOSE_FILE" 2>/dev/null; then
            msg_success "Le fichier docker-compose.yml a été supprimé."
        else
            msg_error "Impossible de supprimer $DOCKER_COMPOSE_FILE"
            msg_error "Permissions insuffisantes - veuillez supprimer manuellement"
            return 1
        fi
    else
        msg_error "Aucun fichier docker-compose.yml trouvé."
    fi
    
    if [[ -d "${DOCKER_WG_DIR}" ]]; then
        if rm -rf "${DOCKER_WG_DIR}" 2>/dev/null; then
            msg_success "Le dossier ${DOCKER_WG_DIR} a été supprimé."
        else
            msg_error "Impossible de supprimer ${DOCKER_WG_DIR}"
            msg_error "Permissions insuffisantes - veuillez supprimer manuellement"
            return 1
        fi
    else
        msg_error "Aucun dossier ${DOCKER_WG_DIR} trouvé."
    fi
}