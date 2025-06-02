# Wireguard Easy Script

## 📌 Présentation générale

Ce script Bash permet de gérer un serveur WireGuard avec Docker Compose, facilement et en toute sécurité.  
Il propose une interface en ligne de commande colorée, des sauvegardes automatiques, la gestion du mot de passe technique, et la mise à jour automatique du script et de ses modules.

---

## 🏗️ Nouvelle structure (v1.5.0)

- **Script principal** : `config_wg.sh`
    - C’est le point d’entrée. Il vérifie et télécharge automatiquement les modules nécessaires depuis GitHub si besoin.
    - Il gère le choix du canal (stable/beta) et charge tous les modules du dossier `lib/`.

- **Modules dans `lib/`** :
    - `utils.sh` : Fonctions utilitaires (affichage, validation, logs, gestion des versions…)
    - `conf.sh` : Fonctions pour la gestion de la configuration et du mot de passe technique
    - `docker.sh` : Fonctions pour la configuration et la gestion de Wireguard via Docker
    - `menu.sh` : Affichage du menu principal et gestion des actions utilisateur
    - `debian_tools.sh` : Outils système pour Debian/Linux

---

## 🚀 Fonctionnalités principales

- **Auto-bootstrap** : Si tu copies juste `config_wg.sh`, il télécharge tout seul les modules manquants.
- **Gestion des mises à jour** :
    - Le script et chaque module vérifient s’il existe une nouvelle version sur GitHub.
    - Si une mise à jour est dispo (script ou module), le menu affiche un bouton clignotant pour prévenir l’utilisateur.
- **Canal stable/beta** : Tu peux choisir d’utiliser la version stable ou beta du script et des modules.
- **Menu interactif** : Toutes les actions (config, démarrage, arrêt, mise à jour…) sont accessibles via un menu coloré et simple.
- **Sécurité** : Gestion du mot de passe technique, sauvegarde/restauration automatique de la configuration.
- **Configuration facile** : Modification des ports, de l’adresse publique, du mot de passe, etc., via des questions simples.

---

## 📝 Exemple d’utilisation

1. **Premier lancement** :  
   - Le script crée le dossier `lib/` et télécharge les modules si besoin.
   - Il vérifie les dépendances et la configuration.
2. **Utilisation** :  
   - L’utilisateur navigue dans le menu pour configurer, démarrer ou mettre à jour Wireguard.
   - Les modules sont chargés dynamiquement.
3. **Mise à jour** :  
   - Si une nouvelle version du script ou d’un module est dispo, le menu le signale.
   - L’utilisateur peut mettre à jour en un clic, sans rien télécharger manuellement.

---

## 🆕 Historique des changements

- **v1.5.0**  
    - Passage à une structure modulaire (`lib/`).
    - Téléchargement automatique des modules manquants.
    - Vérification et affichage des mises à jour (script et modules).
    - Gestion du canal stable/beta.
    - Séparation claire des fonctions (utilitaires, config, docker, menu, outils système).
    - Menu interactif amélioré avec couleurs et emojis.

---

**Ce script est maintenant plus facile à maintenir, à mettre à jour et à utiliser, même si tu ne copies que le script principal !**
## [1.4.0] - 2025-05-31
### Ajouté

### Modifié

### Corrigé
- mot de passe technique non gardé
## [1.4.0] - 2025-06-01
### Ajouté
- Possibilité de modifier les différentes valeur du port ethernet.
    IP, Masque, Passerelle, DNS
- On peut eteindre et redémarrer la vm.
    le mot de passe technique sera demandé
- Au premier lancement un mot de passe technique sera demander.

### Modifié
- Detection si la carte est en DHCP ou Static pour proposer le choix de changer de mode.
- Optimisation du script pour de meilleures performances.

### Corrigé

## [1.3.3] - 2025-05-31
### Ajouté
- Possibilité de switcher 🔁 entre une version stable et beta du script.
- Passage de stable → beta uniquement si la version beta est supérieure, sinon ⛔.
- Si la version stable est supérieure à la beta, retour automatique sur la branche principale.
- Intégration d'un fichier de configuration pour mémoriser des informations essentielles.


### Modifié
- Refonte visuelle du script général.
- Optimisation du script pour de meilleures performances.

### Corrigé
- Correction de l'affichage du fichier CHANGELOG.
- Correction des erreurs liées au changement de canal.
- Amélioration de la remontée d'informations sur les mises à jour dans chaque canal respectif.


## [1.2.0] - 2025-05-30
### Ajouté
- Ajout dans menu pour gérer la vm debian :
    - affichage de la taille du disque de la vm utilisé
    - Moniteur système (btop)
    - terminal dans le script
- Implémentation du fichier du changelog dans le script

### Modifié
- Modification visuelle du script général
- Modification du menu pour la gestion de la VM
- Restructuration du script

### Corrigé


## [1.1.1] - 2025-05-29
### Ajouté
- Ajout du menu pour gérer la vm debian :
    - IP, hostname, port ssh, mise à jour OS.

### Modifié


### Corrigé
- Correction d'un bug pour le double $$ dans la création du mot de passe dans docker-compose.



## [1.0.0] - 2025-05-19
### Ajouté
- Première version du projet.
- Fonctionnalités de base implémentées.