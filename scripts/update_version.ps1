$Fichier = "config_wg.sh"
$VersionFile = "version.txt"
$LogFile = "versions.log"

# Lire la version actuelle
$VersionActuelle = Get-Content $VersionFile

# Vérifier si le fichier a été modifié
$Modifications = git diff --quiet $Fichier

if ($Modifications -eq $null) {
    Write-Output "Aucune modification détectée. Version conservée : $VersionActuelle"
    exit 0
} else {
    # Incrémenter la version
    $NouvelleVersion = ($VersionActuelle -replace "\d+$", { [int]$_ + 1 })
    Set-Content $VersionFile $NouvelleVersion

    # Mettre à jour la version dans le script
    (Get-Content $Fichier) -replace "^# Version:.*", "# Version: $NouvelleVersion" | Set-Content $Fichier

    # Enregistrer l'historique des versions
    Add-Content $LogFile "$(Get-Date) - Version mise à jour : $NouvelleVersion"

    Write-Output "✅ Mise à jour effectuée : nouvelle version $NouvelleVersion"
}