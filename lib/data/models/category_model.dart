class CategoryModel {
  final String id;
  final String name;
  final String slug;
  final int order;
  final bool isActive;
  const CategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.order,
    required this.isActive,
  });
  factory CategoryModel.fromMap(
    Map<String, dynamic> map, {
    required String id,
  }) {
    return CategoryModel(
      id: id,
      name: (map['name'] ?? '').toString(),
      slug: (map['slug'] ?? '').toString(),
      order: (map['order'] ?? 0) as int,
      isActive: (map['isActive'] ?? true) as bool,
    );
  }
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'slug': slug,
      'order': order,
      'isActive': isActive,
    };
  }
  CategoryModel copyWith({
    String? id,
    String? name,
    String? slug,
    int? order,
    bool? isActive,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      order: order ?? this.order,
      isActive: isActive ?? this.isActive,
    );
  }
}
