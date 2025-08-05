# 📁 Fichiers
$templatePath = "CHANGELOG_TEMPLATE.md"
$outputPath = "CHANGELOG.md"

# 🕒 Date du jour
$date = Get-Date -Format "yyyy-MM-dd"

# 🔍 Extraction de la dernière version
$lastVersionLine = Select-String -Path $templatePath -Pattern '^\| (\d+\.\d+\.\d+) ' | Select-Object -First 1
if ($lastVersionLine) {
    $lastVersion = ($lastVersionLine -split '\|')[1].Trim()
    $versionParts = $lastVersion -split '\.'
    $major = [int]$versionParts[0]
    $minor = [int]$versionParts[1]
    $patch = [int]$versionParts[2]
} else {
    $major = 0; $minor = 1; $patch = 0
    $lastVersion = "Aucune version détectée"
}

Write-Host "Dernière version détectée : $lastVersion"
Write-Host "Quel composant souhaitez-vous incrémenter ?"
Write-Host "1. 🧱 Major ($major → $(($major + 1)).0.0)"
Write-Host "2. 🧩 Minor ($major.$minor → $major.$($minor + 1).0)"
Write-Host "3. 🔧 Patch ($major.$minor.$patch → $major.$minor.$($patch + 1))"

$choice = Read-Host "Entrez 1, 2 ou 3"
switch ($choice) {
    "1" { $major++; $minor = 0; $patch = 0 }
    "2" { $minor++; $patch = 0 }
    "3" { $patch++ }
    default { Write-Host "Choix invalide. Incrémentation du patch par défaut."; $patch++ }
}

$newVersion = "$major.$minor.$patch"
$version = Read-Host "Confirmez ou modifiez le numéro de version" -Default $newVersion
$summary = Read-Host "Résumé rapide"

Write-Host "`nAjouts (entrez une ligne vide pour terminer) :"
$added = @()
do {
    $line = Read-Host
    if ($line) { $added += "- ✨ $line" }
} while ($line)

Write-Host "`nModifications (entrez une ligne vide pour terminer) :"
$modified = @()
do {
    $line = Read-Host
    if ($line) { $modified += "- 🔄 $line" }
} while ($line)

Write-Host "`nCorrections (entrez une ligne vide pour terminer) :"
$fixed = @()
do {
    $line = Read-Host
    if ($line) { $fixed += "- 🐛 $line" }
} while ($line)

# 📄 Chargement du template
$template = Get-Content $templatePath -Raw

# 🔄 Remplacement des placeholders
$template = $template -replace "x\.x\.x", $version
$template = $template -replace "YYYY-MM-DD", $date
$template = $template -replace "\- ✨ \[Fonctionnalité\].*", ($added -join "`n")
$template = $template -replace "\- 🎨 \[Interface\].*", ($modified -join "`n")
$template = $template -replace "\- 🛠️ \[Bug\].*", ($fixed -join "`n")

# 📌 Ajout dans le tableau d’historique
$historyLine = "| $version   | $date | $summary |"
$template = $template -replace '(\| Version \| Date.*?\|[\s\S]*?\| \.\.\.     \| \.\.\.        \| \.\.\.                                    \|)', "`$1`n$historyLine"

# 💾 Sauvegarde
$template | Set-Content $outputPath -Encoding UTF8

Write-Host "`n✅ Fichier CHANGELOG.md généré avec succès pour la version $version"