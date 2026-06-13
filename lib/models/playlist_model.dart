class PlaylistSummary {
  final int id;
  final String title;
  final String? description;
  final String? coverImage;
  final int hymnsCount;
  final int completedCount;

  PlaylistSummary({
    required this.id,
    required this.title,
    this.description,
    this.coverImage,
    required this.hymnsCount,
    required this.completedCount,
  });

  factory PlaylistSummary.fromJson(Map<String, dynamic> json) {
    return PlaylistSummary(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      coverImage: json['cover_image'] as String?,
      hymnsCount: json['hymns_count'] as int,
      completedCount: json['completed_count'] as int,
    );
  }

  double get progress => hymnsCount > 0 ? completedCount / hymnsCount : 0.0;
  bool get isCompleted => hymnsCount > 0 && completedCount == hymnsCount;
}
