# Protection : ce module ne doit être chargé que par config_wg.sh
if [[ "$(basename -- "$0")" == "utils.sh" ]]; then
    echo -e "\e[1;31mCe module ne doit pas être lancé directement, mais via config_wg.sh !\e[0m"
    exit 1
fi
##############################
#        VERSION MODULE      #
##############################

UTILS_VERSION="1.3.0"

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

log_action() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> /var/log/wg-easy-script.log
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

get_github_branch() {
    # Utilise la variable globale SCRIPT_CHANNEL
    if [[ "$SCRIPT_CHANNEL" == "beta" ]]; then
        echo "beta"
    else
        echo "main"
    fi
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

show_modules_versions() {
    clear
    msg_info "Versions des modules chargés :"
    for file in "$(dirname "${BASH_SOURCE[0]}")"/*.sh; do
        mod=$(basename "$file" .sh)
        local_var=$(echo "${mod^^}_VERSION")
        local_version="${!local_var:-inconnue}"
        remote_version=$(get_remote_module_version "$mod.sh")
        if [[ -z "$remote_version" ]]; then
            status="\e[33m(Version distante inconnue)\e[0m"
        elif [[ "$local_version" != "$remote_version" ]]; then
            status="\e[33m(Mise à jour dispo: $remote_version)\e[0m"
        else
            status="\e[32m(à jour)\e[0m"
        fi
        printf "  %-16s : %s %b\n" "$mod.sh" "$local_version" "$status"
    done
    echo -e "\n\e[1;33mAppuyez sur une touche pour revenir au menu...\e[0m"
    read
}

show_modules_versions_fancy() {
    clear
    echo -e "\e[1;36m===== Versions des modules chargés =====\e[0m"
    for file in "$(dirname "${BASH_SOURCE[0]}")"/*.sh; do
        mod_name=$(basename "$file" .sh)
        # Ignore utils.sh si tu ne veux pas l'afficher
        [[ "$mod_name" == "utils" ]] && continue
        # Cherche la variable VERSION dans le fichier
        version=$(grep -m1 -E 'VERSION="?([0-9.]+)"?' "$file" | grep -oE '[0-9]+\.[0-9.]+' || echo "inconnue")
        printf "\e[0;36m%-30s : \e[0;32m%s\e[0m\n" "$mod_name" "$version"
    done
    echo -e "\n\e[1;33mAppuyez sur une touche pour revenir au menu...\e[0m"
    read
}

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

update_modules() {
    local branch
    branch=$(get_github_branch)
    local updated=0
    for mod in utils conf docker menu debian_tools; do
        remote_version=$(get_remote_module_version "$mod.sh")
        local_var=$(echo "${mod^^}_VERSION")
        local_version="${!local_var}"
        if [[ -n "$remote_version" && "$local_version" != "$remote_version" ]]; then
            if curl -fsSL -o "lib/$mod.sh" "https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${branch}/lib/$mod.sh"; then
                msg_success "Module \"$mod\" mis à jour (v$local_version → v$remote_version)"
                updated=1
            else
                msg_error "Échec de la mise à jour du module \"$mod\""
            fi
        else
            msg_info "Module \"$mod\" est déjà à jour (v$local_version)."
        fi
    done
    if [[ "$updated" -eq 1 ]]; then
        msg_warn "Relance le script pour charger les nouveaux modules."
    else
        msg_info "Tous les modules sont déjà à jour."
    fi
}

##############################
#     Check des prerequis    #
############################## 

check_and_install_prerequisites() {
    local missing=0

    # Docker
    if ! command -v docker >/dev/null 2>&1; then
        msg_warn "Docker n'est pas installé. Installation en cours..."
        run_as_root apt update
        run_as_root apt install -y docker.io
        missing=1
    fi

    # docker compose (plugin ou standalone)
    if ! docker compose version >/dev/null 2>&1 && ! command -v docker-compose >/dev/null 2>&1; then
        msg_warn "docker compose n'est pas installé. Installation en cours..."
        run_as_root apt install -y docker-compose-plugin
        missing=1
    fi

    # sudo
    if ! command -v sudo >/dev/null 2>&1; then
        msg_warn "sudo n'est pas installé. Installation en cours..."
        apt update
        apt install -y sudo
        missing=1
    fi

    # curl
    if ! command -v curl >/dev/null 2>&1; then
        msg_warn "curl n'est pas installé. Installation en cours..."
        run_as_root apt update
        run_as_root apt install -y curl
        missing=1
    fi

    # btop (optionnel)
    if ! command -v btop >/dev/null 2>&1; then
        msg_warn "btop n'est pas installé (optionnel, pour le monitoring). Installation en cours..."
        run_as_root apt update
        run_as_root apt install -y btop
    fi

    if [[ "$missing" -eq 1 ]]; then
        msg_success "Les prérequis manquants ont été installés. Veuillez relancer le script si besoin."
    else
        msg_success "Tous les prérequis sont présents."
    fi
}

################################
#   Création de l'user + acl   #
################################

setup_script_user() {
    local user="system"
    # Utilise le dossier où est lancé config_wg.sh comme cible
    local target_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    local script_name="config_wg.sh"
    local script_entry="$target_dir/$script_name"
    local password

    # Demande le mot de passe à l'utilisateur (en masqué)
    read -s -p "Entrez le mot de passe à définir pour l'utilisateur '$user' : " password
    echo

    # Crée l'utilisateur s'il n'existe pas
    if ! id "$user" &>/dev/null; then
        run_as_root useradd -m -s /bin/bash "$user"
        echo "$user:$password" | run_as_root chpasswd
        msg_success "Utilisateur '$user' créé avec succès."
    else
        msg_info "L'utilisateur '$user' existe déjà."
    fi

    # Ajoute au groupe docker
    if ! id -nG "$user" | grep -qw docker; then
        run_as_root usermod -aG docker "$user"
        msg_success "Utilisateur '$user' ajouté au groupe docker."
    fi

    # Crée le dossier cible si besoin
    run_as_root mkdir -p "$target_dir"

    # Copie le script principal si absent
    if [[ ! -f "$script_entry" ]]; then
        # Trouve le chemin absolu du script courant
        local current_script_path="$(realpath "$0")"
        run_as_root cp "$current_script_path" "$script_entry"
        msg_success "Script principal copié dans $target_dir."
    fi

    # Donne les droits d'écriture sur le dossier du script
    run_as_root chown -R "$user":"$user" "$target_dir"
    run_as_root chmod -R u+rwX "$target_dir"

    # Ajoute le lancement auto du script à la connexion (dans .bash_profile)
    local profile="/home/$user/.bash_profile"
    if ! grep -q "$script_entry" "$profile" 2>/dev/null; then
        echo "[[ \$- == *i* ]] && bash \"$script_entry\"" | run_as_root tee -a "$profile" >/dev/null
        msg_success "Le script sera lancé automatiquement à la connexion de $user."
    fi
}

##############################
#   MISE À JOUR DU SCRIPT    #
##############################

update_script() {
    clear
    echo -e "\e[1;36m===== Mise à jour du script =====\e[0m"
    local branch="${SCRIPT_CHANNEL:-main}"
    local update_url="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${branch}/config_wg.sh"

    if curl -fsSL "$update_url" -o "$0.new"; then
        if ! cmp -s "$0" "$0.new"; then
            cp "$0" "$SCRIPT_BACKUP"
            mv "$0.new" "$0"
            chmod +x "$0"
            echo -e "\e[32mScript mis à jour avec succès !\e[0m"
            echo -e "\nAppuyez sur une touche pour relancer le script..."
            read -n 1 -s
            exec "$0"
        else
            rm "$0.new"
            echo -e "\e[33mAucune mise à jour disponible.\e[0m"
        fi
    else
        echo -e "\e[31mLa mise à jour du script a échoué.\e[0m"
    fi
}

##############################
#    CHANGEMENT DE CANAL     #
##############################

switch_channel() {
    local new_channel url
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
    url="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${new_channel}/config_wg.sh"

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

##############################
#   MISE À JOUR DU SCRIPT    #
##############################

update_script() {
    clear
    echo -e "\e[1;36m===== Mise à jour du script =====\e[0m"
    local branch="${SCRIPT_CHANNEL:-main}"
    local update_url="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${branch}/config_wg.sh"

    if curl -fsSL "$update_url" -o "$0.new"; then
        if ! cmp -s "$0" "$0.new"; then
            cp "$0" "$SCRIPT_BACKUP"
            mv "$0.new" "$0"
            chmod +x "$0"
            echo -e "\e[32mScript mis à jour avec succès !\e[0m"
            echo -e "\nAppuyez sur une touche pour relancer le script..."
            read -n 1 -s
            exec "$0"
        else
            rm "$0.new"
            echo -e "\e[33mAucune mise à jour disponible.\e[0m"
        fi
    else
        echo -e "\e[31mLa mise à jour du script a échoué.\e[0m"
    fi
}

##############################
#    CHANGEMENT DE CANAL     #
##############################

canal_blocage() {
    if [[ "$CURRENT_CHANNEL" == "stable" && -n "$VERSION_STABLE_CONF" && -n "$VERSION_BETA_CONF" && "$VERSION_STABLE_CONF" > "$VERSION_BETA_CONF" ]]; then
    echo -e "\e[31mLa version STABLE est plus récente que la version BETA. Passage au canal BETA interdit.\e[0m"
    SKIP_PAUSE=0
else
    switch_channel
fi
}
switch_channel() {
    local new_channel url
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
    url="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${new_channel}/config_wg.sh"

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
shutdown_vm() {
    clear
    if ask_tech_password; then
        echo -e "\e[1;33mExtinction de la VM...\e[0m"
            run_as_root /sbin/poweroff
    else
        echo -e "\e[1;31mExtinction annulée.\e[0m"
    fi
}

reboot_vm() {
    clear
    if ask_tech_password; then
        echo -e "\e[1;33mRedémarrage de la VM...\e[0m"
        run_as_root /sbin/reboot
    else
        echo -e "\e[1;31mExtinction annulée.\e[0m"
    fi
}

rename_vm() {
    clear
    if ask_tech_password; then
        read -p $'\e[1;33mEntrez le nouveau nom de la VM : \e[0m' new_name
        if [[ -z "$new_name" ]]; then
            echo -e "\e[1;31mNom invalide.\e[0m"
            return 1
        fi
        run_as_root hostnamectl set-hostname "$new_name"
        echo -e "\e[1;32mNom de la VM modifié avec succès en : $new_name\e[0m"
    else
        echo -e "\e[1;31mChangement de nom annulé.\e[0m"
    fi
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

configure_ip_vm() {
    # Modifier l'adresse IP du serveur
    echo -e "\e[1;33mInterfaces réseau physiques détectées :\e[0m"
    ip -o link show | awk -F': ' '$3 ~ /ether/ && $2 ~ /^eth/ {print NR-1")",$2}'
    read -p $'\e[1;33mNuméro de l\'interface à modifier (laisser vide pour annuler) : \e[0m' IFACE_NUM
    if [[ -z "$IFACE_NUM" ]]; then
        echo -e "\e[1;33mModification annulée.\e[0m"
    SKIP_PAUSE_DEBIAN=0
        break
    fi
    IFACE=$(ip -o link show | awk -F': ' '$3 ~ /ether/ && $2 ~ /^eth/ {print $2}' | sed -n "$((IFACE_NUM))p")
    if [[ -z "$IFACE" ]]; then
        echo -e "\e[1;31mInterface invalide.\e[0m"
        SKIP_PAUSE_DEBIAN=0
        break
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