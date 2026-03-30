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
    final startMs = json['start_ms'] is num ? (json['start_ms'] as num).toInt() : int.parse(json['start_ms'].toString());
    final endMs = json['end_ms'] is num ? (json['end_ms'] as num).toInt() : int.parse(json['end_ms'].toString());
    return LyricSegment(
      id: json['id'] is num ? (json['id'] as num).toInt() : int.parse(json['id'].toString()),
      hymnId: json['hymn_id'] is num ? (json['hymn_id'] as num).toInt() : int.parse(json['hymn_id'].toString()),
      sectionId: json['section_id'] != null ? (json['section_id'] is num ? (json['section_id'] as num).toInt() : int.parse(json['section_id'].toString())) : null,
      startMs: startMs,
      endMs: endMs,
      text: json['text'] ?? '',
      startSeconds: json['start_seconds'] is num ? (json['start_seconds'] as num).toDouble() : (json['start_seconds'] != null ? double.parse(json['start_seconds'].toString()) : startMs.toDouble() / 1000.0),
      endSeconds: json['end_seconds'] is num ? (json['end_seconds'] as num).toDouble() : (json['end_seconds'] != null ? double.parse(json['end_seconds'].toString()) : endMs.toDouble() / 1000.0),
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
