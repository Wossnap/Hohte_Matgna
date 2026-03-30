/// Model representing a hymn category.
class Category {
  final int id;
  final String name;
  final int order;
  final String? imagePath;
  final String? description;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Category({
    required this.id,
    required this.name,
    required this.order,
    this.imagePath,
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] is num ? (json['id'] as num).toInt() : int.parse(json['id'].toString()),
      name: json['name'] ?? '',
      order: (json['order'] as num?)?.toInt() ?? 0,
      imagePath: json['image_path'],
      description: json['description'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'order': order,
      'image_path': imagePath,
      'description': description,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}