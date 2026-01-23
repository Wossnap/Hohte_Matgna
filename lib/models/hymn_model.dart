/// Core model representing a hymn, including metadata like title, plays, and practices.
import 'category_model.dart';
import 'scale_model.dart';

class Hymn {
  final int id;
  final String title;
  final String? description;
  final String? content; // Added for lyrics
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
    this.content,
    this.category,
    this.scale,
    required this.plays,
    required this.practices,
    this.audioUrl,
    this.sheetMusicUrl,
    this.createdAt,
    this.updatedAt,
  });

  static String? handleUrl(dynamic url) {
    if (url == null || url is! String) return null;
    if (url.startsWith('http')) return url;
    const baseUrl = 'https://hohte-matgna.batelew.com/storage';
    final path = url.startsWith('/') ? url : '/$url';
    return '$baseUrl$path';
  }

  static String? stripHtml(String? html) {
    if (html == null) return null;
    // Replace block tags with newlines, remove other tags, keep existing newlines
    return html
        .replaceAll(RegExp(r'</?(p|br|div|h[1-6])[^>]*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\n\s*\n+'), '\n\n') // Normalize multiple newlines
        .trim();
  }

  factory Hymn.fromJson(Map<String, dynamic> json) {

    final id = json['id'] ?? 0;
    final title = json['title'] ?? json['name'] ?? '';
    final audioUrlRaw = json['audio_url'] ?? json['audio'] ?? json['audio_file'] ?? json['file_url'] ?? json['media_url'] ?? json['url'] ?? json['path'];
    final audioUrl = handleUrl(audioUrlRaw);
    
    var contentRaw = json['lyrics_content'] ?? json['content'] ?? json['lyrics'] ?? json['text'] ?? json['body'] ?? json['description'];
    
    // Treat empty string or non-string as null for easier fallbacks
    if (contentRaw is! String || contentRaw.trim().isEmpty) {
      contentRaw = null;
    } else {
      contentRaw = stripHtml(contentRaw);
    }
    
    // Log audio URL status if needed

    return Hymn(
      id: id,
      title: title,
      description: json['description'] ?? json['desc'],
      content: contentRaw,
      category: json['category'] is Map
          ? Category.fromJson(json['category'])
          : null,
      scale: json['scale'] is Map
          ? Scale.fromJson(json['scale'])
          : null,
      plays: (json['plays'] as num?)?.toInt() ?? (json['play_count'] as num?)?.toInt() ?? (json['plays_count'] as num?)?.toInt() ?? 0,
      practices: (json['practices'] as num?)?.toInt() ?? (json['practice_count'] as num?)?.toInt() ?? (json['practices_count'] as num?)?.toInt() ?? 0,
      audioUrl: audioUrl,
      sheetMusicUrl: handleUrl(json['sheet_music_url'] ?? json['sheet_music']),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'content': content,
      'category': category?.toJson(),
      'scale': scale?.toJson(),
      'plays': plays,
      'practices': practices,
      'audio_url': audioUrl,
      'sheet_music_url': sheetMusicUrl,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
