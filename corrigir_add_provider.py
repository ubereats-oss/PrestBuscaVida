import os, sys

ARQUIVO = os.path.join('lib', 'features', 'admin', 'admin_panel_page.dart')

if not os.path.exists(ARQUIVO):
    print(f'ERRO: arquivo nao encontrado: {ARQUIVO}')
    sys.exit(1)

with open(ARQUIVO, 'r', encoding='utf-8') as f:
    conteudo = f.read()

# ── 1. Adicionar controllers de indicacao e observacao ────────────────────────
ANTIGO_1 = "  final _descriptionController = TextEditingController();\n  CategoryModel? _selectedCategory;"
NOVO_1 = "  final _descriptionController = TextEditingController();\n  final _indicacaoController = TextEditingController();\n  final _observacaoController = TextEditingController();\n  CategoryModel? _selectedCategory;"

if ANTIGO_1 not in conteudo:
    print('ERRO: trecho 1 nao encontrado. Verifique se o arquivo nao foi alterado.')
    sys.exit(1)
conteudo = conteudo.replace(ANTIGO_1, NOVO_1, 1)

# ── 2. Dispose dos novos controllers ──────────────────────────────────────────
ANTIGO_2 = "    _descriptionController.dispose();\n    super.dispose();\n  }\n  Future<void> _loadCategories"
NOVO_2 = "    _descriptionController.dispose();\n    _indicacaoController.dispose();\n    _observacaoController.dispose();\n    super.dispose();\n  }\n  Future<void> _loadCategories"

if ANTIGO_2 not in conteudo:
    print('ERRO: trecho 2 nao encontrado.')
    sys.exit(1)
conteudo = conteudo.replace(ANTIGO_2, NOVO_2, 1)

# ── 3. Incluir indicacao e observacao no ProviderModel dentro de _submit ──────
ANTIGO_3 = """        description: _descriptionController.text.trim(),
        avgRating: 0,
        ratingCount: 0,
        isActive: true,
        status: 'active',
      );"""
NOVO_3 = """        description: _descriptionController.text.trim(),
        indicacao: _indicacaoController.text.trim(),
        observacao: _observacaoController.text.trim(),
        avgRating: 0,
        ratingCount: 0,
        isActive: true,
        status: 'active',
      );"""

if ANTIGO_3 not in conteudo:
    print('ERRO: trecho 3 nao encontrado.')
    sys.exit(1)
conteudo = conteudo.replace(ANTIGO_3, NOVO_3, 1)

# ── 4. Limpar controllers novos no clear apos sucesso ─────────────────────────
ANTIGO_4 = "        _descriptionController.clear();\n        setState(() => _selectedCategory = null);"
NOVO_4 = "        _descriptionController.clear();\n        _indicacaoController.clear();\n        _observacaoController.clear();\n        setState(() => _selectedCategory = null);"

if ANTIGO_4 not in conteudo:
    print('ERRO: trecho 4 nao encontrado.')
    sys.exit(1)
conteudo = conteudo.replace(ANTIGO_4, NOVO_4, 1)

# ── 5. Adicionar campos indicacao e observacao na UI (apos campo descricao) ───
ANTIGO_5 = """          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Descrição dos serviços',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
          ),
          if (_errorMessage != null)"""
NOVO_5 = """          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Descrição dos serviços',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _indicacaoController,
            decoration: const InputDecoration(
              labelText: 'Indicação (quem indicou)',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _observacaoController,
            decoration: const InputDecoration(
              labelText: 'Observação interna',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
          if (_errorMessage != null)"""

if ANTIGO_5 not in conteudo:
    print('ERRO: trecho 5 nao encontrado.')
    sys.exit(1)
conteudo = conteudo.replace(ANTIGO_5, NOVO_5, 1)

with open(ARQUIVO, 'w', encoding='utf-8', newline='\n') as f:
    f.write(conteudo)

print('OK: admin_panel_page.dart atualizado com sucesso.')
print('Campos adicionados: indicacao e observacao no formulario de adicionar prestador.')
