# Changelog
Toutes les modifications notables de ce projet seront documentées ici.

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