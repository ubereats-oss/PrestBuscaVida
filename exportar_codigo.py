import os
from datetime import datetime

root = os.getcwd()
output = os.path.join(root, "auditoria_codigo_py.txt")

# ── Configurações ─────────────────────────────────────────────────────────────

EXTENSOES_CODIGO = {'.dart', '.js', '.ts', '.json', '.yaml', '.yml', '.rules', '.md'}

EXTENSOES_AUDITORIA = {
    ".dart", ".yaml", ".yml", ".kts", ".gradle",
    ".xml", ".json", ".plist", ".swift"
}

IGNORAR_PASTAS = {
    '.git', 'build', '.dart_tool', '.idea',
    '.vscode', 'Pods', '.gradle', 'test',
    'node_modules', '.flutter-plugins'
}

IGNORAR_ARQUIVOS = {
    "firebase_options.dart",
    "google-services.json",
    "GoogleService-Info.plist",
    "firebase.json",
    "exportar_codigo.py",
    "auditoria_codigo_py.txt",
    "normalizar_dart.py",
    "package-lock.json",
    "serviceAccountKey.json",
}

# ── Arquivos críticos sempre incluídos na auditoria ───────────────────────────

def is_critical(full_path):
    n = full_path.replace("\\", "/")
    if n.endswith("MainActivity.kt"):       return True
    if n.endswith(".entitlements"):         return True
    if n.endswith("Info.plist"):            return True
    if n.endswith("AppDelegate.swift"):     return True
    if "network_security_config.xml" in n:  return True
    return False

# ── Passo 1: Normalizar quebras de linha ──────────────────────────────────────

print("Normalizando arquivos...")
normalizados = 0

for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [d for d in dirnames if d not in IGNORAR_PASTAS]

    for file in filenames:
        if file in IGNORAR_ARQUIVOS:
            continue
        ext = os.path.splitext(file)[1].lower()
        if ext not in EXTENSOES_CODIGO:
            continue
        caminho = os.path.join(dirpath, file)
        try:
            with open(caminho, 'rb') as f:
                conteudo = f.read()
            texto = conteudo.decode('utf-8', errors='replace')
            normalizado = texto.replace('\r\r\n', '\n').replace('\r\n', '\n').replace('\r', '\n')
            if not normalizado.endswith('\n'):
                normalizado += '\n'
            if normalizado != texto:
                with open(caminho, 'w', encoding='utf-8', newline='\n') as f:
                    f.write(normalizado)
                normalizados += 1
        except Exception as e:
            print(f'  ERRO ao normalizar {caminho}: {e}')

print(f"  {normalizados} arquivo(s) normalizado(s).")

# ── Passo 2: Exportar auditoria ───────────────────────────────────────────────

print("Gerando auditoria...")
file_count = 0

with open(output, "w", encoding="utf-8") as out:
    out.write("==================================================\n")
    out.write(f"AUDITORIA DE CÓDIGO — BioOdonto\n")
    out.write(f"Gerado em: {datetime.now().strftime('%d/%m/%Y %H:%M:%S')}\n")
    out.write(f"Pasta raiz: {root}\n")
    out.write("==================================================\n\n")

    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in IGNORAR_PASTAS]

        for file in sorted(filenames):
            if file in IGNORAR_ARQUIVOS:
                continue
            ext = os.path.splitext(file)[1]
            full_path = os.path.join(dirpath, file)

            if not is_critical(full_path):
                if ext not in EXTENSOES_AUDITORIA:
                    continue

            out.write("==================================================\n")
            out.write(f"ARQUIVO: {full_path}\n")
            out.write("==================================================\n")

            try:
                with open(full_path, "r", encoding="utf-8") as f:
                    for i, line in enumerate(f, start=1):
                        out.write(f"{i:4}: {line}")
                file_count += 1
            except Exception as e:
                out.write(f"[ERRO ao ler arquivo: {e}]\n")

            out.write("\n\n")

    out.write("==================================================\n")
    out.write(f"Total de arquivos exportados: {file_count}\n")
    out.write("==================================================\n")

print(f"  Auditoria gerada: {output}")
print(f"  Total de arquivos exportados: {file_count}")
