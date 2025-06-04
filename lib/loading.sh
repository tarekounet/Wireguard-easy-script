#!/bin/bash

# Fonction pour obtenir la taille de l'écran
function get_screen_size() {
    cols=$(tput cols)
    rows=$(tput lines)
    echo "$cols $rows"
}

# Fonction pour afficher une image ASCII avec une barre de chargement dynamique
function fake_loading_with_ascii() {
    local cols rows
    read -r cols rows <<< "$(get_screen_size)"

    # Image ASCII (modifiez selon vos besoins)
    local ascii_art="                                                                                                                                                                                                                                             
                                                              ░░░░░                                                          
                                                     ░▒▓▓████▓▒▒░▒▓▓██▓▒                                                     
                                                  ░▒██████▒░▒▒░     ░▓█▓██▒                                                  
                                                ░█████▓███▓              ███▓                                                
                                               ▓█████▓▓▓█▓░      ░▒▒▒▒░▒██████▒                                              
                                              ████▓▓▓▓▓██▒░▒     ░████████▓▓▓██▓                                             
                                             ███▓▓▓▓▓▓███████▓▒     ▒████▓▓▓▓▓███                                            
                                            ██▓▓▓▓▓▓▓████▓▒▒▒▓▓▓▒     ▒███▓▓▓▓▓██▓                                           
                                           ▒██▓▓▓▓▓▓███░        ░▒▒     ███▓▓▓▓▓██░                                          
                                           ███▓▓▓▓▓██▒            ░▓    ▒█▓▓▓▓▓▓▓█▓                                          
                                          ░██▓▓▓▓▓██▓     ▒▓▓▓▒    ░▒   ░██▓▓▓▓▓███                                          
                                          ▒█▓▓▓▓▓▓██     ██████▓   ▒░   ▒█▓▓▓▓▓▓▓██                                          
                                          ▓██▓▓▓▓▓██    ░███████  ▒▒    ██▓▓▓▓▓▓▓██                                          
                                          ▓█▓▓▓▓▓▓▓█▒    ▒█████▒░▒░    ▓██▓▓▓▓▓▓▓██                                          
                                          ▒██▓▓▓▓▓███      ░▒░       ▒███▓▓▓▓▓▓▓▓██                                          
                                          ░██▓▓▓▓▓▓███▓  ▒░        ░░▒███▓▓▓▓▓▓▓▓█▓                                          
                                           ██▓▓▓█▓███▓▓▒▓      ░▒▒     ▒██▓▓▓▓▓▓██▒                                          
                                           ▒██▓▓▓██▒   ▒     ▓████▒     ▓█▓▓▓▓▓███                                           
                                            ███▓██░   ▒▒    ████████    ░██▓▓▓███                                            
                                             █████▒▓███░   ░████▓███    ░█▓▓▓███░                                            
                                              ▓████████▒    ▒██████▒    ▒██▓███                                              
                                               ░████████░     ░▒▒░     ░█████▒                                               
                                                 ░▓██████▒            ▓███▓▒                                                 
                                                    ░▒▓████▓░      ▒▓██▓░                                                    
                                                           ▒▒▒▒▒░░░░░                                                        
 █▓       ░█▓       ▒█░                                   ▒▓█████▓░                                                          
 ▒█▒      ███░      ██                                  ██▓░    ░▓██▒                                                      ░ 
  ██     ▒█░██     ▒█ ▒█   ▓▓▓▓█▓█▓█▓▒   ▒▓▓▓███████▓ ░██          ▓▒  ▒█▒        ▓▓     ░█░     ░▓▓▓▓▓█▓█▓▓▒   ▒▓▓█▓██▓▒░ ▒ 
  ░█▒    █▓ ░█▒    █▓ ▓█░  ██░░░░░░░▒██░ ▒█▒░░░░░░░▒░ ██               ▒█▒        ██     ███     ░█▓░░░░░░░▒██  ▓█▒░▒░▒▒▓██  
   ▓█   ▓█   ██   ▓█  ▓█   █▓        ▒█▒ ▒█           █▓       ▓▓▓▒▒▒  ▒█▒        █▓    ██ ██    ░█▒        ▒█░ ▓█        ██ 
    █▒  █▒   ░█▒  █▒  ▓█   ██▓▓▓▓▓▓▓▓█▓  ▒███████▓    █▓       ▓▓▓▒██░ ░█▒        █▓   ██   ██    ██▓▓▓▓▓▓▓▓█▒  ▓█        ░█▒
    ▒█ ▓█     ▓█ ▓█   ▓█   ██░░▒▒░▒██    ▒█░          ▓█░          ▒█░ ▒█▒        █▓  ▓█▒░░░▒█▓   █▓░░▒▒░▓█▓    ▓█        ▒█░
     ███▒      ███░   ▓█   █▓      ░█▒   ▒█            ██▒        ░██  ░█▒        █▓ ▒█▒▒▓▓▓▒▒█▓  █▒      ▒█▒   ▓█       ░██ 
     ▒██       ▒█▓    ▓█   ██        ██  ▒█▓▒▓▓▓▓▓▓▓▓▒  ▒██▓▒▒▒▒▓██▒    ▓█▓▒▒▒▒▒▒██ ▒█░       ░█▒ █▓       ░█▓  ▓█▒▓▓▓▓▓██▒                                                                                                                                                                                                                                                    "
    
    # Centrer l'image ASCII ligne par ligne
    clear
    while IFS= read -r line; do
        printf "%*s\n" $(( (cols + ${#line}) / 2 )) "$line"
    done <<< "$ascii_art"

    # Palette de couleurs ANSI pour le dégradé (exemple du rouge vers le jaune)
    local colors=(31 91 31 91 31 91 31 91 31 91 31 91)  # Tu peux ajuster la palette

    clear
    local color_index=0
    local color_count=${#colors[@]}
    while IFS= read -r line; do
        # Applique la couleur du dégradé à chaque ligne
        printf "\033[%sm%*s\033[0m\n" "${colors[color_index]}" $(( (cols + ${#line}) / 2 )) "$line"
        color_index=$(( (color_index + 1) % color_count ))
    done <<< "$ascii_art"

    # Modules à charger
    local modules=("Module 1" "Module 2" "Module 3" "Module 4" "Vérification des prérequis")

    # Barre de chargement dynamique avec couleur verte
    echo -e "\033[32mChargement en cours...\033[0m"
    for i in "${!modules[@]}"; do
        if command -v tput &>/dev/null; then
            tput cuu1 2>/dev/null
        fi
        echo -e "\033[5;36m${modules[i]}\033[0m"
        local progress=$(( (i + 1) * cols / ${#modules[@]} ))
        printf -v bar "%*s" "$cols" ""
        bar=${bar// /▓}
        echo -ne "\033[91m${bar:0:$progress}\033[0m\r"
        sleep $((RANDOM % 3 + 1))  # Entre 1 et 3 secondes
    done
    echo -e "\n\033[32mChargement terminé !\033[0m"

    # Pause pour appuyer sur une touche
    echo "Appuyez sur une touche pour continuer..."
    read -n 1 -s
}

# Appeler la fonction de chargement
fake_loading_with_ascii