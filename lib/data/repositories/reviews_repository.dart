import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/review_model.dart';
class ReviewsRepository {
  final FirebaseFirestore _firestore;
  ReviewsRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;
  Stream<List<ReviewModel>> watchReviewsByProvider(String providerId) {
    return _firestore
        .collection('reviews')
        .where('providerId', isEqualTo: providerId)
        .snapshots()
        .map((snapshot) {
      final reviews = snapshot.docs.map((doc) {
        return ReviewModel.fromMap(doc.data(), id: doc.id);
      }).toList();
      reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return reviews;
    });
  }
  /// Salva a avaliação e recalcula [avgRating] / [ratingCount] atomicamente
  /// via [runTransaction], eliminando a race condition de escrita concorrente.
  Future<void> addReview({required ReviewModel review}) async {
    final reviewRef = _firestore.collection('reviews').doc();
    final providerRef =
        _firestore.collection('providers').doc(review.providerId);
    await _firestore.runTransaction((transaction) async {
      final providerSnap = await transaction.get(providerRef);
      // Grava a avaliação
      transaction.set(reviewRef, review.toMap());
      // Atualiza o prestador somente se o documento existir
      if (providerSnap.exists) {
        final data = providerSnap.data()!;
        final currentCount = (data['ratingCount'] ?? 0) as int;
        final currentAvg = _toDouble(data['avgRating']);
        final newCount = currentCount + 1;
        final newAvg =
            ((currentAvg * currentCount) + review.rating) / newCount;
        transaction.update(providerRef, {
          'ratingCount': newCount,
          'avgRating': double.parse(newAvg.toStringAsFixed(1)),
        });
      }
    });
  }
  static double _toDouble(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return double.tryParse(value.toString()) ?? 0;
  }
}
