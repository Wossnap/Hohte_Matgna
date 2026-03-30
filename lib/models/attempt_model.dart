/// Model representing a user's practice attempt, including score and feedback.
class Attempt {
  final int id;
  final String playableType;
  final int playableId;
  final double? score;
  final String? feedback;
  final Map<String, dynamic>? analysis;
  final String status; // 'pending', 'processing', 'completed', 'failed'
  final bool isSaved;
  final String? recordingPath;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Attempt({
    required this.id,
    required this.playableType,
    required this.playableId,
    this.score,
    this.feedback,
    this.analysis,
    required this.status,
    required this.isSaved,
    this.recordingPath,
    required this.createdAt,
    this.updatedAt,
  });

  factory Attempt.fromJson(Map<String, dynamic> json) {
    return Attempt(
      id: json['id'] ?? 0,
      playableType: json['playable_type'] ?? '',
      playableId: json['playable_id'] ?? 0,
      score: json['score'] != null ? (json['score'] as num).toDouble() : null,
      feedback: json['feedback'],
      analysis: json['analysis'] is Map<String, dynamic> ? Map<String, dynamic>.from(json['analysis']) : null,
      status: json['status'] ?? 'pending',
      isSaved: json['is_saved'] ?? false,
      recordingPath: json['recording_path'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'playable_type': playableType,
      'playable_id': playableId,
      'score': score,
      'feedback': feedback,
      'analysis': analysis,
      'status': status,
      'is_saved': isSaved,
      'recording_path': recordingPath,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  bool get isCompleted => status == 'completed';
  bool get isPending => status == 'pending' || status == 'processing';
  bool get hasFailed => status == 'failed';
}
