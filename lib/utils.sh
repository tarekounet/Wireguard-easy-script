# Sourcing du script principal si besoin
CONFIG_WG_PATH="$HOME/wireguard-script-manager/config_wg.sh"
if [[ -z "$CONFIG_WG_SOURCED" ]]; then
    source "$CONFIG_WG_PATH"
fi
log_info "Module utils chargé"
##############################
#         DEBUG MODE         #
###############################
enable_debug() {
    export DEBUG=1
    # Utilise le chemin du dossier logs du script principal si défini
    local log_dir="${SCRIPT_DIR:-.}/logs"
    mkdir -p "$log_dir"
    exec 2>>"$log_dir/debug.log"
}

disable_debug() {
    export DEBUG=0
    # Restaure la sortie d'erreur vers le terminal courant
    exec 2>/dev/tty
}

##############################
#   BRANCHE GITHUB           #
##############################

get_github_branch() {
    local channel
    CONF_FILE="${CONF_FILE:-config/wg-easy.conf}"
    channel=$(grep '^SCRIPT_CHANNEL=' "$CONF_FILE" 2>/dev/null | cut -d'"' -f2)
    [[ "$channel" == "beta" ]] && echo "beta" || echo "main"
}

##############################
#        VERSION MODULE      #
##############################

UTILS_VERSION="1.4.1"

##############################
#        acces ROOT          #
##############################

run_as_root() {
    if [[ $EUID -ne 0 ]]; then
        sudo "$@"
    else
        "$@"
    fi
}

###############################
#         LOGS ACTION         #
###############################
LOG_FILE="$SCRIPT_DIR/logs/wg-easy-script.log"
ERROR_LOG="$SCRIPT_DIR/logs/error.log"
INSTALL_LOG="$SCRIPT_DIR/logs/install.log"
DOCKER_LOG="$SCRIPT_DIR/logs/docker-actions.log"
AUTH_LOG="$SCRIPT_DIR/logs/auth.log"

log_action() {
    local msg="$1"
    echo "$(date '+%F %T') [ACTION] $msg" >> "$LOG_FILE"
}

log_error() {
    local msg="$1"
    echo "$(date '+%F %T') [ERROR] $msg" >> "$ERROR_LOG"
}

log_install() {
    local msg="$1"
    echo "$(date '+%F %T') [INSTALL] $msg" >> "$INSTALL_LOG"
}

log_docker() {
    local msg="$1"
    echo "$(date '+%F %T') [DOCKER] $msg" >> "$DOCKER_LOG"
}

log_auth() {
    local msg="$1"
    echo "$(date '+%F %T') [AUTH] $msg" >> "$AUTH_LOG"
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
#         LOGGING            #
##############################

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

get_remote_module_version() {
    local module="$1"
    local branch url version
    branch=$(get_github_branch)
    url="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${branch}/lib/${module}"
    version=$(curl -fsSL "$url" | grep -m1 -E 'VERSION="?([0-9.]+)"?' | grep -oE '[0-9]+\.[0-9.]+')
    if [[ -z "$version" ]]; then
        echo "inconnue"
    else
        echo "$version"
    fi
}

##############################
#   AFFICHAGE DES VERSIONS   #
##############################

show_changelog() {
    clear
    if [[ -f "CHANGELOG.md" ]]; then
        less -R "CHANGELOG.md"
    else
        echo -e "\e[31mAucun changelog trouvé.\e[0m"
        sleep 2
    fi
}
##############################
#     MISE À JOUR MODULES    #
##############################

check_updates() {
    MODULE_UPDATE_AVAILABLE=0
    SCRIPT_UPDATE_AVAILABLE=0

    local branch
    branch=$(get_github_branch)

    # Vérification des modules
    for mod in utils conf docker menu debian_tools; do
        local_var=$(echo "${mod^^}_VERSION")
        local_version="${!local_var}"
        remote_version=$(get_remote_module_version "$mod.sh")
        if [[ -n "$remote_version" && "$local_version" != "$remote_version" ]]; then
            MODULE_UPDATE_AVAILABLE=1
            break
        fi
    done

    # Vérification du script principal
    remote_script_version=$(curl -fsSL "https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${branch}/config_wg.sh" | grep -m1 -E 'SCRIPT_BASE_VERSION_INIT="?([0-9.]+)"?' | grep -oE '[0-9]+\.[0-9.]+')
    if [[ -n "$remote_script_version" && "$SCRIPT_BASE_VERSION_INIT" != "$remote_script_version" ]]; then
        SCRIPT_UPDATE_AVAILABLE=1
    fi
}

##############################
#   MISE À JOUR DU SCRIPT    #
##############################

update_script_and_libs() {
    clear
    echo -e "\e[1;36m===== Vérification des mises à jour du script et des modules =====\e[0m"
    check_updates

    if [[ "$MODULE_UPDATE_AVAILABLE" -eq 0 && "$SCRIPT_UPDATE_AVAILABLE" -eq 0 ]]; then
        echo -e "\e[32mAucune mise à jour disponible pour le script ou les modules.\e[0m"
        echo -e "\nAppuyez sur une touche pour revenir au menu..."
        read -n 1 -s
        return
    fi

    echo -e "\e[33mDes mises à jour sont disponibles.\e[0m"
    local branch
    branch=$(get_github_branch)
    local update_url="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${branch}/config_wg.sh"
    local lib_url="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${branch}/lib"
    local script_dir="$(dirname "$0")"
    local lib_dir="$script_dir/lib"

    # Sauvegarde du script principal
    if [[ -f "$0" ]]; then
        cp "$0" "$SCRIPT_BACKUP"
    fi

    # Mise à jour du script principal si nécessaire
    if [[ "$SCRIPT_UPDATE_AVAILABLE" -eq 1 ]]; then
        if curl -fsSL "$update_url" -o "$0.new"; then
            if ! cmp -s "$0" "$0.new"; then
                mv "$0.new" "$0"
                chmod +x "$0"
                echo -e "\e[32mScript principal mis à jour avec succès !\e[0m"
            else
                rm "$0.new"
                echo -e "\e[33mAucune mise à jour du script principal.\e[0m"
            fi
        else
            echo -e "\e[31mLa mise à jour du script principal a échoué.\e[0m"
        fi
    else
        echo -e "\e[32mLe script principal est déjà à jour.\e[0m"
    fi

    # Mise à jour des modules si nécessaire
    if [[ "$MODULE_UPDATE_AVAILABLE" -eq 1 && -d "$lib_dir" ]]; then
        for mod in utils conf docker menu debian_tools; do
            remote_mod_url="$lib_url/$mod.sh"
            local_mod_file="$lib_dir/$mod.sh"
            if curl -fsSL "$remote_mod_url" -o "$local_mod_file.new"; then
                if ! cmp -s "$local_mod_file" "$local_mod_file.new"; then
                    mv "$local_mod_file.new" "$local_mod_file"
                    chmod +x "$local_mod_file"
                    echo -e "\e[32mModule $mod mis à jour.\e[0m"
                else
                    rm "$local_mod_file.new"
                fi
            else
                echo -e "\e[31mÉchec de la mise à jour du module $mod.\e[0m"
            fi
        done
    else
        echo -e "\e[32mTous les modules sont déjà à jour.\e[0m"
    fi

    echo -e "\nAppuyez sur une touche pour relancer le script..."
    read -n 1 -s
    exec "$0"
}

##############################
#    CHANGEMENT DE CANAL     #
##############################

canal_blocage() {
    if [[ "$CURRENT_CHANNEL" == "stable" && -n "$VERSION_STABLE_CONF" && -n "$VERSION_BETA_CONF" && "$VERSION_STABLE_CONF" > "$VERSION_BETA_CONF" ]]; then
    echo -e "\e[31mLa vE est plus récente que la version BETA. Passage au canal BETA interdit.\e[0m"
    SKIP_PAUSE=0
else
    switch_channel
fi
}
switch_channel() {
    local new_channel url branch
    if [[ "$SCRIPT_CHANNEL" == "stable" ]]; then
        EXPECTED_HASH=$(get_conf_value "EXPECTED_HASH")
        read -sp $'\e[1;33mEntrez le mot de passe technique pour passer en beta : \e[0m' PASS
        echo
        ENTERED_HASH=$(openssl passwd -6 -salt Qw8n0Qw8 "$PASS")
        if [[ "$ENTERED_HASH" != "$EXPECTED_HASH" ]]; then
            echo -e "\e[1;31mMot de passe incorrect. Passage en beta annulé.\e[0m"
            sleep 2
            return
        fi
        echo -e "\e[1;33m⚠️  Vous allez passer sur le canal beta. Ce canal peut contenir des fonctionnalités instables ou expérimentales.\e[0m"
        read -p $'\e[1;33mConfirmez-vous vouloir passer en beta et accepter les risques ? (o/N) : \e[0m' CONFIRM_BETA
        if [[ "$CONFIRM_BETA" =~ ^[oO]$ ]]; then
            new_channel="beta"
        else
            echo -e "\e[1;33mChangement annulé. Retour au menu principal.\e[0m"
            sleep 1
            return
        fi
    else
        new_channel="stable"
    fi

    set_conf_value "SCRIPT_CHANNEL" "$new_channel"
    set_conf_value "BETA_CONFIRMED" $([[ "$new_channel" == "beta" ]] && echo "1" || echo "0")
    branch=$(get_github_branch)
    url="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${branch}/config_wg.sh"

    if curl -fsSL "$url" -o "$0.new"; then
        mv "$0.new" "$0"
        chmod +x "$0"
        if [[ "$new_channel" == "beta" ]]; then
            echo -e "\e[1;35mLe script beta a été téléchargé. Redémarrage...\e[0m"
        else
            echo -e "\e[1;32mLe script stable a été téléchargé. Redémarrage...\e[0m"
        fi
        sleep 1
        exec "$0"
    else
        echo -e "\e[1;31mErreur lors du téléchargement du script ($new_channel).\e[0m"
        sleep 2
    fi
}

###############################
#   MENU PRINCIPAL DU SCRIPT  #
###############################

start_wireguard () {
    clear
    echo "Démarrage de Wireguard..."
    docker compose -f "$DOCKER_COMPOSE_FILE" up -d
    echo "Wireguard démarré avec succès ! 🚀"
    echo -e "\n\e[1;33mAppuyez sur une touche pour revenir au menu principal...\e[0m"
    read -n 1 -s
    exec "$0"
}   
update_wireguard() {
    clear
    echo "Mise à jour de Wireguard..."

    check_and_update_wg_easy_version

    docker compose -f "$DOCKER_COMPOSE_FILE" down --rmi all --volumes --remove-orphans
    docker compose -f "$DOCKER_COMPOSE_FILE" pull
    docker compose -f "$DOCKER_COMPOSE_FILE" up -d
    echo "Wireguard mis à jour et purgé avec succès ! ⬆️"
    echo -e "\n\e[1;33mAppuyez sur une touche pour revenir au menu principal...\e[0m"
    read -n 1 -s
    exec "$0"
}
restart_wireguard() {
    clear
    echo "Redémarrage de Wireguard..."
    docker compose -f "$DOCKER_COMPOSE_FILE" restart
    echo "Wireguard redémarré avec succès ! 🔄"
    echo -e "\n\e[1;33mAppuyez sur une touche pour revenir au menu principal...\e[0m"
    read -n 1 -s
    exec "$0"
}
shutdown_wireguard() {
    clear
    echo "Extinction de Wireguard..."
    docker compose -f "$DOCKER_COMPOSE_FILE" down
    echo "Wireguard éteint avec succès ! 📴"
    echo -e "\n\e[1;33mAppuyez sur une touche pour revenir au menu principal...\e[0m"
    read -n 1 -s
    exec "$0"
}

################################
#         Debian Tools         #
################################
list_physical_ethernet() {
    echo "Cartes Ethernet physiques détectées :"
    for iface in /sys/class/net/*; do
        iface_name=$(basename "$iface")
        # Vérifie que ce n'est pas une interface virtuelle et qu'elle a une adresse MAC
        if [[ -e "$iface/device" ]] && [[ -f "/sys/class/net/$iface_name/address" ]]; then
            mac=$(cat "/sys/class/net/$iface_name/address")
            # Exclut les interfaces loopback et sans MAC valide
            if [[ "$iface_name" != "lo" && ! "$mac" =~ ^00:00:00:00:00:00$ ]]; then
                echo " - $iface_name ($mac)"
            fi
        fi
    done
}

configure_ip_vm() {
    # Modifier l'adresse IP du serveur
    echo -e "\e[1;33mInterfaces réseau physiques détectées :\e[0m"
    local phys_ifaces=()
    local idx=1
    for iface in /sys/class/net/*; do
        iface_name=$(basename "$iface")
        # Vérifie que ce n'est pas une interface virtuelle et qu'elle a une adresse MAC
        if [[ -e "$iface/device" ]] && [[ -f "/sys/class/net/$iface_name/address" ]]; then
            mac=$(cat "/sys/class/net/$iface_name/address")
            if [[ "$iface_name" != "lo" && ! "$mac" =~ ^00:00:00:00:00:00$ ]]; then
                echo "  $idx) $iface_name ($mac)"
                phys_ifaces+=("$iface_name")
                idx=$((idx+1))
            fi
        fi
    done

    read -p $'\e[1;33mNuméro de l\'interface à modifier (laisser vide pour annuler) : \e[0m' IFACE_NUM
    if [[ -z "$IFACE_NUM" ]]; then
        echo -e "\e[1;33mModification annulée.\e[0m"
        SKIP_PAUSE_DEBIAN=0
        return
    fi

    IFACE="${phys_ifaces[$((IFACE_NUM-1))]}"
    if [[ -z "$IFACE" ]]; then
        echo -e "\e[1;31mInterface invalide.\e[0m"
        SKIP_PAUSE_DEBIAN=0
        return
    fi

    # Vérification du mode actuel (DHCP ou statique)
    DHCP_STATE="Statique"
    if nmcli device show "$IFACE" 2>/dev/null | grep -q "IP4.DHCP4.OPTION"; then
        DHCP_STATE="DHCP"
    fi
    echo -e "\e[1;33mMode actuel de l\'interface $IFACE :\e[0m $DHCP_STATE"

    read -p $'\e[1;33mVoulez-vous conserver ce mode ? (o/N) : \e[0m' KEEP_MODE
    if [[ "$KEEP_MODE" == "o" || "$KEEP_MODE" == "O" ]]; then
        echo -e "\e[1;33mMode conservé.\e[0m"
    else
        if [[ "$DHCP_STATE" == "DHCP" ]]; then
            echo -e "\e[1;33mPassage en mode statique...\e[0m"
                nmcli con mod "$IFACE" ipv4.method manual
        else
            echo -e "\e[1;33mPassage en mode DHCP...\e[0m"
                nmcli con mod "$IFACE" ipv4.method auto
                nmcli con up "$IFACE"
            echo -e "\e[1;32mMode DHCP appliqué.\e[0m"
            SKIP_PAUSE_DEBIAN=0
            break
        fi
    fi

    # Modification des valeurs en mode statique
    CUR_IP=$(ip -4 addr show "$IFACE" | awk '/inet / {print $2}')
    echo -e "\e[1;33mAdresse IP actuelle de $IFACE :\e[0m $CUR_IP"
    read -p $'\e[1;33mVoulez-vous modifier l\'adresse IP ? (o/N) : \e[0m' MODIFY_IP
    if [[ "$MODIFY_IP" == "o" || "$MODIFY_IP" == "O" ]]; then
        read -p $'\e[1;33mNouvelle adresse IP (ex : 192.168.1.100, laisser vide pour annuler) : \e[0m' NEW_IP
        if [[ -z "$NEW_IP" ]]; then
            echo -e "\e[1;33mModification annulée.\e[0m"
            SKIP_PAUSE_DEBIAN=0
            break
        fi
        MODIF_RESEAU=1
    else
        NEW_IP=$(echo "$CUR_IP" | cut -d '/' -f 1)
    fi

    # Masque
    CUR_MASK=$(echo "$CUR_IP" | cut -d '/' -f 2)
    CUR_MASK_DECIMAL=$(ipcalc -m "$CUR_IP" | awk '/Netmask/ {print $2}')
    echo -e "\e[1;33mMasque de sous-réseau actuel :\e[0m $CUR_MASK_DECIMAL"
    read -p $'\e[1;33mVoulez-vous modifier le masque de sous-réseau ? (o/N) : \e[0m' MODIFY_MASK
    if [[ "$MODIFY_MASK" == "o" || "$MODIFY_MASK" == "O" ]]; then
        read -p $'\e[1;33mNouveau masque de sous-réseau (ex : 255.255.255.0, laisser vide pour 255.255.255.0) : \e[0m' NEW_MASK_DECIMAL
        NEW_MASK_DECIMAL=${NEW_MASK_DECIMAL:-255.255.255.0}
        NEW_MASK=$(ipcalc -p "$NEW_IP/$NEW_MASK_DECIMAL" | awk '/Prefix/ {print $2}')
        MODIF_RESEAU=1
    else
        NEW_MASK="$CUR_MASK"
    fi

    # Passerelle
    CUR_GW=$(ip route | awk '/default/ {print $3}')
    echo -e "\e[1;33mPasserelle actuelle :\e[0m $CUR_GW"
    read -p $'\e[1;33mVoulez-vous modifier la passerelle ? (o/N) : \e[0m' MODIFY_GW
    if [[ "$MODIFY_GW" == "o" || "$MODIFY_GW" == "O" ]]; then
        read -p $'\e[1;33mNouvelle passerelle (laisser vide pour aucune modification) : \e[0m' NEW_GW
        MODIF_RESEAU=1
    else
        NEW_GW="$CUR_GW"
    fi

    # DNS
    CUR_DNS=$(grep "nameserver" /etc/resolv.conf | awk '{print $2}' | head -n 1)
    echo -e "\e[1;33mDNS actuel :\e[0m $CUR_DNS"
    read -p $'\e[1;33mVoulez-vous modifier le DNS ? (o/N) : \e[0m' MODIFY_DNS
    if [[ "$MODIFY_DNS" == "o" || "$MODIFY_DNS" == "O" ]]; then
        read -p $'\e[1;33mNouveau DNS (laisser vide pour aucune modification) : \e[0m' NEW_DNS
        MODIF_RESEAU=1
    else
        NEW_DNS="$CUR_DNS"
    fi

    # Appliquer uniquement si au moins une modification
    if [[ "$MODIF_RESEAU" == "1" ]]; then
            ip addr flush dev "$IFACE"
            ip addr add "$NEW_IP/$NEW_MASK" dev "$IFACE"
        if [[ -n "$NEW_GW" ]]; then
                ip route replace default via "$NEW_GW" dev "$IFACE"
        fi
        if [[ -n "$NEW_DNS" ]]; then
            echo "nameserver $NEW_DNS" |  tee /etc/resolv.conf > /dev/null
        fi
            systemctl restart networking 2>/dev/null ||  systemctl restart NetworkManager 2>/dev/null
        echo -e "\e[1;32mConfiguration appliquée. Attention, la connexion SSH peut être interrompue.\e[0m"
    else
        echo -e "\e[1;33mAucune modification réseau appliquée.\e[0m"
    fi
}

show_debian_version () {
    clear
    echo -e "\e[1;36m===== Version de Debian =====\e[0m"
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo -e "\e[1;33mNom :\e[0m $NAME"
        echo -e "\e[1;33mVersion :\e[0m $VERSION"
        echo -e "\e[1;33mID :\e[0m $ID"
        echo -e "\e[1;33mVersion ID :\e[0m $VERSION_ID"
    else
        echo -e "\e[1;31mImpossible de déterminer la version de Debian.\e[0m"
    fi
    echo -e "\n\e[1;33mAppuyez sur une touche pour revenir au menu...\e[0m"
    read
}

show_disk_space () {
    clear
    echo -e "\e[1;36m===== Espace disque =====\e[0m"
    df -h --output=source,size,used,avail,pcent,target | grep -v '^tmpfs\|^udev\|^overlay\|^Filesystem'
    echo -e "\n\e[1;33mAppuyez sur une touche pour revenir au menu...\e[0m"
    read
}

show_docker_status () {
    clear
    echo -e "\e[1;36m===== État de Docker =====\e[0m"
    if systemctl is-active --quiet docker; then
        echo -e "\e[1;32mDocker est actif.\e[0m"
        docker ps -a --format "table {{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Names}}"
    else
        echo -e "\e[1;31mDocker n'est pas actif.\e[0m"
    fi
    echo -e "\n\e[1;33mAppuyez sur une touche pour revenir au menu...\e[0m"
    read
}

show_system_monitor () {
    clear
    echo -e "\e[1;36m===== Moniteur système (btop) =====\e[0m"
    if command -v btop >/dev/null 2>&1; then
        btop
    else
        echo -e "\e[1;31mbtop n'est pas installé. Veuillez l'installer pour utiliser cette fonctionnalité.\e[0m"
        run_as_root apt update && run_as_root apt install -y btop
        btop
    fi
    echo -e "\n\e[1;33mAppuyez sur une touche pour revenir au menu...\e[0m"
    read
}

update_system () {
    clear
    echo -e "\e[1;36m===== Mise à jour du système =====\e[0m"
    run_as_root apt update && run_as_root apt upgrade -y
    echo -e "\n\e[1;33mAppuyez sur une touche pour revenir au menu...\e[0m"
    read
}

rename_vm () {
    clear
    current_name=$(hostname)
    echo -e "\e[1;33mNom actuel de la VM :\e[0m $current_name"
    read -p $'\e[1;33mEntrez le nouveau nom de la VM : \e[0m' new_name
    if [[ -z "$new_name" ]]; then
        echo -e "\e[1;31mNom invalide.\e[0m"
        SKIP_PAUSE_DEBIAN=0
        return 1
    fi
    run_as_root hostnamectl set-hostname "$new_name"
    echo -e "\e[1;32mNom de la VM modifié avec succès en : $new_name\e[0m"
}

ssh_access() {
    clear
    echo -e "\n\e[1;36m------ Modifier le port SSH ------\e[0m"
    CURRENT_SSH_PORT=$(grep -E '^Port ' /etc/ssh/sshd_config | head -n1 | awk '{print $2}')
    CURRENT_SSH_PORT=${CURRENT_SSH_PORT:-22}
    echo -e "\e[1;33mPort SSH actuel : $CURRENT_SSH_PORT\e[0m"
    read -p $'\e[1;33mNouveau port SSH (laisser vide pour aucune modification) : \e[0m' NEW_SSH_PORT
    if [[ -n "$NEW_SSH_PORT" ]]; then
        if [[ "$NEW_SSH_PORT" =~ ^[0-9]+$ ]] && (( NEW_SSH_PORT >= 1 && NEW_SSH_PORT <= 65535 )); then
            sed -i "s/^#\?Port .*/Port $NEW_SSH_PORT/" /etc/ssh/sshd_config
            systemctl restart sshd
            echo -e "\e[1;32mPort SSH modifié à $NEW_SSH_PORT. Attention, la connexion SSH peut être interrompue.\e[0m"
        else
            echo -e "\e[1;31mPort SSH invalide. Aucune modification appliquée.\e[0m"
        fi
    fi
}

reboot_vm() {
    clear
    echo -e "\e[1;36m===== Redémarrage de la VM =====\e[0m"
    if ask_tech_password; then
        run_as_root reboot
    else
        echo -e "\e[1;31mRedémarrage annulé.\e[0m"
    fi
}

shutdown_vm() {
    clear
    echo -e "\e[1;36m===== Extinction de la VM =====\e[0m"
    if ask_tech_password; then
        run_as_root shutdown now
    else
        echo -e "\e[1;31mExtinction annulée.\e[0m"
    fi
}


################################
#    UPDATE DOCKER COMPOSE     #
################################

update_wg_easy_version_only() {
    local branch
    branch=$(get_github_branch)
    # Vérifie si le fichier existe
    if [[ ! -f "$DOCKER_COMPOSE_FILE" ]]; then
        echo "Aucun fichier docker-compose.yml trouvé."
        return 1
    fi

    # Récupère l'ancienne version
    local old_version
    old_version=$(grep 'image: ghcr.io/wg-easy/wg-easy:' "$DOCKER_COMPOSE_FILE" | sed 's/.*://')

    # Met à jour la ligne image: dans le docker-compose.yml
    sed -i "s#image: ghcr.io/wg-easy/wg-easy:.*#image: ghcr.io/wg-easy/wg-easy:$WG_EASY_VERSION#" "$DOCKER_COMPOSE_FILE"
    echo "docker-compose.yml mis à jour avec la version $WG_EASY_VERSION."

    if [[ "$old_version" != "$WG_EASY_VERSION" ]]; then
        # Purge les images obsolètes et les volumes non utilisés
        docker compose -f "$DOCKER_COMPOSE_FILE" down --rmi all --volumes --remove-orphans
        docker compose -f "$DOCKER_COMPOSE_FILE" pull
        docker compose -f "$DOCKER_COMPOSE_FILE" up -d
        echo "Wireguard mis à jour et purgé avec succès !"
    else
        # Si pas de changement de version, simple redémarrage
        docker compose -f "$DOCKER_COMPOSE_FILE" up -d
        echo "Wireguard déjà à jour, redémarrage effectué."
    fi
}

detect_new_wg_easy_version() {
    local branch
    branch=$(get_github_branch)
    WG_EASY_VERSION_DISTANT=$(curl -fsSL "https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${branch}/WG_EASY_VERSION" | head -n1)
    if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
        WG_EASY_VERSION_LOCAL=$(grep 'image: ghcr.io/wg-easy/wg-easy:' "$DOCKER_COMPOSE_FILE" | sed 's/.*://')
    else
        WG_EASY_VERSION_LOCAL=""
    fi
    if [[ "$WG_EASY_VERSION_LOCAL" != "$WG_EASY_VERSION_DISTANT" && -n "$WG_EASY_VERSION_DISTANT" ]]; then
        export NEW_WG_EASY_VERSION="$WG_EASY_VERSION_DISTANT"
        export CURRENT_WG_EASY_VERSION="$WG_EASY_VERSION_LOCAL"
    else
        export NEW_WG_EASY_VERSION=""
        export CURRENT_WG_EASY_VERSION="$WG_EASY_VERSION_LOCAL"
    fi
}
# Nettoyage : suppression des fonctions, variables et helpers non utilisés ou jamais appelés