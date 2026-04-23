import os, sys

pasta = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.getcwd(), 'lib')

# Extensões de código a normalizar
EXTENSOES = {'.dart', '.js', '.ts', '.json', '.yaml', '.yml', '.rules', '.md'}

# Pastas a ignorar
IGNORAR_PASTAS = {'node_modules', '.git', 'build', '.dart_tool', '.flutter-plugins'}

for raiz, dirs, arquivos in os.walk(pasta):
    # Remove pastas ignoradas do percurso
    dirs[:] = [d for d in dirs if d not in IGNORAR_PASTAS]

    for nome in arquivos:
        ext = os.path.splitext(nome)[1].lower()
        if ext not in EXTENSOES:
            continue
        caminho = os.path.join(raiz, nome)
        try:
            with open(caminho, 'rb') as f:
                conteudo = f.read()
            texto = conteudo.decode('utf-8', errors='replace')
            texto = texto.replace('\r\r\n', '\n').replace('\r\n', '\n').replace('\r', '\n')
            linhas = [l for l in texto.split('\n') if l.strip() != '']
            texto_final = '\n'.join(linhas) + '\n'
            with open(caminho, 'w', encoding='utf-8', newline='\n') as f:
                f.write(texto_final)
        except Exception as e:
            print(f'ERRO {caminho}: {e}')

print('Normalizacao concluida.')