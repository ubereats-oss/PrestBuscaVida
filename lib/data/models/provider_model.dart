class ProviderModel {
  final String id;
  final String name;
  final String categoryId;
  final String categoryName;
  final String phone;
  final String whatsapp;
  final String description;
  final double avgRating;
  final int ratingCount;
  final bool isActive;
  final String status; // 'active' | 'pending' | 'rejected'
  final String? suggestedBy; // uid do usuário que sugeriu
  final String indicacao;
  final String observacao;
  const ProviderModel({
    required this.id,
    required this.name,
    required this.categoryId,
    this.categoryName = '',
    required this.phone,
    required this.whatsapp,
    required this.description,
    required this.avgRating,
    required this.ratingCount,
    required this.isActive,
    this.status = 'active',
    this.suggestedBy,
    this.indicacao = '',
    this.observacao = '',
  });
  factory ProviderModel.fromMap(
    Map<String, dynamic> map, {
    required String id,
  }) {
    return ProviderModel(
      id: id,
      name: (map['name'] ?? '').toString(),
      categoryId: (map['categoryId'] ?? '').toString(),
      categoryName: (map['categoryName'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      whatsapp: (map['whatsapp'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      avgRating: _toDouble(map['avgRating']),
      ratingCount: (map['ratingCount'] ?? 0) as int,
      isActive: (map['isActive'] ?? true) as bool,
      status: (map['status'] ?? 'active').toString(),
      suggestedBy: map['suggestedBy'] as String?,
      indicacao: (map['indicacao'] ?? '').toString(),
      observacao: (map['observacao'] ?? '').toString(),
    );
  }
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'phone': phone,
      'whatsapp': whatsapp,
      'description': description,
      'avgRating': avgRating,
      'ratingCount': ratingCount,
      'isActive': isActive,
      'status': status,
      'suggestedBy': suggestedBy,
      'indicacao': indicacao,
      'observacao': observacao,
    };
  }
  ProviderModel copyWith({
    String? id,
    String? name,
    String? categoryId,
    String? categoryName,
    String? phone,
    String? whatsapp,
    String? description,
    double? avgRating,
    int? ratingCount,
    bool? isActive,
    String? status,
    String? suggestedBy,
    String? indicacao,
    String? observacao,
  }) {
    return ProviderModel(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      description: description ?? this.description,
      avgRating: avgRating ?? this.avgRating,
      ratingCount: ratingCount ?? this.ratingCount,
      isActive: isActive ?? this.isActive,
      status: status ?? this.status,
      suggestedBy: suggestedBy ?? this.suggestedBy,
      indicacao: indicacao ?? this.indicacao,
      observacao: observacao ?? this.observacao,
    );
  }
  static double _toDouble(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return double.tryParse(value.toString()) ?? 0;
  }
}
