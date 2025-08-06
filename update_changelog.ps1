# ===============================
# 📦 WireGuard Easy – Changelog Generator
# ===============================

function Get-LastVersion {
    $changelogPath = "CHANGELOG.md"
    if (-not (Test-Path $changelogPath)) {
        return "0.0.0"
    }

    $content = Get-Content $changelogPath
    foreach ($line in $content) {
        if ($line -match '### \[(\d+\.\d+\.\d+)\]') {
            return $matches[1]
        }
    }

    return "0.0.0"
}

function Update-Version {
    param (
        [string]$currentVersion,
        [ValidateSet("major", "minor", "patch")]
        [string]$type
    )

    $parts = $currentVersion -replace '[^\d.]', '' -split '\.'
    $major = [int]$parts[0]
    $minor = [int]$parts[1]
    $patch = [int]$parts[2]

    switch ($type) {
        "major" {
            $major++
            $minor = 0
            $patch = 0
        }
        "minor" {
            $minor++
            $patch = 0
        }
        "patch" {
            $patch++
        }
    }

    return "$major.$minor.$patch"
}

function Add-ChangelogSmart {
    $changelogPath = "CHANGELOG.md"
    $date = Get-Date -Format "yyyy-MM-dd"
    $lastVersion = Get-LastVersion

    Write-Host "📌 Dernière version : $lastVersion"

    # Collecte des entrées
    $added = @()
    $modified = @()
    $fixed = @()

    Write-Host "`n✅ Ajouté (ENTER vide pour finir)"
    while ($true) {
        $line = Read-Host "➕"
        if ([string]::IsNullOrWhiteSpace($line)) { break }
        $added += "- $line"
    }

    Write-Host "`n🔄 Modifié (ENTER vide pour finir)"
    while ($true) {
        $line = Read-Host "🔧"
        if ([string]::IsNullOrWhiteSpace($line)) { break }
        $modified += "- $line"
    }

    Write-Host "`n🐛 Corrigé (ENTER vide pour finir)"
    while ($true) {
        $line = Read-Host "🩹"
        if ([string]::IsNullOrWhiteSpace($line)) { break }
        $fixed += "- $line"
    }

    # Détection du type d'incrément
    if ($added.Count -gt 0 -and ($added -match "structure|refonte|majeure")) {
        $type = "major"
    } elseif ($added.Count -gt 0 -or $modified.Count -gt 0) {
        $type = "minor"
    } elseif ($fixed.Count -gt 0) {
        $type = "patch"
    } else {
        Write-Host "❌ Aucun changement détecté. Abandon." -ForegroundColor Red
        return
    }

    # Détection version pré-1.0 et proposition de passage en stable
    if ($lastVersion -match '^0\.') {
        Write-Host "`n🚧 Version de développement détectée : $lastVersion" -ForegroundColor Yellow
        Write-Host "🎯 Le script va calculer automatiquement : $(Update-Version -currentVersion $lastVersion -type $type)" -ForegroundColor Cyan
        
        $goStable = Read-Host "`n🎉 Voulez-vous plutôt passer directement en version stable 1.0.0 ? (o/N)"
        if ($goStable -match '^[oO]$') {
            $newVersion = "1.0.0"
            Write-Host "`n🎊 Passage en version stable : 1.0.0 !" -ForegroundColor Green
            Write-Host "🏆 Félicitations pour la sortie officielle de votre projet !" -ForegroundColor Green
        } else {
            $newVersion = Update-Version -currentVersion $lastVersion -type $type
            Write-Host "`n🆕 Nouvelle version détectée : $newVersion ($type)" -ForegroundColor Cyan
        }
    } else {
        $newVersion = Update-Version -currentVersion $lastVersion -type $type
        Write-Host "`n🆕 Nouvelle version détectée : $newVersion ($type)" -ForegroundColor Cyan
    }

    # Création du fichier si nécessaire
    if (-not (Test-Path $changelogPath)) {
        New-Item -Path $changelogPath -ItemType File -Force | Out-Null
        Add-Content $changelogPath "# 📦 WireGuard Easy Script – Changelog`n"
    }

    # Lecture du contenu existant
    $existingContent = Get-Content $changelogPath

    # Préparation du nouveau contenu
    $newEntry = @()
    $newEntry += "`n### [$newVersion] - $date`n"

    if ($added.Count -gt 0) {
        $newEntry += "#### ✅ Ajouté"
        $added | ForEach-Object { $newEntry += $_ }
    }

    if ($modified.Count -gt 0) {
        $newEntry += "`n#### 🔄 Modifié"
        $modified | ForEach-Object { $newEntry += $_ }
    }

    if ($fixed.Count -gt 0) {
        $newEntry += "`n#### 🐛 Corrigé"
        $fixed | ForEach-Object { $newEntry += $_ }
    }

    # Recherche de la position d'insertion (après le titre principal)
    $insertIndex = 0
    for ($i = 0; $i -lt $existingContent.Length; $i++) {
        if ($existingContent[$i] -match '^# ') {
            $insertIndex = $i + 1
            break
        }
    }

    # Reconstruction du fichier avec la nouvelle entrée en haut
    $newContent = @()
    $newContent += $existingContent[0..($insertIndex-1)]
    $newContent += $newEntry
    $newContent += $existingContent[$insertIndex..($existingContent.Length-1)]

    # Écriture du nouveau contenu
    $newContent | Set-Content $changelogPath

    # Mise à jour du fichier version.txt
    $newVersion | Set-Content "version.txt"

    # Mise à jour de admin_menu.sh
    if (Test-Path "admin_menu.sh") {
        $adminContent = Get-Content "admin_menu.sh"
        $updated = $false
        
        for ($i = 0; $i -lt $adminContent.Length; $i++) {
            # Mise à jour de la ligne de version dans les commentaires
            if ($adminContent[$i] -match '^# Version: \d+\.\d+\.\d+') {
                $adminContent[$i] = "# Version: $newVersion"
                $updated = $true
            }
            # Mise à jour de la variable DEFAULT_VERSION
            elseif ($adminContent[$i] -match '^readonly DEFAULT_VERSION="[^"]*"') {
                $adminContent[$i] = 'readonly DEFAULT_VERSION="' + $newVersion + '"'
                $updated = $true
            }
        }
        
        if ($updated) {
            $adminContent | Set-Content "admin_menu.sh"
            Write-Host "📝 Fichier admin_menu.sh mis à jour" -ForegroundColor Green
        }
    }

    # Mise à jour de config_wg.sh
    if (Test-Path "config_wg.sh") {
        $configContent = Get-Content "config_wg.sh"
        $updated = $false
        
        for ($i = 0; $i -lt $configContent.Length; $i++) {
            # Mise à jour de la variable DEFAULT_VERSION
            if ($configContent[$i] -match '^readonly DEFAULT_VERSION="[^"]*"') {
                $configContent[$i] = 'readonly DEFAULT_VERSION="' + $newVersion + '"'
                $updated = $true
                break
            }
        }
        
        if ($updated) {
            $configContent | Set-Content "config_wg.sh"
            Write-Host "📝 Fichier config_wg.sh mis à jour" -ForegroundColor Green
        }
    }

    Write-Host "`n✅ Changelog mis à jour avec la version $newVersion !" -ForegroundColor Green
    Write-Host "📝 Fichier version.txt également mis à jour" -ForegroundColor Green
    
    # Pause pour laisser le temps de lire
    Write-Host "`n🔄 Appuyez sur une touche pour continuer..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Show-Menu {
    Clear-Host
    
    # Récupération des informations
    $currentVersion = Get-LastVersion
    $versionFile = if (Test-Path "version.txt") { Get-Content "version.txt" -First 1 } else { "Non trouvé" }
    $changelogExists = Test-Path "CHANGELOG.md"
    $lastModified = if ($changelogExists) { (Get-Item "CHANGELOG.md").LastWriteTime.ToString("dd/MM/yyyy HH:mm") } else { "N/A" }
    
    Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║          📦 WireGuard Easy – Générateur de Changelog      ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    # Informations du projet
    Write-Host "📊 Informations du projet :" -ForegroundColor Yellow
    Write-Host "   🏷️  Version actuelle (CHANGELOG) : $currentVersion" -ForegroundColor White
    Write-Host "   📄 Version (version.txt)        : $versionFile" -ForegroundColor White
    Write-Host "   📅 Dernière modification        : $lastModified" -ForegroundColor White
    Write-Host "   📋 Fichier CHANGELOG.md         : $(if ($changelogExists) { "✅ Présent" } else { "❌ Absent" })" -ForegroundColor White
    Write-Host ""
    
    # Règles de versioning
    Write-Host "📐 Règles de versioning automatique :" -ForegroundColor Magenta
    Write-Host "   🔴 MAJOR : Ajouts avec mots-clés 'structure|refonte|majeure'" -ForegroundColor Red
    Write-Host "   🟡 MINOR : Ajouts ou modifications (nouvelles fonctionnalités)" -ForegroundColor Yellow
    Write-Host "   🟢 PATCH : Corrections de bugs uniquement" -ForegroundColor Green
    if ($currentVersion -match '^0\.') {
        Write-Host "   🎉 STABLE: Option spéciale 0.xx.xx → 1.0.0 (passage en stable)" -ForegroundColor Magenta
    }
    Write-Host ""
    
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "1. 📝 Ajouter une entrée avec détection intelligente"
    Write-Host "0. 🚪 Quitter"
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
}

do {
    Show-Menu
    $choice = Read-Host "Choix"

    switch ($choice) {
        "1" { Add-ChangelogSmart }
        "0" { Write-Host "👋 À bientôt, Tarek !" }
        default { Write-Host "❌ Choix invalide. Réessaie." }
    }
} while ($choice -ne "0")