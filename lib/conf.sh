# Protection : ce module ne doit être chargé que par config_wg.sh

if [[ "$(basename -- "$0")" == "conf.sh" ]]; then
    echo -e "\e[1;31mCe module ne doit pas être lancé directement, mais via config_wg.sh !\e[0m"
    exit 1
fi
##############################
#      CONSTANTES            #
##############################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF_FILE="$SCRIPT_DIR/config/wg-easy.conf"
AUTH_LOG="$SCRIPT_DIR/logs/auth.log"

##############################
#        VERSION MODULE      #
##############################

CONF_VERSION="1.1.0"

##############################
#        LOGS CONF           #
##############################
log_config() {
    local msg="$1"
    echo "$(date '+%F %T') [CONFIG] $msg" >> "$CONFIG_LOG"
}

log_auth() {
    local msg="$1"
    echo "$(date '+%F %T') [AUTH] $msg" >> "$AUTH_LOG"
}

##############################
#   GESTION DE LA CONF       #
##############################

set_conf_value() {
    local key="$1"
    local value="$2"
    local conf_file="${CONF_FILE:-config/wg-easy.conf}"
    if grep -q "^${key}=" "$conf_file"; then
        sed -i "s|^${key}=.*|${key}=\"${value}\"|" "$conf_file"
    else
        echo "${key}=\"${value}\"" >> "$conf_file"
    fi
}

get_conf_value() {
    local key="$1"
    grep "^${key}=" "$CONF_FILE" 2>/dev/null | cut -d '=' -f2- | tr -d '"'
}

##############################
#   GESTION DU MOT DE PASSE  #
##############################

set_tech_password() {
    local PASS1 PASS2 HASH SALT
    SALT=$(openssl rand -hex 8)
    while true; do
        read -sp "Entrez le nouveau mot de passe technique : " PASS1
        echo
        read -sp "Confirmez le nouveau mot de passe technique : " PASS2
        echo
        if [[ -z "$PASS1" ]]; then
            msg_error "Le mot de passe ne peut pas être vide."
        elif [[ "$PASS1" != "$PASS2" ]]; then
            msg_error "Les mots de passe ne correspondent pas."
        else
            HASH=$(openssl passwd -6 -salt "$SALT" "$PASS1")
            set_conf_value "EXPECTED_HASH" "$HASH"
            set_conf_value "TECH_SALT" "$SALT"
            msg_success "Mot de passe technique enregistré avec succès."
            log_action "Mot de passe technique modifié"
            break
        fi
    done
}

ask_tech_password() {
    local EXPECTED_HASH SALT
    EXPECTED_HASH=$(get_conf_value "EXPECTED_HASH")
    SALT=$(get_conf_value "TECH_SALT")
    if [[ -z "$EXPECTED_HASH" || -z "$SALT" ]]; then
        msg_error "Le mot de passe technique ou le sel est introuvable dans le fichier de configuration."
        log_auth "Échec : hash attendu ou sel introuvable"
        return 1
    fi
    read -sp $'\e[1;33mEntrez le mot de passe technique : \e[0m' PASS
    echo
    local ENTERED_HASH
    ENTERED_HASH=$(openssl passwd -6 -salt "$SALT" "$PASS")
    if [[ "$ENTERED_HASH" != "$EXPECTED_HASH" ]]; then
        msg_error "Mot de passe incorrect."
        log_auth "Échec : mot de passe incorrect"
        return 1
    fi
    log_auth "Succès : authentification réussie"
    return 0
}

change_tech_password() {
    CURRENT_HASH=$(get_conf_value "EXPECTED_HASH")
    SALT=$(get_conf_value "TECH_SALT")
    if [[ -n "$CURRENT_HASH" && -n "$SALT" ]]; then
        read -sp $'\e[1;33mEntrez l\'ancien mot de passe technique : \e[0m' OLD_PASS
        echo
        ENTERED_HASH=$(openssl passwd -6 -salt "$SALT" "$OLD_PASS")
        if [[ "$ENTERED_HASH" != "$CURRENT_HASH" ]]; then
            msg_error "Mot de passe incorrect."
            return
        fi
    fi
    set_tech_password
}

init_tech_password() {
    local EXPECTED_HASH
    EXPECTED_HASH=$(get_conf_value "EXPECTED_HASH")
    while [[ -z "$EXPECTED_HASH" ]]; do
        msg_warn "Aucun mot de passe technique enregistré. Veuillez en définir un."
        set_tech_password
        EXPECTED_HASH=$(get_conf_value "EXPECTED_HASH")
    done
}
