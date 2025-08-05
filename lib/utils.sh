# Protection : ce module ne doit être chargé que par config_wg.sh
if [[ "$(basename -- "$0")" == "utils.sh" ]]; then
    echo -e "\e[1;31mCe module ne doit pas être lancé directement, mais via config_wg.sh !\e[0m"
    exit 1
fi

##############################
#        LOGS D'ERREUR       #
##############################

# Variables de logging (erreurs uniquement)
ERROR_LOG_FILE="${ERROR_LOG_FILE:-/tmp/wireguard-errors.log}"
ERROR_LOG_TO_FILE="${ERROR_LOG_TO_FILE:-false}"
ERROR_LOG_MAX_SIZE="${ERROR_LOG_MAX_SIZE:-1048576}"  # 1MB en bytes

# Fonction pour écrire les erreurs dans le fichier de log
write_error_log() {
    local message="$1"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    # Vérifier si on doit logger vers un fichier
    if [[ "$ERROR_LOG_TO_FILE" == "true" ]]; then
        # Rotation automatique si le fichier devient trop volumineux
        if [[ -f "$ERROR_LOG_FILE" ]] && [[ $(stat -f%z "$ERROR_LOG_FILE" 2>/dev/null || stat -c%s "$ERROR_LOG_FILE" 2>/dev/null) -gt $ERROR_LOG_MAX_SIZE ]]; then
            mv "$ERROR_LOG_FILE" "${ERROR_LOG_FILE}.old" 2>/dev/null
        fi
        
        echo "[$timestamp] [ERROR] $message" >> "$ERROR_LOG_FILE"
    fi
}

# Fonction de log pour les erreurs uniquement
log_error() {
    local message="$1"
    local show_console="${2:-true}"
    
    write_error_log "$message"
    
    if [[ "$show_console" == "true" ]]; then
        echo -e "\e[1;31m[ERREUR]\e[0m $message" >&2
    fi
}

# Fonction pour activer le logging d'erreur vers fichier
enable_error_logging() {
    local log_file="$1"
    ERROR_LOG_TO_FILE="true"
    if [[ -n "$log_file" ]]; then
        ERROR_LOG_FILE="$log_file"
    fi
    echo "✓ Logging d'erreur vers fichier activé : $ERROR_LOG_FILE"
}

# Fonction pour désactiver le logging d'erreur vers fichier
disable_error_logging() {
    ERROR_LOG_TO_FILE="false"
    echo "✓ Logging d'erreur vers fichier désactivé"
}

##############################
#        acces ROOT          #
##############################

run_as_root() {
    if [[ $EUID -ne 0 ]]; then
        sudo bash -c "$*"
    else
        bash -c "$*"
    fi
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
            printf "\033[90m%s\033[0m\n" "$line"
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
    [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] && \
    awk -F. '{for(i=1;i<=4;i++) if($i>255) exit 1}' <<< "$ip"
}

##############################
#      CHANGE PORT WEB       #
##############################

change_wg_easy_web_port() {
    local compose_file="$DOCKER_COMPOSE_FILE"
    local new_port

    read -p $'\e[1;33mEntrez le nouveau port pour l’interface web (par défaut 51821) : \e[0m' new_port
    if ! validate_port "$new_port"; then
        echo -e "\e[1;31mPort invalide.\e[0m"
        return 1
    fi

    # Modifie la variable d'environnement PORT="" dans le docker-compose
    if grep -qE 'PORT="?([0-9]+)"?' "$compose_file"; then
        sed -i -E "s/(PORT=)\"?[0-9]+\"?/\1\"$new_port\"/" "$compose_file"
        echo -e "\e[1;32mLe port de l’interface web a été modifié à : $new_port\e[0m"
    else
        echo -e "\e[1;31mImpossible de trouver la variable PORT dans $compose_file.\e[0m"
        return 1
    fi

    # Redémarre le conteneur pour appliquer le changement
    docker compose -f "$compose_file" down
    docker compose -f "$compose_file" up -d
    echo -e "\e[1;32mWireguard redémarré avec le nouveau port web.\e[0m"
}

##############################
#     GESTION DES VERSIONS   #
##############################

version_gt() {
    local IFS=.
    local i ver1=($1) ver2=($2)
    for ((i=${#ver1[@]}; i<3; i++)); do ver1[i]=0; done
    for ((i=${#ver2[@]}; i<3; i++)); do ver2[i]=0; done
    for ((i=0; i<3; i++)); do
        if ((10#${ver1[i]} > 10#${ver2[i]})); then
            return 0
        elif ((10#${ver1[i]} < 10#${ver2[i]})); then
            return 1
        fi
    done
    return 1
}

##############################
#   MISE À JOUR DU SCRIPT    #
##############################

update_all() {
    clear
    echo -e "\e[1;36m===== Mise à jour du script et de la librairie =====\e[0m"
    local base_url="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/main"
    local main_script="config_wg.sh"
    local lib_script="lib/utils.sh"
    local updated=0

    # Met à jour le script principal
    if curl -fsSL "$base_url/$main_script" -o "$0.new"; then
        if ! cmp -s "$0" "$0.new"; then
            cp "$0" "$SCRIPT_BACKUP"
            mv "$0.new" "$0"
            chmod +x "$0"
            echo -e "\e[32mScript principal mis à jour avec succès !\e[0m"
            updated=1
        else
            rm "$0.new"
            echo -e "\e[33mAucune mise à jour du script principal.\e[0m"
        fi
    else
        echo -e "\e[31mLa mise à jour du script principal a échoué.\e[0m"
    fi

    # Met à jour la librairie
    local lib_path="$(dirname "$0")/lib/utils.sh"
    if curl -fsSL "$base_url/$lib_script" -o "$lib_path.new"; then
        if ! cmp -s "$lib_path" "$lib_path.new"; then
            cp "$lib_path" "${lib_path}.bak"
            mv "$lib_path.new" "$lib_path"
            chmod +x "$lib_path"
            echo -e "\e[32mLibrairie utils.sh mise à jour avec succès !\e[0m"
            updated=1
        else
            rm "$lib_path.new"
            echo -e "\e[33mAucune mise à jour de la librairie utils.sh.\e[0m"
        fi
    else
        echo -e "\e[31mLa mise à jour de la librairie utils.sh a échoué.\e[0m"
    fi

    if [[ $updated -eq 1 ]]; then
        echo -e "\nAppuyez sur une touche pour relancer le script..."
        read -n 1 -s
        exec "$0"
    fi
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