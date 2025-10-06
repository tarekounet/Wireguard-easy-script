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
    image: ghcr.io/wg-easy/wg-easy:${WG_EASY_VERSION}
    container_name: wg-easy
    networks:
      wg:
        ipv4_address: 10.42.42.42
        ipv6_address: fdcc:ad94:bacf:61a3::2a
    volumes:
      - etc_wireguard:/etc/wireguard
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
volumes:
  etc_wireguard:
    driver: local
    driver_opts:
      type: none
      device: ${WG_CONF_DIR}
      o: bind

EOF
        echo "Fichier docker-compose.yml créé avec succès."
        trap - SIGINT
    else
        DOCKER_COMPOSE_CREATED=0
    fi

    # Configuration automatique avec valeurs par défaut sécurisées
    CURRENT_PORT=$(grep 'PORT=' "$DOCKER_COMPOSE_FILE" | cut -d '=' -f 2)
    msg_info "Port configuré pour l'interface web : $CURRENT_PORT"
    
    # Configuration sécurisée automatique (INSECURE=false)
    sed -i "s#INSECURE=.*#INSECURE=false#" "$DOCKER_COMPOSE_FILE"
    msg_success "Interface web configurée en mode sécurisé (INSECURE=false)."
    msg_info "Configuration terminée avec les paramètres par défaut sécurisés."
    
    # Demander s'il faut lancer le service (défaut: Non)
    echo ""
    read -p $'Voulez-vous démarrer le service Wireguard maintenant ? (o/N) : ' START_SERVICE
    if [[ "${START_SERVICE,,}" == "o" ]]; then
        echo -e "\e[34m🚀 Démarrage du service Wireguard...\e[0m"
        if command -v docker-compose &>/dev/null; then
            docker-compose -f "$DOCKER_COMPOSE_FILE" up -d
        elif docker compose version &>/dev/null 2>&1; then
            docker compose -f "$DOCKER_COMPOSE_FILE" up -d
        else
            msg_error "Docker Compose non disponible"
            return 1
        fi
        
        if [[ $? -eq 0 ]]; then
            msg_success "Service Wireguard démarré avec succès !"
            # Récupérer l'IP de la machine
            LOCAL_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || ip route get 1 | awk '{print $NF;exit}' 2>/dev/null || echo "localhost")
            echo -e "\e[36m🌐 Interface web accessible sur : https://$LOCAL_IP:$CURRENT_PORT\e[0m"
        else
            msg_error "Erreur lors du démarrage du service"
        fi
    else
        msg_info "Service non démarré. Vous pouvez le lancer plus tard depuis le menu principal."
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
