import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/provider_model.dart';
class ProvidersRepository {
  final FirebaseFirestore _firestore;
  ProvidersRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;
  // ── LEITURA PÚBLICA ───────────────────────────────────────────────────────────
  Stream<List<ProviderModel>> watchProvidersByCategory({
    required String categoryId,
  }) {
    return _firestore
        .collection('providers')
        .where('isActive', isEqualTo: true)
        .where('categoryId', isEqualTo: categoryId)
        .snapshots()
        .map((snapshot) {
      final providers = snapshot.docs.map((doc) {
        return ProviderModel.fromMap(doc.data(), id: doc.id);
      }).toList();
      providers.sort((a, b) => a.name.compareTo(b.name));
      return providers;
    });
  }
  Stream<List<ProviderModel>> watchProvidersForSearch({
    required String searchQuery,
  }) {
    return _firestore
        .collection('providers')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final providers = snapshot.docs.map((doc) {
        return ProviderModel.fromMap(doc.data(), id: doc.id);
      }).toList();
      final normalizedQuery = searchQuery.trim().toLowerCase();
      if (normalizedQuery.isEmpty) {
        providers.sort((a, b) => a.name.compareTo(b.name));
        return providers;
      }
      final filtered = providers.where((provider) {
        return provider.name.toLowerCase().contains(normalizedQuery) ||
            provider.description.toLowerCase().contains(normalizedQuery) ||
            provider.categoryName.toLowerCase().contains(normalizedQuery);
      }).toList();
      filtered.sort((a, b) => a.name.compareTo(b.name));
      return filtered;
    });
  }
  // ── ADMIN ────────────────────────────────────────────────────────────────────
  /// Stream de sugestões aguardando aprovação.
  Stream<List<ProviderModel>> watchPendingProviders() {
    return _firestore
        .collection('providers')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      final providers = snapshot.docs.map((doc) {
        return ProviderModel.fromMap(doc.data(), id: doc.id);
      }).toList();
      providers.sort((a, b) => a.name.compareTo(b.name));
      return providers;
    });
  }
  /// Admin adiciona prestador diretamente (já ativo).
  Future<void> addProvider({required ProviderModel provider}) async {
    await _firestore.collection('providers').add(provider.toMap());
  }
  /// Aprovar sugestão: torna o prestador visível no app.
  Future<void> approveProvider(String id) async {
    await _firestore.collection('providers').doc(id).update({
      'isActive': true,
      'status': 'active',
    });
  }
  /// Rejeitar sugestão: oculta o prestador sem excluir.
  Future<void> rejectProvider(String id) async {
    await _firestore.collection('providers').doc(id).update({
      'status': 'rejected',
    });
  }
  // ── USUÁRIO ──────────────────────────────────────────────────────────────────
  /// Usuário sugere um prestador (fica pendente até admin aprovar).
  Future<void> suggestProvider({required ProviderModel provider}) async {
    await _firestore.collection('providers').add(provider.toMap());
  }
}
