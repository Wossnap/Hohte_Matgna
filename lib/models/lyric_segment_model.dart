/// Model representing a specific segment of lyrics with timing information.
class LyricSegment {
  final int id;
  final int hymnId;
  final int? sectionId;
  final int startMs;
  final int endMs;
  final String text;
  final double startSeconds;
  final double endSeconds;

  LyricSegment({
    required this.id,
    required this.hymnId,
    this.sectionId,
    required this.startMs,
    required this.endMs,
    required this.text,
    required this.startSeconds,
    required this.endSeconds,
  });

  factory LyricSegment.fromJson(Map<String, dynamic> json) {
    return LyricSegment(
      id: (json['id'] as num?)?.toInt() ?? 0,
      hymnId: (json['hymn_id'] as num?)?.toInt() ?? 0,
      sectionId: (json['section_id'] as num?)?.toInt(),
      startMs: (json['start_ms'] as num?)?.toInt() ?? 0,
      endMs: (json['end_ms'] as num?)?.toInt() ?? 0,
      text: json['text'] ?? '',
      startSeconds: (json['start_seconds'] ?? ((json['start_ms'] as num?)?.toDouble() ?? 0.0) / 1000.0).toDouble(),
      endSeconds: (json['end_seconds'] ?? ((json['end_ms'] as num?)?.toDouble() ?? 0.0) / 1000.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hymn_id': hymnId,
      'section_id': sectionId,
      'start_ms': startMs,
      'end_ms': endMs,
      'text': text,
      'start_seconds': startSeconds,
      'end_seconds': endSeconds,
    };
  }
}
