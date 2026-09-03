// Model representing a section of a hymn, containing multiple lyric segments.

import 'lyric_segment_model.dart';
import '../core/utils/url_utils.dart';

class Section {
  final int id;
  final String name;
  final String? content;
  final String? audioUrl;
  final int plays;
  final int practices;
  final double? bestScore;
  final int? playMinutes;
  /// Server-side completion state from `user_progress.is_completed`.
  final bool isCompleted;
  final int order;
  final double? startTime;
  final double? endTime;
  final int? duration;
  final List<dynamic>? comparisonBreakpoints;
  final List<Section> children;
  final List<LyricSegment> lyricSegments;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Section({
    required this.id,
    required this.name,
    this.content,
    this.audioUrl,
    required this.plays,
    required this.practices,
    this.bestScore,
    this.playMinutes,
    this.isCompleted = false,
    required this.order,
    this.startTime,
    this.endTime,
    this.duration,
    this.comparisonBreakpoints,
    required this.children,
    this.lyricSegments = const [],
    this.createdAt,
    this.updatedAt,
  });

  static String? handleUrl(dynamic url) {
    if (url == null || url is! String) return null;
    return UrlUtils.resolveStorageUrl(url);
  }

  static String? stripHtml(String? html) {
    if (html == null) return null;
    return html
        .replaceAll(RegExp(r'</?(p|br|div|h[1-6])[^>]*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\n\s*\n+'), '\n\n')
        .trim();
  }

  factory Section.fromJson(dynamic json, [Map<String, dynamic>? progressSections]) {
    Map<String, dynamic> map;
    if (json is Map<String, dynamic>) {
      map = json;
    } else if (json is List && json.isNotEmpty && json[0] is Map<String, dynamic>) {
      map = json[0] as Map<String, dynamic>;
    } else {
      map = {};
    }

    final id = map['id'] is num ? (map['id'] as num).toInt() : int.parse(map['id'].toString());
    
    // Extract progress data if available
    final progress = progressSections?[id.toString()];
    final int plays = progress?['play_count'] ?? map['play_count'] ?? 0;
    final int practices = progress?['practice_count'] ?? map['practice_count'] ?? 0;
    final double? bestScore = progress?['best_score'] != null ? (progress!['best_score'] as num).toDouble() : null;
    final int? playMinutes = progress?['play_minutes'] is int ? progress!['play_minutes'] : null;
    final bool isCompleted = progress?['is_completed'] == true;

    final childrenRaw = map['children'];
    List<Section> childrenList = [];
    if (childrenRaw is List) {
      for (final c in childrenRaw) {
        childrenList.add(Section.fromJson(c, progressSections));
      }
      // Match the web app, which loads child sections `->orderBy('order')` at
      // every nesting level (HymnPracticeController). The Flutter API returns
      // them in default id order, so sort here to keep the order correct.
      childrenList.sort((a, b) => a.order.compareTo(b.order));
    }

    final segmentsRaw = map['effective_lyric_segments'] ?? map['segments'] ?? map['lyric_segments'];
    List<LyricSegment> segmentsList = [];
    if (segmentsRaw is List) {
      for (final s in segmentsRaw) {
        segmentsList.add(LyricSegment.fromJson(s));
      }
    }

    return Section(
      id: id,
      name: map['name'] ?? '',
      content: stripHtml(map['lyrics_content'] ?? map['content'] ?? map['lyrics']),
      audioUrl: handleUrl(map['audio_url'] ?? map['audio']),
      plays: plays,
      practices: practices,
      bestScore: bestScore,
      playMinutes: playMinutes,
      isCompleted: isCompleted,
      order: map['order'] != null ? (map['order'] is num ? (map['order'] as num).toInt() : int.parse(map['order'].toString())) : 0,
      startTime: map['start_time'] != null ? (map['start_time'] is num ? (map['start_time'] as num).toDouble() : double.parse(map['start_time'].toString())) : null,
      endTime: map['end_time'] != null ? (map['end_time'] is num ? (map['end_time'] as num).toDouble() : double.parse(map['end_time'].toString())) : null,
      duration: map['duration'] is num ? (map['duration'] as num).toInt() : null,
      comparisonBreakpoints: map['comparison_breakpoints'] is List ? List<dynamic>.from(map['comparison_breakpoints']) : null,
      children: childrenList,
      lyricSegments: segmentsList,
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
      'is_completed': isCompleted,
      'order': order,
      'start_time': startTime,
      'end_time': endTime,
      'duration': duration,
      'comparison_breakpoints': comparisonBreakpoints,
      'children': children.map((e) => e.toJson()).toList(),
      'lyric_segments': lyricSegments.map((e) => e.toJson()).toList(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
