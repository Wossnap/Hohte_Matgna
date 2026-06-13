// Core model representing a hymn, including metadata like title, plays, and practices.

import 'category_model.dart';
import 'scale_model.dart';
import '../core/utils/url_utils.dart';

class Hymn {
  final int id;
  final String title;
  final String? description;
  final String? content; // Added for lyrics
  final String? gameContent;
  final Category? category;
  final Scale? scale;
  final int plays;
  final int practices;
  final int totalPlays;
  final int totalPractices;
  final int order;
  final String? audioUrl;
  final String? sheetMusicUrl;
  final List<dynamic>? comparisonBreakpoints;
  final int? bpm;
  final List<double>? beatTimestamps;
  final int? duration;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isCompleted;

  Hymn({
    required this.id,
    required this.title,
    this.description,
    this.content,
    this.gameContent,
    this.category,
    this.scale,
    required this.plays,
    required this.practices,
    required this.totalPlays,
    required this.totalPractices,
    required this.order,
    this.audioUrl,
    this.sheetMusicUrl,
    this.comparisonBreakpoints,
    this.bpm,
    this.beatTimestamps,
    this.duration,
    this.createdAt,
    this.updatedAt,
    this.isCompleted = false,
  });

  static String? handleUrl(dynamic url) {
    if (url == null || url is! String) return null;
    return UrlUtils.resolveStorageUrl(url);
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

  factory Hymn.fromJson(Map<String, dynamic> json, [Map<String, dynamic>? progress]) {
    // Handle potential Inertia/Laravel Resource wrappers
    final data = json['data'] is Map<String, dynamic> ? json['data'] : json;

    final id = data['id'] is num ? (data['id'] as num).toInt() : int.parse(data['id'].toString());
    final title = data['title'] ?? '';
    final audioUrlRaw = data['audio_url'] ?? data['audio'];
    final audioUrl = handleUrl(audioUrlRaw);
    
    var contentRaw = data['lyrics_content'] ?? data['lyrics'] ?? data['content'];
    
    if (contentRaw is! String || contentRaw.trim().isEmpty) {
      contentRaw = null;
    } else {
      contentRaw = stripHtml(contentRaw);
    }

    // Extract progress data if available
    final hymnProgress = progress?['hymn'] ?? progress;
    final int plays = hymnProgress?['play_count'] ?? data['hymn_play_count'] ?? data['plays'] ?? 0;
    final int practices = hymnProgress?['practice_count'] ?? data['hymn_practice_count'] ?? data['practices'] ?? 0;
    
    return Hymn(
      id: id,
      title: title,
      description: data['description'],
      content: contentRaw,
      gameContent: data['game_content'],
      category: data['category'] is Map
          ? Category.fromJson(data['category'])
          : null,
      scale: data['scale'] is Map
          ? Scale.fromJson(data['scale'])
          : null,
      plays: plays,
      practices: practices,
      totalPlays: data['plays'] != null ? (data['plays'] is num ? (data['plays'] as num).toInt() : int.parse(data['plays'].toString())) : 0,
      totalPractices: data['practices'] != null ? (data['practices'] is num ? (data['practices'] as num).toInt() : int.parse(data['practices'].toString())) : 0,
      order: (data['order'] as num?)?.toInt() ?? 0,
      audioUrl: audioUrl,
      sheetMusicUrl: handleUrl(data['sheet_music_url'] ?? data['sheet_music']),
      comparisonBreakpoints: data['comparison_breakpoints'] is List ? List<dynamic>.from(data['comparison_breakpoints']) : null,
      bpm: data['bpm'] is num ? (data['bpm'] as num).toInt() : null,
      beatTimestamps: data['beat_timestamps'] is List ? (data['beat_timestamps'] as List).map((e) => (e as num).toDouble()).toList() : null,
      duration: data['duration'] is num ? (data['duration'] as num).toInt() : null,
      createdAt: data['created_at'] != null
          ? DateTime.parse(data['created_at'])
          : null,
      updatedAt: data['updated_at'] != null
          ? DateTime.parse(data['updated_at'])
          : null,
      isCompleted: data['is_completed'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'content': content,
      'game_content': gameContent,
      'category': category?.toJson(),
      'scale': scale?.toJson(),
      'plays': plays,
      'practices': practices,
      'order': order,
      'audio_url': audioUrl,
      'sheet_music_url': sheetMusicUrl,
      'comparison_breakpoints': comparisonBreakpoints,
      'bpm': bpm,
      'beat_timestamps': beatTimestamps,
      'duration': duration,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
