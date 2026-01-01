class Section {
  final int id;
  final String name;
  final String? content;
  final String? audioUrl;
  final int plays;
  final int practices;
  final List<Section> children;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Section({
    required this.id,
    required this.name,
    this.content,
    this.audioUrl,
    required this.plays,
    required this.practices,
    required this.children,
    this.createdAt,
    this.updatedAt,
  });

  factory Section.fromJson(dynamic json) {
    Map<String, dynamic> map;
    if (json is Map<String, dynamic>) {
      map = json;
    } else if (json is List && json.isNotEmpty && json[0] is Map<String, dynamic>) {
      map = json[0] as Map<String, dynamic>;
    } else {
      map = {};
    }

    final childrenRaw = map['children'];
    List<Section> childrenList = [];
    if (childrenRaw is List) {
      for (final c in childrenRaw) {
        childrenList.add(Section.fromJson(c));
      }
    }

    return Section(
      id: map['id'] ?? 0,
      name: map['name'] ?? '',
      content: map['content'],
      audioUrl: map['audio_url'],
      plays: map['plays'] ?? 0,
      practices: map['practices'] ?? 0,
      children: childrenList,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'content': content,
      'audio_url': audioUrl,
      'plays': plays,
      'practices': practices,
      'children': children.map((e) => e.toJson()).toList(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}