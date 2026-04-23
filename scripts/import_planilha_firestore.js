const admin = require('firebase-admin');
const xlsx = require('xlsx');
const path = require('path');
const fs = require('fs');
const serviceAccountPath = path.join(__dirname, 'serviceAccountKey.json');
const spreadsheetPath = path.join(__dirname, '..', 'prestadores_importacao.xlsx');
if (!fs.existsSync(serviceAccountPath)) {
  console.error('ERRO: arquivo serviceAccountKey.json nao encontrado na pasta scripts.');
  process.exit(1);
}
if (!fs.existsSync(spreadsheetPath)) {
  console.error('ERRO: planilha nao encontrada na raiz do projeto.');
  console.error('Esperado em:');
  console.error(spreadsheetPath);
  process.exit(1);
}
admin.initializeApp({
  credential: admin.credential.cert(require(serviceAccountPath)),
});
const db = admin.firestore();
function normalizeText(value) {
  return String(value ?? '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}
function slugify(value) {
  return normalizeText(value)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}
function digitsOnly(value) {
  return String(value ?? '').replace(/\D/g, '');
}
function toNumber(value) {
  if (value === null || value === undefined || value === '') {
    return 0;
  }
  if (typeof value === 'number') {
    return value;
  }
  const normalized = String(value).replace(',', '.').trim();
  const parsed = Number(normalized);
  return Number.isFinite(parsed) ? parsed : 0;
}
function isSheetTitleRow(row) {
  const colA = normalizeText(row[0]).toLowerCase();
  const colB = normalizeText(row[1]).toLowerCase();
  return (
    colA.includes('lista de prestadores de servico') &&
    colB.includes('nome do prestador')
  );
}
function isCategoryHeaderRow(row) {
  const colA = normalizeText(row[0]);
  const colB = normalizeText(row[1]).toLowerCase();
  const colC = normalizeText(row[2]).toLowerCase();
  if (!colA) {
    return false;
  }
  return colB === 'nome' && colC.includes('contato');
}
function rowHasAnyContent(row) {
  return row.some((cell) => normalizeText(cell) !== '');
}
function buildProviderId(categorySlug, providerName, usedIds) {
  const baseId = slugify(`${categorySlug}-${providerName}`) || `provider-${Date.now()}`;
  let finalId = baseId;
  let counter = 2;
  while (usedIds.has(finalId)) {
    finalId = `${baseId}-${counter}`;
    counter += 1;
  }
  usedIds.add(finalId);
  return finalId;
}
function extractData(sheet) {
  const rows = xlsx.utils.sheet_to_json(sheet, {
    header: 1,
    defval: '',
    raw: false,
  });
  const categories = [];
  const providers = [];
  const usedProviderIds = new Set();
  let currentCategoryName = '';
  let currentCategorySlug = '';
  let currentOrder = 0;
  for (let i = 0; i < rows.length; i += 1) {
    const row = rows[i];
    if (!rowHasAnyContent(row)) {
      continue;
    }
    if (isSheetTitleRow(row)) {
      continue;
    }
    if (isCategoryHeaderRow(row)) {
      currentCategoryName = normalizeText(row[0]);
      currentCategorySlug = slugify(currentCategoryName);
      if (
        currentCategorySlug &&
        !categories.some((item) => item.slug === currentCategorySlug)
      ) {
        currentOrder += 1;
        categories.push({
          id: currentCategorySlug,
          name: currentCategoryName,
          slug: currentCategorySlug,
          order: currentOrder,
          isActive: true,
        });
      }
      continue;
    }
    if (!currentCategorySlug) {
      continue;
    }
    const providerName = normalizeText(row[1]);
    const rawContact = row[5] !== '' ? row[5] : row[2];
    const phone = digitsOnly(rawContact);
    const rating = toNumber(row[3]);
    const notes = normalizeText(row[4]);
    if (!providerName) {
      continue;
    }
    if (providerName.toLowerCase() === 'nome') {
      continue;
    }
    if (providerName.startsWith('#REF')) {
      continue;
    }
    const providerId = buildProviderId(
      currentCategorySlug,
      providerName,
      usedProviderIds,
    );
    providers.push({
      id: providerId,
      name: providerName,
      categoryId: currentCategorySlug,
      phone,
      whatsapp: phone,
      description: currentCategoryName,
      avgRating: rating,
      ratingCount: rating > 0 ? 1 : 0,
      notes,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
  return { categories, providers };
}
async function saveCategories(categories) {
  for (const category of categories) {
    await db.collection('categories').doc(category.id).set({
      name: category.name,
      slug: category.slug,
      order: category.order,
      isActive: category.isActive,
    });
    console.log(`Categoria salva: ${category.name}`);
  }
}
async function saveProviders(providers) {
  for (const provider of providers) {
    await db.collection('providers').doc(provider.id).set({
      name: provider.name,
      categoryId: provider.categoryId,
      phone: provider.phone,
      whatsapp: provider.whatsapp,
      description: provider.description,
      avgRating: provider.avgRating,
      ratingCount: provider.ratingCount,
      notes: provider.notes,
      isActive: provider.isActive,
      createdAt: provider.createdAt,
      updatedAt: provider.updatedAt,
    });
    console.log(`Prestador salvo: ${provider.name}`);
  }
}
async function main() {
  console.log('Abrindo planilha...');
  const workbook = xlsx.readFile(spreadsheetPath);
  const sheetName = workbook.SheetNames[0];
  const sheet = workbook.Sheets[sheetName];
  const { categories, providers } = extractData(sheet);
  console.log(`Categorias encontradas: ${categories.length}`);
  console.log(`Prestadores encontrados: ${providers.length}`);
  if (categories.length === 0) {
    throw new Error('Nenhuma categoria foi identificada na planilha.');
  }
  if (providers.length === 0) {
    throw new Error('Nenhum prestador foi identificado na planilha.');
  }
  await saveCategories(categories);
  await saveProviders(providers);
  console.log('Importacao concluida com sucesso.');
}
main().catch((error) => {
  console.error('Erro na importacao:', error);
  process.exit(1);
});
