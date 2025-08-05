# Logs d'Erreur pour Wireguard Easy Script

## Fonction disponible

### Logs d'erreur uniquement
```bash
log_error "Message d'erreur"
log_error "Message d'erreur" false  # N'affiche pas sur la console
```

## Configuration

### Variables d'environnement
- `ERROR_LOG_TO_FILE=true` : Active l'écriture vers un fichier de log d'erreur
- `ERROR_LOG_FILE=/path/to/errors.log` : Spécifie le fichier de log (défaut: /tmp/wireguard-errors.log)
- `ERROR_LOG_MAX_SIZE=1048576` : Taille max du fichier avant rotation (défaut: 1MB)
- `DEBUG=1` : Active l'affichage des messages de debug dans la console

### Activation du logging d'erreur vers fichier
```bash
# Activer avec fichier par défaut
enable_error_logging

# Activer avec fichier spécifique
enable_error_logging "/var/log/wireguard-errors.log"

# Désactiver
disable_error_logging
```

## Exemples d'utilisation

### Avec logs d'erreur vers fichier
```bash
ERROR_LOG_TO_FILE=true ERROR_LOG_FILE="/tmp/wg-errors.log" ./config_wg.sh
```

### Debug console + logs d'erreur vers fichier
```bash
DEBUG=1 ERROR_LOG_TO_FILE=true ./config_wg.sh
```

### Voir seulement les erreurs
```bash
ERROR_LOG_TO_FILE=true ./config_wg.sh 2>&1 | grep -E "ERREUR"
```

## Format des logs

### Console
- `[ERREUR] Message` (en rouge sur stderr)

### Fichier
```
[2025-08-05 14:30:15] [ERROR] Message d'erreur
[2025-08-05 14:30:20] [ERROR] Autre erreur critique
```

## Rotation automatique

Le fichier de log est automatiquement renommé en `.old` quand il dépasse la taille configurée (1MB par défaut).

## Cas d'usage typiques

### Production - logs d'erreur vers fichier
```bash
ERROR_LOG_TO_FILE=true ERROR_LOG_FILE="/var/log/wireguard-errors.log" ./config_wg.sh
```

### Debug - console + fichier d'erreur
```bash
DEBUG=1 ERROR_LOG_TO_FILE=true ./config_wg.sh
```
