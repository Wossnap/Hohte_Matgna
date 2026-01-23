/// Model representing a user's practice attempt, including score and feedback.
class Attempt {
  final int id;
  final String playableType;
  final int playableId;
  final double? score;
  final String? feedback;
  final String status; // 'pending', 'processing', 'completed', 'failed'
  final DateTime createdAt;
  final DateTime? updatedAt;

  Attempt({
    required this.id,
    required this.playableType,
    required this.playableId,
    this.score,
    this.feedback,
    required this.status,
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
      status: json['status'] ?? 'pending',
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
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  bool get isCompleted => status == 'completed';
  bool get isPending => status == 'pending' || status == 'processing';
  bool get hasFailed => status == 'failed';
}
