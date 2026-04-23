import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/category_model.dart';
class CategoriesRepository {
  final FirebaseFirestore _firestore;
  CategoriesRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;
  /// Retorna categorias ativas ordenadas pelo campo [order] (definido no Firestore).
  Future<List<CategoryModel>> fetchActiveCategories() async {
    final snapshot = await _firestore
        .collection('categories')
        .where('isActive', isEqualTo: true)
        .orderBy('order')
        .get();
    return snapshot.docs.map((doc) {
      return CategoryModel.fromMap(doc.data(), id: doc.id);
    }).toList();
  }
  Future<void> suggestCategory({required String name, required String suggestedByUid}) async {
    await _firestore.collection('category_suggestions').add({
      'name': name,
      'suggestedByUid': suggestedByUid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
  /// Stream de categorias ativas ordenadas pelo campo [order].
  Stream<List<CategoryModel>> watchActiveCategories() {
    return _firestore
        .collection('categories')
        .where('isActive', isEqualTo: true)
        .orderBy('order')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return CategoryModel.fromMap(doc.data(), id: doc.id);
      }).toList();
    });
  }
}
