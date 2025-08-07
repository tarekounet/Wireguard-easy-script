#!/bin/bash
##############################
#      GESTION DES ERREURS   #
##############################

# Fonction de log pour les erreurs (affichage console uniquement)
log_error() {
    local message="$1"
    echo -e "\e[1;31m[ERREUR]\e[0m $message" >&2
}

###############################
#       CENTRAGE BLOCK        # 
###############################

center_block() {
    local content=("$@")
    local cols rows
    read -r cols rows <<< "$(get_screen_size)"

    # Calcul du nombre de lignes et de la largeur max
    local max_width=0
    for line in "${content[@]}"; do
        [[ ${#line} -gt $max_width ]] && max_width=${#line}
    done
    local block_height=${#content[@]}

    # Calcul du décalage
    local pad_top=$(( (rows - block_height) / 2 ))
    local pad_left=$(( (cols - max_width) / 2 ))

    # Affichage du bloc centré
    for ((i=0; i<pad_top; i++)); do echo ""; done
    for line in "${content[@]}"; do
        printf "%*s%s\n" $pad_left "" "$line"
    done
}

##############################
#         LOGO ASCII         #
##############################

function get_screen_size() {
    cols=$(tput cols)
    rows=$(tput lines)
    echo "$cols $rows"
}

show_logo_ascii() {
    local ascii_art="
============================================================
        .__                                             .___
__  _  _|__|______   ____   ____  __ _______ _______  __| _/
\ \/ \/ /  \_  __ \_/ __ \ / ___\|  |  \__  \_  __  \/ __ |
 \     /|  ||  | \/\  ___// /_/  >  |  // __ \|  | \/ /_/ |
  \/\_/ |__||__|    \___  >___  /|____/(____  /__|  \____ |
                        \/_____/            \/           \/

=================== Easy Script Manager ====================

"
    clear
    local line_num=0
    local colors=(31 91 91 31 91 31 91 31 91 31 91 31)
    local color_index=0
    local color_count=${#colors[@]}
    while IFS= read -r line; do
        if [[ $line_num -eq 0 || $line =~ ^=+$ ]]; then
            printf "\033[97m%s\033[0m\n" "$line"
        elif [[ $line =~ "Easy Script Manager" ]]; then
            printf "\033[97m%s\033[0m\n" "$line"
        else
            printf "\033[%sm%s\033[0m\n" "${colors[color_index]}" "$line"
            color_index=$(( (color_index + 1) % color_count ))
        fi
        line_num=$((line_num + 1))
    done <<< "$ascii_art"
}
##############################
#      AFFICHAGE COULEUR     #
##############################

msg_info()    { echo -e "\e[1;36m$1\e[0m"; }
msg_success() { echo -e "\e[1;32m$1\e[0m"; }
msg_warn()    { echo -e "\e[1;33m$1\e[0m"; }
msg_error()   { echo -e "\e[1;31m$1\e[0m"; }

##############################
#      VALIDATION ENTRÉES    #
##############################

validate_port() {
    local port="$1"
    [[ "$port" =~ ^[0-9]+$ ]] && (( port >= 1 && port <= 65535 ))
}
validate_yesno() {
    local choice="${1,,}"
    [[ "$choice" == "o" || "$choice" == "n" || -z "$choice" ]]
}
validate_ip() {
    local ip="$1"
    [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] && 
    awk -F. '{for(i=1;i<=4;i++) if($i>255) exit 1}' <<< "$ip"
}

#########################
#    DOCKER_fonction    #
#########################

start_wireguard () {
    if ! docker compose -f "$DOCKER_COMPOSE_FILE" up -d; then
        echo -e "\e[1;31mÉchec du démarrage de Wireguard.\e[0m"
        return 1
    fi
    echo -e "\e[1;32mWireguard démarré avec succès.\e[0m"
}
stop_wireguard () {
    if ! docker compose -f "$DOCKER_COMPOSE_FILE" down; then
        echo -e "\e[1;31mÉchec de l'arrêt de Wireguard.\e[0m"
        return 1
    fi
    echo -e "\e[1;32mWireguard arrêté avec succès.\e[0m"
}
restart_wireguard () {
    if ! docker compose -f "$DOCKER_COMPOSE_FILE" restart; then
        echo -e "\e[1;31mÉchec du redémarrage de Wireguard.\e[0m"
        return 1
    fi
    echo -e "\e[1;32mWireguard redémarré avec succès.\e[0m"
} 