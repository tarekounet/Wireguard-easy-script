UTILS_VERSION="1.0.0"

msg_info()    { echo -e "\e[1;36m$1\e[0m"; }
msg_success() { echo -e "\e[1;32m$1\e[0m"; }
msg_warn()    { echo -e "\e[1;33m$1\e[0m"; }
msg_error()   { echo -e "\e[1;31m$1\e[0m"; }

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
log_action() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> /var/log/wg-easy-script.log
}
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
show_modules_versions() {
    msg_info "Versions des modules chargés :"
    echo "  utils.sh         : $UTILS_VERSION"
    echo "  conf.sh          : $CONF_VERSION"
    echo "  docker.sh        : $DOCKER_VERSION"
    echo "  menu.sh          : $MENU_VERSION"
    echo "  debian_tools.sh  : $DEBIAN_TOOLS_VERSION"
}

update_module() {
    msg_info "Quel module voulez-vous mettre à jour ?"
    echo "1) utils.sh"
    echo "2) conf.sh"
    echo "3) docker.sh"
    echo "4) menu.sh"
    echo "5) debian_tools.sh"
    read -p "Votre choix : " CHOIX
    case "$CHOIX" in
        1) MODULE="utils.sh"; LOCAL_VERSION="$UTILS_VERSION" ;;
        2) MODULE="conf.sh"; LOCAL_VERSION="$CONF_VERSION" ;;
        3) MODULE="docker.sh"; LOCAL_VERSION="$DOCKER_VERSION" ;;
        4) MODULE="menu.sh"; LOCAL_VERSION="$MENU_VERSION" ;;
        5) MODULE="debian_tools.sh"; LOCAL_VERSION="$DEBIAN_TOOLS_VERSION" ;;
        *) msg_error "Choix invalide."; return ;;
    esac
    local branch
    branch=$(get_github_branch)
    REMOTE_VERSION=$(get_remote_module_version "$MODULE")
    if [[ -z "$REMOTE_VERSION" ]]; then
        msg_warn "Impossible de récupérer la version distante de $MODULE."
    elif [[ "$LOCAL_VERSION" == "$REMOTE_VERSION" ]]; then
        msg_success "$MODULE est déjà à jour (v$LOCAL_VERSION)."
    else
        msg_info "Mise à jour de $MODULE (local: $LOCAL_VERSION → distant: $REMOTE_VERSION)..."
        if curl -fsSL -o "lib/$MODULE" "https://raw.githubusercontent.com/tarekounet/Wireguard-easy-script/$branch/lib/$MODULE"; then
            msg_success "$MODULE mis à jour en $REMOTE_VERSION !"
            msg_warn "Relancez le script pour recharger le module mis à jour."
        else
            msg_error "Échec de la mise à jour de $MODULE."
        fi
    fi
}

get_remote_module_version() {
    local module="$1"
    local branch
    branch=$(get_github_branch)
    curl -fsSL "https://raw.githubusercontent.com/tarekounet/Wireguard-easy-script/$branch/lib/$module" | grep -m1 -E 'VERSION="?([0-9.]+)"?' | grep -oE '[0-9]+\.[0-9.]+'
}
show_modules_versions() {
    msg_info "Versions des modules chargés :"
    for mod in utils conf docker menu debian_tools; do
        local_var=$(echo "${mod^^}_VERSION")
        local_version="${!local_var}"
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
}

get_github_branch() {
    # Utilise la variable globale SCRIPT_CHANNEL
    if [[ "$SCRIPT_CHANNEL" == "beta" ]]; then
        echo "beta"
    else
        echo "main"
    fi
}

check_updates() {
    MODULE_UPDATE_AVAILABLE=0
    SCRIPT_UPDATE_AVAILABLE=0

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
    local branch
    branch=$(get_github_branch)
    remote_script_version=$(curl -fsSL "https://raw.githubusercontent.com/tarekounet/Wireguard-easy-script/$branch/config_wg.sh" | grep -m1 -E 'SCRIPT_BASE_VERSION_INIT="?([0-9.]+)"?' | grep -oE '[0-9]+\.[0-9.]+')
    if [[ -n "$remote_script_version" && "$SCRIPT_BASE_VERSION_INIT" != "$remote_script_version" ]]; then
        SCRIPT_UPDATE_AVAILABLE=1
    fi
}