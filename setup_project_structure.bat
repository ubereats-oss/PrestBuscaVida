@echo off

echo Criando estrutura de pastas...

mkdir lib\app
mkdir lib\core
mkdir lib\core\constants
mkdir lib\core\theme
mkdir lib\core\utils

mkdir lib\data
mkdir lib\data\models
mkdir lib\data\repositories

mkdir lib\features
mkdir lib\features\home
mkdir lib\features\categories
mkdir lib\features\providers
mkdir lib\features\provider_detail
mkdir lib\features\reviews

mkdir lib\firebase


echo Criando arquivos base...

type nul > lib\app\app.dart

type nul > lib\core\theme\app_theme.dart

type nul > lib\data\models\category_model.dart
type nul > lib\data\models\provider_model.dart
type nul > lib\data\models\review_model.dart

type nul > lib\features\home\home_page.dart
type nul > lib\features\categories\categories_page.dart
type nul > lib\features\providers\providers_page.dart
type nul > lib\features\provider_detail\provider_detail_page.dart
type nul > lib\features\reviews\review_form_page.dart


echo Estrutura criada com sucesso.
pause