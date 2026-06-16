/// Model representing a hymn category.
class Category {
  final int id;
  final String name;
  final int order;
  final String? imagePath;
  final String? description;
  // Self-referential parent, eager-loaded by the API as `category.parent`.
  // Used to render the full category hierarchy ("Parent → Child") in the hero.
  final Category? parent;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Category({
    required this.id,
    required this.name,
    required this.order,
    this.imagePath,
    this.description,
    this.parent,
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
      parent: json['parent'] is Map<String, dynamic>
          ? Category.fromJson(json['parent'] as Map<String, dynamic>)
          : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  /// Full chain from the root category down to this one (root first, leaf last).
  List<Category> get hierarchy {
    final chain = <Category>[];
    Category? current = this;
    while (current != null) {
      chain.insert(0, current);
      current = current.parent;
    }
    return chain;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'order': order,
      'image_path': imagePath,
      'description': description,
      'parent': parent?.toJson(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}