import os

def replace(path, old, new):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    if old not in content:
        print(f'[ERRO] Trecho nao encontrado em {path}')
        return
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content.replace(old, new, 1))
    print(f'[OK] {path}')

# ── Utilitário de formatação dinâmica ─────────────────────────────────────────
# Adiciona função de formatação ao phone_formatter.dart

formatter_path = os.path.join('lib', 'core', 'utils', 'phone_formatter.dart')
with open(formatter_path, 'r', encoding='utf-8') as f:
    content = f.read()

append = '''
String formatPhoneInput(String raw) {
  final digits = raw.replaceAll(RegExp(r'\\D'), '');
  if (digits.isEmpty) return '';
  if (digits.length <= 2) return '(${digits}';
  if (digits.length <= 6) return '(${digits.substring(0, 2)}) ${digits.substring(2)}';
  final isCell = digits.length > 10 || (digits.length > 6 && digits[2] == '9');
  if (isCell) {
    if (digits.length <= 11) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2, digits.length > 7 ? 7 : digits.length)}${digits.length > 7 ? '-${digits.substring(7)}' : ''}';
    }
    return '(${digits.substring(0, 2)}) ${digits.substring(2, 7)}-${digits.substring(7, 11)}';
  } else {
    if (digits.length <= 10) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2, digits.length > 6 ? 6 : digits.length)}${digits.length > 6 ? '-${digits.substring(6)}' : ''}';
    }
    return '(${digits.substring(0, 2)}) ${digits.substring(2, 6)}-${digits.substring(6, 10)}';
  }
}
'''

if 'formatPhoneInput' not in content:
    with open(formatter_path, 'a', encoding='utf-8') as f:
        f.write(append)
    print(f'[OK] {formatter_path}')
else:
    print(f'[JA EXISTE] formatPhoneInput em {formatter_path}')

# ── admin_panel_page.dart ──────────────────────────────────────────────────────

admin_path = os.path.join('lib', 'features', 'admin', 'admin_panel_page.dart')

# Adicionar import
replace(
    admin_path,
    "import 'package:flutter/material.dart';",
    "import 'package:flutter/material.dart';\nimport '../../core/utils/phone_formatter.dart';"
)

# Campo telefone — adicionar onChanged
replace(
    admin_path,
    "          TextField(\n"
    "            controller: _phoneController,\n"
    "            decoration: const InputDecoration(\n"
    "              labelText: 'Telefone',\n"
    "              border: OutlineInputBorder(),\n"
    "            ),\n"
    "            keyboardType: TextInputType.phone,\n"
    "          ),",
    "          TextField(\n"
    "            controller: _phoneController,\n"
    "            decoration: const InputDecoration(\n"
    "              labelText: 'Telefone',\n"
    "              border: OutlineInputBorder(),\n"
    "            ),\n"
    "            keyboardType: TextInputType.phone,\n"
    "            onChanged: (v) {\n"
    "              final formatted = formatPhoneInput(v);\n"
    "              if (formatted != v) {\n"
    "                _phoneController.value = TextEditingValue(\n"
    "                  text: formatted,\n"
    "                  selection: TextSelection.collapsed(offset: formatted.length),\n"
    "                );\n"
    "              }\n"
    "            },\n"
    "          ),"
)

# Campo whatsapp — adicionar onChanged
replace(
    admin_path,
    "          TextField(\n"
    "            controller: _whatsappController,\n"
    "            decoration: const InputDecoration(\n"
    "              labelText: 'WhatsApp (somente números com DDD)',\n"
    "              border: OutlineInputBorder(),\n"
    "            ),\n"
    "            keyboardType: TextInputType.phone,\n"
    "          ),",
    "          TextField(\n"
    "            controller: _whatsappController,\n"
    "            decoration: const InputDecoration(\n"
    "              labelText: 'WhatsApp',\n"
    "              border: OutlineInputBorder(),\n"
    "            ),\n"
    "            keyboardType: TextInputType.phone,\n"
    "            onChanged: (v) {\n"
    "              final formatted = formatPhoneInput(v);\n"
    "              if (formatted != v) {\n"
    "                _whatsappController.value = TextEditingValue(\n"
    "                  text: formatted,\n"
    "                  selection: TextSelection.collapsed(offset: formatted.length),\n"
    "                );\n"
    "              }\n"
    "            },\n"
    "          ),"
)

# ── suggest_provider_page.dart ─────────────────────────────────────────────────

suggest_path = os.path.join('lib', 'features', 'suggestions', 'suggest_provider_page.dart')

# Adicionar import
replace(
    suggest_path,
    "import 'package:flutter/material.dart';",
    "import 'package:flutter/material.dart';\nimport '../../core/utils/phone_formatter.dart';"
)

# Campo telefone
replace(
    suggest_path,
    "              TextField(\r\n"
    "                controller: _phoneController,\r\n"
    "                decoration: const InputDecoration(\r\n"
    "                  labelText: 'Telefone',\r\n"
    "                  border: OutlineInputBorder(),\r\n"
    "                ),\r\n"
    "                keyboardType: TextInputType.phone,\r\n"
    "              ),",
    "              TextField(\n"
    "                controller: _phoneController,\n"
    "                decoration: const InputDecoration(\n"
    "                  labelText: 'Telefone',\n"
    "                  border: OutlineInputBorder(),\n"
    "                ),\n"
    "                keyboardType: TextInputType.phone,\n"
    "                onChanged: (v) {\n"
    "                  final formatted = formatPhoneInput(v);\n"
    "                  if (formatted != v) {\n"
    "                    _phoneController.value = TextEditingValue(\n"
    "                      text: formatted,\n"
    "                      selection: TextSelection.collapsed(offset: formatted.length),\n"
    "                    );\n"
    "                  }\n"
    "                },\n"
    "              ),"
)

# Campo whatsapp
replace(
    suggest_path,
    "              TextField(\r\n"
    "                controller: _whatsappController,\r\n"
    "                decoration: const InputDecoration(\r\n"
    "                  labelText: 'WhatsApp (somente numeros com DDD)',\r\n"
    "                  border: OutlineInputBorder(),\r\n"
    "                ),\r\n"
    "                keyboardType: TextInputType.phone,\r\n"
    "              ),",
    "              TextField(\n"
    "                controller: _whatsappController,\n"
    "                decoration: const InputDecoration(\n"
    "                  labelText: 'WhatsApp',\n"
    "                  border: OutlineInputBorder(),\n"
    "                ),\n"
    "                keyboardType: TextInputType.phone,\n"
    "                onChanged: (v) {\n"
    "                  final formatted = formatPhoneInput(v);\n"
    "                  if (formatted != v) {\n"
    "                    _whatsappController.value = TextEditingValue(\n"
    "                      text: formatted,\n"
    "                      selection: TextSelection.collapsed(offset: formatted.length),\n"
    "                    );\n"
    "                  }\n"
    "                },\n"
    "              ),"
)
