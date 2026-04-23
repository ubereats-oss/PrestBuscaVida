# preparar_auditoria.ps1
# Gera um ZIP de auditoria contendo SOMENTE código e configs relevantes.

$projectRoot = Get-Location
$parent = Split-Path $projectRoot -Parent
$outZip = Join-Path $parent "auditoria_senhas.zip"

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$staging = Join-Path $env:TEMP "auditoria_flutter_staging_$stamp"

Write-Host "Projeto:  $projectRoot"
Write-Host "Staging:  $staging"
Write-Host "Saida:    $outZip"
Write-Host ""

if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
New-Item -ItemType Directory -Path $staging | Out-Null

function Copy-IfExists($relativePath) {
  $src = Join-Path $projectRoot $relativePath
  if (Test-Path $src) {
    $dst = Join-Path $staging $relativePath
    $dstDir = Split-Path $dst -Parent
    if (!(Test-Path $dstDir)) { New-Item -ItemType Directory -Path $dstDir | Out-Null }

    if ((Get-Item $src).PSIsContainer) {
      robocopy "$src" "$dst" /E /R:0 /W:0 | Out-Null
    } else {
      Copy-Item -Path $src -Destination $dst -Force
    }
    Write-Host "OK  $relativePath"
  } else {
    Write-Host "SKIP $relativePath (nao existe)"
  }
}

# Exclui arquivos sensíveis ou gerados de uma pasta antes de copiar
function Copy-FolderFiltered($relativePath, [string[]]$excludePatterns) {
  $src = Join-Path $projectRoot $relativePath
  if (!(Test-Path $src)) {
    Write-Host "SKIP $relativePath (nao existe)"
    return
  }
  $dst = Join-Path $staging $relativePath
  if (!(Test-Path $dst)) { New-Item -ItemType Directory -Path $dst | Out-Null }

  Get-ChildItem -Path $src -Recurse -File | Where-Object {
    $rel = $_.FullName.Substring($src.Length + 1)
    $exclude = $false
    foreach ($pattern in $excludePatterns) {
      if ($rel -like $pattern) { $exclude = $true; break }
    }
    -not $exclude
  } | ForEach-Object {
    $rel = $_.FullName.Substring($src.Length + 1)
    $dstFile = Join-Path $dst $rel
    $dstFileDir = Split-Path $dstFile -Parent
    if (!(Test-Path $dstFileDir)) { New-Item -ItemType Directory -Path $dstFileDir | Out-Null }
    Copy-Item -Path $_.FullName -Destination $dstFile -Force
  }
  Write-Host "OK  $relativePath (filtrado)"
}

Write-Host "Copiando itens essenciais..."
Copy-IfExists "lib"
Copy-IfExists "pubspec.yaml"
Copy-IfExists "pubspec.lock"
Copy-IfExists "analysis_options.yaml"
Copy-IfExists "README.md"
Copy-IfExists "README.txt"

# Firebase configs (raiz do projeto)
Copy-IfExists "firebase.json"
Copy-IfExists "firestore.rules"
Copy-IfExists "firestore.indexes.json"
Copy-IfExists "storage.rules"
Copy-IfExists ".firebaserc"

# Android (configs relevantes, sem build)
Copy-IfExists "android\app\build.gradle"
Copy-IfExists "android\app\build.gradle.kts"
Copy-IfExists "android\build.gradle"
Copy-IfExists "android\build.gradle.kts"
Copy-IfExists "android\settings.gradle"
Copy-IfExists "android\settings.gradle.kts"
Copy-IfExists "android\gradle.properties"
Copy-IfExists "android\gradle\wrapper"
Copy-IfExists "android\app\src\main\AndroidManifest.xml"
Copy-IfExists "android\app\src\debug\AndroidManifest.xml"
Copy-IfExists "android\app\src\profile\AndroidManifest.xml"

# iOS (configs relevantes, sem Pods)
Copy-IfExists "ios\Podfile"
Copy-IfExists "ios\Runner.xcodeproj\project.pbxproj"

# Cloud Functions — exclui node_modules, .env e arquivos de build
Copy-FolderFiltered "functions" @(
  "node_modules\*",
  ".env",
  ".env.*",
  "*.env",
  "lib\*",          # pasta build do TypeScript
  ".runtimeconfig.json"
)

Write-Host "Normalizando line endings dos .dart..."
py "$projectRoot\normalizar_dart.py" "$projectRoot"

Write-Host ""
Write-Host "Gerando ZIP..."

if (Test-Path $outZip) { Remove-Item $outZip -Force }
Compress-Archive -Path (Join-Path $staging "*") -DestinationPath $outZip -Force

Remove-Item $staging -Recurse -Force

$tamanho = [math]::Round((Get-Item $outZip).Length / 1MB, 2)
Write-Host ""
Write-Host "ZIP gerado: $outZip ($tamanho MB)"