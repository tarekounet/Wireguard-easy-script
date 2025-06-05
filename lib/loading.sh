#!/bin/bash

##############################
#        VERSION MODULE      #
##############################

loading_VERSION="1.0.0"

##############################
#           LOADING          #
##############################

# # Fonction pour obtenir la taille de l'écran
function get_screen_size() {
    cols=$(tput cols)
    rows=$(tput lines)
    echo "$cols $rows"
}

# # Fonction pour afficher une image ASCII avec une barre de chargement dynamique
function fake_loading_with_ascii() {
    # Palette de couleurs ANSI pour le dégradé rouge
    local colors=(31 91 91 31 91 31 91 31 91 31 91 31)
    local color_index=0
    local color_count=${#colors[@]}

    # Image ASCII
    local ascii_art="
=============================================================

        .__                                             .___
__  _  _|__|______   ____   ____  __ _______ _______  __| _/
\ \/ \/ /  \_  __ \_/ __ \ / ___\|  |  \__  \_  __  \/ __ |
 \     /|  ||  | \/\  ___// /_/  >  |  // __ \|  | \/ /_/ |
  \/\_/ |__||__|    \___  >___  /|____/(____  /__|  \____ |
                        \/_____/            \/           \/

==================== Easy Script Manager ===================

"

    clear
    local line_num=0
    while IFS= read -r line; do
        read -r cols rows <<< "$(get_screen_size)"
        if [[ $line_num -eq 0 || $line =~ ^=+$ ]]; then
            printf "\033[90m%*s\033[0m\n" $(( (cols + ${#line}) / 2 )) "$line"
        elif [[ $line =~ "Easy Script Manager" ]]; then
            printf "\033[97m%*s\033[0m\n" $(( (cols + ${#line}) / 2 )) "$line"
        else
            printf "\033[%sm%*s\033[0m\n" "${colors[color_index]}" $(( (cols + ${#line}) / 2 )) "$line"
            color_index=$(( (color_index + 1) % color_count ))
        fi
        line_num=$((line_num + 1))
    done <<< "$ascii_art"

    # Modules à charger
    local modules=("menu" "config" "debian_tools" "utils" "docker")

    # Barre de chargement dynamique avec couleur verte
    echo -e "\033[32mChargement en cours...\033[0m"
    local floppy_icons=("💾" " " "💾" " ")
    local floppy_count=${#floppy_icons[@]}

    read -r cols rows <<< "$(get_screen_size)"   # Taille fixée une fois

    # Largeur fixe pour la barre de progression
    local bar_width=40

    for i in "${!modules[@]}"; do
        local progress=$(( (i + 1) * bar_width / ${#modules[@]} ))
        local percent=$(( (progress * 100) / bar_width ))
        local filled=$(printf "%*s" "$progress" "" | tr ' ' '=')
        local arrow="➤"
        local empty=$(printf "%*s" "$((bar_width - progress - 1))" "" | tr ' ' '-')
        local floppy="${floppy_icons[$((i % floppy_count))]}"

        printf "\033[1;36m%s\033[0m\n" "${modules[i]}"
        printf "\033[92m[%s%s%s] %3d%%\033[0m \033[95m%s\033[0m\r" \
            "$filled" "$arrow" "$empty" "$percent" "$floppy"

        sleep $(awk "BEGIN {print ($RANDOM % 2) * 0.5 + 1}")
        printf "\033[1A"
    done
    sleep 1
}


# Appeler la fonction de chargement
fake_loading_with_ascii