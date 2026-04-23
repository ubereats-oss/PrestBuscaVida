@echo off
cd /d "%~dp0"

echo Instalando dependencias do importador...
call npm init -y
call npm install firebase-admin xlsx

echo Executando importacao da planilha para o Firestore...
node import_planilha_firestore.js

pause