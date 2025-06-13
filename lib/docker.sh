#!/bin/bash
CONFIG_WG_PATH="$HOME/wireguard-script-manager/config_wg.sh"
if [[ -z "$CONFIG_WG_SOURCED" ]]; then
    source "$CONFIG_WG_PATH"
fi

##############################
#      CONSTANTES            #
##############################

DOCKER_COMPOSE_DIR="/mnt/wireguard"

# Récupérer la valeur depuis le bon fichier de conf
WG_EASY_VERSION=$(get_conf_value "WG_EASY_VERSION" "$CONF_FILE")
[[ -z "$WG_EASY_VERSION" ]] && WG_EASY_VERSION="inconnu"

##############################
#        VERSION MODULE      #
##############################

DOCKER_VERSION="1.1.5"

##############################
#        LOGS DOCKER         #
##############################

log_docker_action() {
    local msg="$1"
    echo "$(date '+%F %T') [DOCKER] $msg" >> "$DOCKER_LOG"
}

##############################
#   CONFIGURATION PRINCIPALE #
##############################
cancel_config() {
    trap - SIGINT
    echo -e "\n\e[1;31mConfiguration annulée par l'utilisateur.\e[0m"
    if [[ "$DOCKER_COMPOSE_CREATED" == "1" && -f "$DOCKER_COMPOSE_FILE" ]]; then
        read -p $'Voulez-vous supprimer le fichier docker-compose.yml créé ? (o/N) : ' CONFIRM_DEL
        if [[ "$CONFIRM_DEL" =~ ^[oO]$ ]]; then
            rm -rf "$DOCKER_COMPOSE_FILE" "$DOCKER_COMPOSE_DIR/config"
            echo -e "\e[1;31mLe fichier docker-compose.yml créé a été supprimé.\e[0m"
        else
            echo -e "\e[1;33mLe fichier docker-compose.yml a été conservé.\e[0m"
        fi
    fi
    exit 1
}

configure_values() {
    # Fonction d'annulation (Ctrl+C) pendant la création
    trap cancel_config SIGINT

    # Sauvegarde de l'état initial
    if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
        cp "$DOCKER_COMPOSE_FILE" "$DOCKER_COMPOSE_FILE.bak"
    fi

    # Création du fichier si absent
    if [[ ! -f "$DOCKER_COMPOSE_FILE" ]]; then
        trap cancel_config SIGINT
        DOCKER_COMPOSE_CREATED=1
        echo "Création de la configuration de Wireguard..."
        # Vérifier et créer $HOME/wireguard et $HOME/wireguard/config si nécessaire
        [[ -d "$DOCKER_COMPOSE_DIR" ]] || mkdir -p "$DOCKER_COMPOSE_DIR"
        [[ -d "$DOCKER_COMPOSE_DIR/config" ]] || mkdir -p "$DOCKER_COMPOSE_DIR/config"
        cat <<EOF > "$DOCKER_COMPOSE_FILE"
volumes:
  etc_wireguard:
    driver: local
    driver_opts:
      type: none
      device: ${DOCKER_COMPOSE_DIR}/config
      o: bind

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

##############################
#   RÉINITIALISATION CONFIG  #
##############################

RAZ_docker_compose() {
    if ! ask_tech_password; then
        msg_error "Réinitialisation annulée."
        return
    fi
    msg_warn "⚠️  Cette action supprimera toutes les configurations existantes."
    read -p $'Confirmez-vous vouloir réinitialiser la configuration ? (o/N) : ' CONFIRM_RAZ
    if [[ ! "$CONFIRM_RAZ" =~ ^[oO]$ ]]; then
        msg_warn "Réinitialisation annulée."
        return
    fi
    # Stopper le conteneur docker s'il est en cours d'exécution
    if docker ps -a --format '{{.Names}}' | grep -q '^wg-easy$'; then
        docker stop wg-easy
        docker rm wg-easy
        msg_success "Le conteneur wg-easy a été arrêté et supprimé."
    fi
    # Supprimer le docker-compose.yml
    if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
        rm -f "$DOCKER_COMPOSE_FILE"
        msg_success "Le fichier docker-compose.yml a été supprimé."
    else
        msg_error "Aucun fichier docker-compose.yml trouvé."
    fi
    # Supprimer le contenu du dossier config dans /mnt/wireguard
    if [[ -d "$DOCKER_COMPOSE_DIR/config" ]]; then
        rm -rf "$DOCKER_COMPOSE_DIR/config"/*
        msg_success "Le contenu du dossier config a été supprimé."
    else
        msg_error "Aucun dossier config trouvé dans $DOCKER_COMPOSE_DIR."
    fi
}

# Nettoyage : suppression des fonctions, variables et helpers non utilisés ou jamais appelés