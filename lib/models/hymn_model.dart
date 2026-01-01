import 'category_model.dart';
import 'scale_model.dart';

class Hymn {
  final int id;
  final String title;
  final String? description;
  final Category? category;
  final Scale? scale;
  final int plays;
  final int practices;
  final String? audioUrl;
  final String? sheetMusicUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Hymn({
    required this.id,
    required this.title,
    this.description,
    this.category,
    this.scale,
    required this.plays,
    required this.practices,
    this.audioUrl,
    this.sheetMusicUrl,
    this.createdAt,
    this.updatedAt,
  });

  factory Hymn.fromJson(Map<String, dynamic> json) {
    return Hymn(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'],
      category: json['category'] is Map
          ? Category.fromJson(json['category'])
          : null,
      scale: json['scale'] is Map
          ? Scale.fromJson(json['scale'])
          : null,
      plays: json['plays'] ?? 0,
      practices: json['practices'] ?? 0,
      audioUrl: json['audio_url'],
      sheetMusicUrl: json['sheet_music_url'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }
}
