##############################
#        VERSION MODULE      #
##############################

CONF_VERSION="1.0.0"

##############################
#      CONSTANTES            #
##############################

# Le chemin du fichier de configuration principal
CONF_FILE="wg-easy.conf"

##############################
#   GESTION DE LA CONF       #
##############################

set_conf_value() {
    local key="$1"
    local value="$2"
    if grep -q "^${key}=" "$CONF_FILE"; then
        sed -i "s|^${key}=.*|${key}=\"${value}\"|" "$CONF_FILE"
    else
        echo "${key}=\"${value}\"" >> "$CONF_FILE"
    fi
}

get_conf_value() {
    local key="$1"
    grep "^${key}=" "$CONF_FILE" | cut -d '=' -f2- | tr -d '"'
}

##############################
#   GESTION DU MOT DE PASSE  #
##############################

set_tech_password() {
    local PASS1 PASS2 HASH
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
            HASH=$(openssl passwd -6 -salt Qw8n0Qw8 "$PASS1")
            set_conf_value "EXPECTED_HASH" "$HASH"
            msg_success "Mot de passe technique enregistré avec succès."
            log_action "Mot de passe technique modifié"
            break
        fi
    done
}

ask_tech_password() {
    local EXPECTED_HASH
    EXPECTED_HASH=$(get_conf_value "EXPECTED_HASH")
    if [[ -z "$EXPECTED_HASH" ]]; then
        msg_error "Le mot de passe technique est introuvable dans le fichier de configuration."
        return 1
    fi
    read -sp $'\e[1;33mEntrez le mot de passe technique : \e[0m' PASS
    echo
    local ENTERED_HASH
    ENTERED_HASH=$(openssl passwd -6 -salt Qw8n0Qw8 "$PASS")
    if [[ "$ENTERED_HASH" != "$EXPECTED_HASH" ]]; then
        msg_error "Mot de passe incorrect."
        return 1
    fi
    return 0
}

change_tech_password() {
    CURRENT_HASH=$(get_conf_value "EXPECTED_HASH")
    if [[ -n "$CURRENT_HASH" ]]; then
        read -sp $'\e[1;33mEntrez l\'ancien mot de passe technique : \e[0m' OLD_PASS
        echo
        ENTERED_HASH=$(openssl passwd -6 -salt Qw8n0Qw8 "$OLD_PASS")
        if [[ "$ENTERED_HASH" != "$CURRENT_HASH" ]]; then
            msg_error "Mot de passe incorrect."
            return
        fi
    fi
    set_tech_password
}