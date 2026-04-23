import 'package:cloud_firestore/cloud_firestore.dart';
class ReviewModel {
  final String id;
  final String providerId;
  final String reviewerUid;
  final String reviewerName;
  final int rating;
  final String comment;
  final DateTime createdAt;
  const ReviewModel({
    required this.id,
    required this.providerId,
    required this.reviewerUid,
    required this.reviewerName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });
  factory ReviewModel.fromMap(
    Map<String, dynamic> map, {
    required String id,
  }) {
    return ReviewModel(
      id: id,
      providerId: (map['providerId'] ?? '').toString(),
      reviewerUid: (map['reviewerUid'] ?? '').toString(),
      reviewerName: (map['reviewerName'] ?? '').toString(),
      rating: (map['rating'] ?? 1) as int,
      comment: (map['comment'] ?? '').toString(),
      createdAt:
          (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
  Map<String, dynamic> toMap() {
    return {
      'providerId': providerId,
      'reviewerUid': reviewerUid,
      'reviewerName': reviewerName,
      'rating': rating,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
  ReviewModel copyWith({
    String? id,
    String? providerId,
    String? reviewerUid,
    String? reviewerName,
    int? rating,
    String? comment,
    DateTime? createdAt,
  }) {
    return ReviewModel(
      id: id ?? this.id,
      providerId: providerId ?? this.providerId,
      reviewerUid: reviewerUid ?? this.reviewerUid,
      reviewerName: reviewerName ?? this.reviewerName,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
