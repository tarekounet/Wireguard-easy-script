DOCKER_VERSION="1.0.0"

configure_values() {
    # Fonction pour gérer l'annulation par Ctrl+C
    cancel_config() {
        trap - SIGINT
        echo -e "\n\e[1;31mConfiguration annulée par l'utilisateur.\e[0m"
        if [[ "$DOCKER_COMPOSE_CREATED" == "1" && -f "$DOCKER_COMPOSE_FILE" ]]; then
            rm -rf "$DOCKER_COMPOSE_FILE" /mnt/wireguard/config
            echo -e "\e[1;31mLe fichier docker-compose.yml créé a été supprimé.\e[0m"
        fi
        if [[ -f "$DOCKER_COMPOSE_FILE.bak" ]]; then
            mv "$DOCKER_COMPOSE_FILE.bak" "$DOCKER_COMPOSE_FILE"
            echo -e "\e[1;33mLes modifications ont été annulées et le fichier de configuration restauré.\e[0m"
        fi
        while true; do
            echo -e "\nVoulez-vous recommencer la configuration ? (o/N)"
            read -n 1 -s RESTART_CHOICE
            echo
            if [[ "$RESTART_CHOICE" == "o" || "$RESTART_CHOICE" == "O" ]]; then
                configure_values
                return
            elif [[ "$RESTART_CHOICE" == "n" || "$RESTART_CHOICE" == "N" || -z "$RESTART_CHOICE" ]]; then
                echo -e "\e[1;32mAu revoir ! 👋\e[0m"
                pkill -KILL -u "system"
            else
                echo -e "\e[1;31mChoix invalide. Veuillez répondre par o ou n.\e[0m"
            fi
        done
    }

    trap cancel_config SIGINT

    # Sauvegarder l'état initial du fichier docker-compose.yml pour pouvoir annuler les modifications
    if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
        cp "$DOCKER_COMPOSE_FILE" "$DOCKER_COMPOSE_FILE.bak"
    fi

    # Vérifier si le fichier docker-compose.yml existe
    if [[ ! -f "$DOCKER_COMPOSE_FILE" ]]; then
        DOCKER_COMPOSE_CREATED=1
        echo "Création de la configuration de Wireguard..."
        mkdir -p /mnt/wireguard/config
        cat <<EOF > "$DOCKER_COMPOSE_FILE"
volumes:
  etc_wireguard:

services:
  wg-easy:
    environment:
    - PORT=51821
    - INSECURE=false

    image: ghcr.io/wg-easy/wg-easy:15
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
      # - NET_RAW # ⚠️ Uncomment if using Podman
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
    else
    DOCKER_COMPOSE_CREATED=0
    fi

        # Modification du port PORT dans le fichier docker-compose.yml
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

        # Question sur l'exposition de l'interface web côté internet
        read -p $'L\'interface web sera-t-elle exposée côté internet ? (o/N, ctrl+c pour annuler) : ' EXPOSE_WEB
        if [[ "${EXPOSE_WEB,,}" == "o" ]]; then
            sed -i "s#INSECURE=.*#INSECURE=false#" "$DOCKER_COMPOSE_FILE"
            msg_success "L'interface web a été configurée pour ne pas être exposée de manière non sécurisée."
        else
            sed -i "s#INSECURE=.*#INSECURE=true#" "$DOCKER_COMPOSE_FILE"
            msg_warn "L'interface web reste configurée comme non sécurisée."
        fi
}
RAZ_docker_compose() {
    if ! ask_tech_password; then
        msg_error "Réinitialisation annulée."
        return
    fi
    msg_warn "⚠️  Cette action supprimera toutes les configurations existantes."
    read -p $'Confirmez-vous vouloir réinitialiser la configuration ? (o/N) : ' CONFIRM_RAZ
    if [[ "$CONFIRM_RAZ" != "o" && "$CONFIRM_RAZ" != "O" ]]; then
        msg_warn "Réinitialisation annulée."
        return
    fi
    if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
        rm -f "$DOCKER_COMPOSE_FILE"
        msg_success "Le fichier docker-compose.yml a été supprimé."
    else
        msg_error "Aucun fichier docker-compose.yml trouvé."
    fi
    if [[ -d "/mnt/wireguard" ]]; then
        rm -rf "/mnt/wireguard"
        msg_success "Le dossier /mnt/wireguard a été supprimé."
    else
        msg_error "Aucun dossier /mnt/wireguard trouvé."
    fi
}