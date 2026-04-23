import os
import xml.etree.ElementTree as ET

PLIST_PATH = os.path.join("ios", "Runner", "Info.plist")

def main():
    if not os.path.exists(PLIST_PATH):
        print("❌ Info.plist não encontrado em ios/Runner/")
        return

    tree = ET.parse(PLIST_PATH)
    root = tree.getroot()

    dict_elem = root.find("dict")
    if dict_elem is None:
        print("❌ Estrutura inválida no Info.plist")
        return

    # Verificar se já existe
    keys = list(dict_elem)
    for i in range(0, len(keys), 2):
        if keys[i].tag == "key" and keys[i].text == "ITSAppUsesNonExemptEncryption":
            print("⚠️ Já existe. Nenhuma alteração feita.")
            return

    # Inserir no final
    key = ET.Element("key")
    key.text = "ITSAppUsesNonExemptEncryption"

    value = ET.Element("false")

    dict_elem.append(key)
    dict_elem.append(value)

    tree.write(PLIST_PATH, encoding="utf-8", xml_declaration=True)

    print("✅ Inserido com sucesso no Info.plist")

if __name__ == "__main__":
    main()