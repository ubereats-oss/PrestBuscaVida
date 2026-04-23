# preparar_auditoria.ps1
# Gera um ZIP de auditoria contendo SOMENTE código e configs relevantes.

$projectRoot = Get-Location
$parent = Split-Path $projectRoot -Parent
$outZip = Join-Path $parent "auditoria_PrestServ.zip"

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

Write-Host "Copiando itens essenciais..."

# ── Dart / Flutter ────────────────────────────────────────────────────────────
Copy-IfExists "lib"
Copy-IfExists "pubspec.yaml"
Copy-IfExists "pubspec.lock"
Copy-IfExists "analysis_options.yaml"
Copy-IfExists "README.md"
Copy-IfExists "README.txt"

# ── Assets (logos, imagens referenciadas no código) ───────────────────────────
Copy-IfExists "assets"

# ── Firebase ──────────────────────────────────────────────────────────────────
Copy-IfExists "firebase.json"
Copy-IfExists ".firebaserc"
Copy-IfExists "functions\index.js"
Copy-IfExists "functions\package.json"
# NÃO incluir: google-services.json, firebase_options.dart,
#              serviceAccountKey*.json  (dados sensíveis)

# ── Android ───────────────────────────────────────────────────────────────────
Copy-IfExists "android\app\src\main\AndroidManifest.xml"
Copy-IfExists "android\app\src\debug\AndroidManifest.xml"
Copy-IfExists "android\app\src\profile\AndroidManifest.xml"
Copy-IfExists "android\app\build.gradle"
Copy-IfExists "android\app\build.gradle.kts"
Copy-IfExists "android\build.gradle"
Copy-IfExists "android\build.gradle.kts"
Copy-IfExists "android\settings.gradle"
Copy-IfExists "android\settings.gradle.kts"
Copy-IfExists "android\gradle.properties"
Copy-IfExists "android\gradle\wrapper"
Copy-IfExists "android\key.properties"
# NÃO incluir: *.keystore, *.jks  (chave de assinatura sensível)

# ── iOS ───────────────────────────────────────────────────────────────────────
Copy-IfExists "ios\Runner\Info.plist"
Copy-IfExists "ios\Runner\AppDelegate.swift"
Copy-IfExists "ios\Runner.xcodeproj\project.pbxproj"
Copy-IfExists "ios\Podfile"
# NÃO incluir: GoogleService-Info.plist  (dados sensíveis)

Write-Host ""
Write-Host "Gerando ZIP..."

if (Test-Path $outZip) { Remove-Item $outZip -Force }
Compress-Archive -Path (Join-Path $staging "*") -DestinationPath $outZip -Force

Remove-Item $staging -Recurse -Force

$tamanho = [math]::Round((Get-Item $outZip).Length / 1MB, 2)
Write-Host ""
Write-Host "✅ ZIP gerado: $outZip ($tamanho MB)"