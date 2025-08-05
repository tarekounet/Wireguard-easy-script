#!/bin/bash
##############################
#      CONSTANTES            #
##############################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF_FILE="$SCRIPT_DIR/config/wg-easy.conf"
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
    local PASS1 PASS2 HASH SALT
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
            # Générer un sel aléatoire
            SALT=$(head -c 8 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 8)
            HASH=$(openssl passwd -6 -salt "$SALT" "$PASS1")
            set_conf_value "EXPECTED_HASH" "$HASH"
            set_conf_value "HASH_SALT" "$SALT"
            msg_success "Mot de passe technique enregistré avec succès."
            break
        fi
    done
}

ask_tech_password() {
    local EXPECTED_HASH HASH_SALT
    EXPECTED_HASH=$(get_conf_value "EXPECTED_HASH")
    HASH_SALT=$(get_conf_value "HASH_SALT")
    if [[ -z "$EXPECTED_HASH" || -z "$HASH_SALT" ]]; then
        msg_error "Le mot de passe technique ou le sel est introuvable dans le fichier de configuration."
        return 1
    fi
    read -sp $'\e[1;33mEntrez le mot de passe technique : \e[0m' PASS
    echo
    local ENTERED_HASH
    ENTERED_HASH=$(openssl passwd -6 -salt "$HASH_SALT" "$PASS")
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
