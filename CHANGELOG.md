# 📦 Wireguard Easy Script

### [0.18.0] - 2025-08-13


#### 🔄 Modifié
- restructure le menu admin

### [0.17.0] - 2025-08-12


#### 🔄 Modifié
- modif de du menu gestion utilisateur

### [0.16.0] - 2025-08-11


#### 🔄 Modifié
- suppression de l'upgrade en debian 13

### [0.15.3] - 2025-08-11


#### 🐛 Corrigé
- impossible de lancer le script admin si il n'y a pas internet.

### [0.15.2] - 2025-08-07


#### 🐛 Corrigé
- correction le la remonté d'info version docker

### [0.15.1] - 2025-08-07


#### 🐛 Corrigé
- remonté d'information de la version du container

### [0.15.0] - 2025-08-07


#### 🔄 Modifié
- modification des couleur du menu
- optimisation du scrit
- suppression du fichier de conf et du mot de passe technique

### [0.14.2] - 2025-08-07


#### 🐛 Corrigé
- Dans le script admin correction de l'arrêt service SSH au lieu de fermer juste la session.

### [0.14.1] – 2025-08-06


#### 🐛 Corrigé
- correction pour l'exécution
- upgrade distri

### [0.14.0] – 2025-08-06


#### 🔄 Modifié
- modification de la configuration du docker
- ajout de l'afficher de l'url pour ce conneter sur l'interface
- modification des infos du script dans le menu
- déplacement de la version du container dans > etat du service wireguad

#### 🐛 Corrigé
- bug pour la mise a jour du script admin

### [0.13.0] – 2025-08-06


#### 🔄 Modifié
- armonisation de la gestion des versions entre le script principale et admin

### [0.12.0] – 2025-08-06


#### 🔄 Modifié
- Optimisation général du script et des modules
- suppresion des logs

#### 🐛 Corrigé
- erreur de permision

### [0.11.2] – 2025-08-05


#### 🐛 Corrigé
- docker permission

### [0.11.1] – 2025-08-05


#### 🐛 Corrigé
- Erreur pendant le processus de mise à jour.

### [0.11.0] – 2025-08-05

#### ✅ Ajouté
- ajout des logs pour les erreur

#### 🐛 Corrigé
- la remonté de l'etat du container déjà installé

### [0.10.0] – 2025-08-05

#### ✅ Ajouté
- test
- test

#### 🔄 Modifié
- test

#### 🐛 Corrigé
- test

### [0.9.0] – 2025-08-05

#### ✅ Ajouté
- Refonte visuelle du script principal
- Déplacement de certaines fonctions vers le script admin

#### 🔄 Modifié
- Système de mise à jour à chaque lancement
- Structure du menu admin

---

### [0.4.1] – 2025-05-31

#### ✅ Ajouté
- Modification des valeurs réseau : IP, masque, passerelle, DNS
- Extinction et redémarrage de la VM (mot de passe requis)
- Demande du mot de passe technique au premier lancement

#### 🔄 Modifié
- Détection DHCP/Static pour proposer le changement de mode
- Optimisation des performances

---

### [0.3.1] – 2025-05-31

#### ✅ Ajouté
- Switch entre version stable et beta
- Passage vers beta uniquement si version supérieure
- Retour automatique vers stable si nécessaire
- Fichier de configuration pour mémoriser les infos essentielles

#### 🔄 Modifié
- Refonte visuelle du script
- Optimisation des performances

#### 🐛 Corrigé
- Affichage du fichier changelog
- Erreurs liées au changement de canal
- Amélioration des infos de mise à jour

---

### [0.2.0] – 2025-05-30

#### ✅ Ajouté
- Menu VM Debian : disque, moniteur système (btop), terminal
- Implémentation du changelog dans le script

#### 🔄 Modifié
- Visuel du script
- Menu VM
- Restructuration générale

---

### [0.1.1] – 2025-05-29

#### ✅ Ajouté
- Menu VM Debian : IP, hostname, port SSH, mise à jour OS

#### 🐛 Corrigé
- Bug du double `$` dans la création du mot de passe Docker

---

### [0.1.0] – 2025-05-19

#### ✅ Ajouté
- Première version du projet
- Fonctionnalités de base

## 📌 Présentation générale

Ce script Bash permet de gérer un serveur WireGuard avec Docker Compose, facilement et en toute sécurité.  
Il propose une interface en ligne de commande colorée, des sauvegardes automatiques, la gestion du mot de passe technique, et la mise à jour automatique du script et de ses modules.
---
