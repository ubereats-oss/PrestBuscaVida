echo Atualizando iOS Deployment Target para 15.0...

:: 1. Atualiza Podfile
powershell -Command "(Get-Content ios\Podfile) -replace 'platform :ios, .*', 'platform :ios, ''15.0''' | Set-Content ios\Podfile"

:: 2. Atualiza project.pbxproj
powershell -Command "(Get-Content ios\Runner.xcodeproj\project.pbxproj) -replace 'IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;', 'IPHONEOS_DEPLOYMENT_TARGET = 15.0;' | Set-Content ios\Runner.xcodeproj\project.pbxproj"

:: 3. Atualiza xcconfig (se existir)
if exist ios\Flutter\AppFrameworkInfo.plist (
  powershell -Command "(Get-Content ios\Flutter\AppFrameworkInfo.plist) -replace '<string>[0-9.]+</string>', '<string>15.0</string>' | Set-Content ios\Flutter\AppFrameworkInfo.plist"
)

echo Concluido.