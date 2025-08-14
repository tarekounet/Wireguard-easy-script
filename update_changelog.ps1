
# ===============================
# 📦 WireGuard Easy – Changelog Generator
# ===============================

function Convert-ToLF {
    param (
        [string]$FilePath
    )
    $dos2unix = $null
    # Chemin prioritaire pour Windows/Git Bash
    if (Test-Path 'C:/Program Files/Git/usr/bin/dos2unix.exe') {
        $dos2unix = 'C:/Program Files/Git/usr/bin/dos2unix.exe'
    } elseif (Get-Command dos2unix -ErrorAction SilentlyContinue) {
        $dos2unix = 'dos2unix'
    } elseif (Test-Path 'C:/Program Files/Git/usr/bin/dos2unix') {
        $dos2unix = 'C:/Program Files/Git/usr/bin/dos2unix'
    }
    if ($dos2unix) {
        & $dos2unix $FilePath
    } else {
        Write-Warning "dos2unix n'est pas installé ou introuvable. Conversion LF ignorée."
    }
}

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

    # Conversion LF automatique
    Convert-ToLF $changelogPath
    Convert-ToLF "version.txt"
    Convert-ToLF "admin_menu.sh"
    Convert-ToLF "config_wg.sh"

    # Mise à jour du fichier version.txt
    $newVersion | Set-Content "version.txt"
    Convert-ToLF "version.txt"

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
            Convert-ToLF "admin_menu.sh"
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
            Convert-ToLF "config_wg.sh"
            Write-Host "📝 Fichier config_wg.sh mis à jour" -ForegroundColor Green
        }
    }

    Write-Host "`n✅ Changelog mis à jour avec la version $newVersion !" -ForegroundColor Green
    Write-Host "📝 Fichier version.txt également mis à jour" -ForegroundColor Green
    
    # Proposition d'automatisation Git
    Write-Host "`n🚀 Workflow Git automatique disponible :" -ForegroundColor Cyan
    Write-Host "   📝 Commit des changements" -ForegroundColor White
    Write-Host "   🏷️  Création du tag v$newVersion" -ForegroundColor White
    Write-Host "   📤 Push vers le repository" -ForegroundColor White
    
    $gitWorkflow = Read-Host "`n🤖 Voulez-vous exécuter le workflow Git automatique ? (o/N)"
    if ($gitWorkflow -match '^[oO]$') {
        Start-GitWorkflow -version $newVersion -changelogEntries ($added + $modified + $fixed)
    } else {
        Write-Host "`n💡 Workflow Git ignoré. Vous pouvez l'exécuter manuellement plus tard." -ForegroundColor Yellow
    }
    
    # Pause pour laisser le temps de lire
    Write-Host "`n🔄 Appuyez sur une touche pour continuer..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Start-GitWorkflow {
    param (
        [string]$version,
        [array]$changelogEntries
    )
   
    Write-Host "`n🚀 Démarrage du workflow Git automatique..." -ForegroundColor Cyan
    
    # Conversion en LF (format Unix) pour tous les .sh avant le commit/push
    if (Get-Command bash -ErrorAction SilentlyContinue) {
        bash -c "find . -type f -name '*.sh' -exec dos2unix {} \;"
    } else {
        foreach ($folder in @('.', 'lib_admin', 'lib')) {
            Get-ChildItem -Path $folder -Recurse -Filter *.sh | ForEach-Object {
                if (Get-Command dos2unix -ErrorAction SilentlyContinue) {
                    dos2unix $_.FullName
                } else {
                    (Get-Content $_.FullName) | Set-Content $_.FullName
                }
            }
        }
    }

    # Vérification que nous sommes dans un repo Git
    if (-not (Test-Path ".git")) {
        Write-Host "❌ Erreur : Ce dossier n'est pas un repository Git." -ForegroundColor Red
        return
    }
    
    try {
        # 1. Vérification du statut Git
        Write-Host "`n📋 Vérification du statut Git..." -ForegroundColor Yellow
        $gitStatus = git status --porcelain
        
        if ($gitStatus) {
            Write-Host "📝 Fichiers modifiés détectés :" -ForegroundColor Green
            git status --short
            
            # 2. Ajout des fichiers modifiés
            Write-Host "`n➕ Ajout des fichiers au staging..." -ForegroundColor Yellow
            git add .
            
            # 3. Création du commit avec message automatique
            $commitMessage = "🔖 Release v$version`n`n"
            if ($changelogEntries.Count -gt 0) {
                $commitMessage += "Changements:`n"
                $changelogEntries | ForEach-Object { $commitMessage += "$_`n" }
            }
            
            Write-Host "`n💾 Création du commit..." -ForegroundColor Yellow
            git commit -m $commitMessage
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Commit créé avec succès" -ForegroundColor Green
            } else {
                throw "Erreur lors de la création du commit"
            }
        } else {
            Write-Host "ℹ️  Aucun fichier modifié détecté pour le commit" -ForegroundColor Blue
        }
        
        # 4. Création du tag
        Write-Host "`n🏷️  Création du tag v$version..." -ForegroundColor Yellow
        
        # Vérifier si le tag existe déjà
        $existingTag = git tag -l "v$version"
        if ($existingTag) {
            Write-Host "⚠️  Le tag v$version existe déjà. Suppression de l'ancien tag..." -ForegroundColor Yellow
            git tag -d "v$version"
            git push origin ":refs/tags/v$version" 2>$null
        }
        
        # Récupérer la dernière version avant incrément
        $lastVersion = Get-LastVersion
        if ($lastVersion -eq "0.0.0") {
            git tag -a "v$version" -m "v$version"
        } else {
            git tag -a "v$version" -m "v$lastVersion > v$version"
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Tag v$version créé avec succès" -ForegroundColor Green
        } else {
            throw "Erreur lors de la création du tag"
        }
        
        # 5. Push vers le repository
        Write-Host "`n📤 Push vers le repository..." -ForegroundColor Yellow
        
        # Push des commits
        git push origin main
        if ($LASTEXITCODE -ne 0) {
            throw "Erreur lors du push des commits"
        }
        
        # Push des tags
        git push origin "v$version"
        if ($LASTEXITCODE -ne 0) {
            throw "Erreur lors du push du tag"
        }
        
        Write-Host "`n🎉 Workflow Git terminé avec succès !" -ForegroundColor Green
        Write-Host "   ✅ Commit créé et pushé" -ForegroundColor White
        Write-Host "   ✅ Tag v$version créé et pushé" -ForegroundColor White
        Write-Host "   🌐 Repository mis à jour" -ForegroundColor White
        
        # Affichage des liens utiles
        $repoUrl = git config --get remote.origin.url
        if ($repoUrl -and $repoUrl -match "github\.com[:/]([^/]+)/([^/\.]+)") {
            $owner = $matches[1]
            $repo = $matches[2]
            Write-Host "`n🔗 Liens utiles :" -ForegroundColor Cyan
            Write-Host "   📦 Release : https://github.com/$owner/$repo/releases/tag/v$version" -ForegroundColor Blue
            Write-Host "   📝 Commits : https://github.com/$owner/$repo/commits/main" -ForegroundColor Blue
        }
        
    } catch {
        Write-Host "`n❌ Erreur durant le workflow Git : $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "💡 Vous pouvez exécuter les commandes manuellement :" -ForegroundColor Yellow
        Write-Host "   git add ." -ForegroundColor Gray
        Write-Host "   git commit -m `"Release v$version`"" -ForegroundColor Gray
        Write-Host "   git tag -a v$version -m `"Release v$version`"" -ForegroundColor Gray
        Write-Host "   git push origin main" -ForegroundColor Gray
        Write-Host "   git push origin v$version" -ForegroundColor Gray
    }
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
    Write-Host "2. 🚀 Workflow Git (commit + tag + push)"
    Write-Host "0. 🚪 Quitter"
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
}

do {
    Show-Menu
    $choice = Read-Host "Choix"

    switch ($choice) {
        "1" { Add-ChangelogSmart }
        "2" { 
            $currentVersion = Get-LastVersion
            if ($currentVersion -eq "0.0.0") {
                Write-Host "❌ Aucune version trouvée dans le changelog. Créez d'abord une entrée." -ForegroundColor Red
            } else {
                Start-GitWorkflow -version $currentVersion -changelogEntries @()
            }
        }
        "0" { Write-Host "👋 À bientôt, Tarek !" }
        default { Write-Host "❌ Choix invalide. Réessaie." }
    }
} while ($choice -ne "0")

function Convert-ToLF {
    param (
        [string]$FilePath
    )
    $dos2unix = $null
    # Chemin prioritaire pour Windows/Git Bash
    if (Test-Path 'C:/Program Files/Git/usr/bin/dos2unix.exe') {
        $dos2unix = 'C:/Program Files/Git/usr/bin/dos2unix.exe'
    } elseif (Get-Command dos2unix -ErrorAction SilentlyContinue) {
        $dos2unix = 'dos2unix'
    } elseif (Test-Path 'C:/Program Files/Git/usr/bin/dos2unix') {
        $dos2unix = 'C:/Program Files/Git/usr/bin/dos2unix'
    }
    if ($dos2unix) {
        & $dos2unix $FilePath
    } else {
        Write-Warning "dos2unix n'est pas installé ou introuvable. Conversion LF ignorée."
    }
}