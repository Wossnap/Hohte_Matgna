/// Model representing a section of a hymn, containing multiple lyric segments.
import 'lyric_segment_model.dart';

class Section {
  final int id;
  final String name;
  final String? content;
  final String? audioUrl;
  final int plays;
  final int practices;
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
    required this.children,
    this.lyricSegments = const [],
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
    return html
        .replaceAll(RegExp(r'</?(p|br|div|h[1-6])[^>]*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\n\s*\n+'), '\n\n')
        .trim();
  }

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

    final segmentsRaw = map['effective_lyric_segments'] ?? map['segments'];
    List<LyricSegment> segmentsList = [];
    if (segmentsRaw is List) {
      for (final s in segmentsRaw) {
        segmentsList.add(LyricSegment.fromJson(s));
      }
    }

    return Section(
      id: map['id'] ?? 0,
      name: map['name'] ?? '',
      content: stripHtml(map['lyrics_content'] ?? map['content'] ?? map['text'] ?? map['lyrics']),
      audioUrl: handleUrl(map['audio_url'] ?? map['audio'] ?? map['audio_file'] ?? map['file_url']),
      plays: (map['plays'] as num?)?.toInt() ?? (map['play_count'] as num?)?.toInt() ?? 0,
      practices: (map['practices'] as num?)?.toInt() ?? (map['practice_count'] as num?)?.toInt() ?? 0,
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
      'children': children.map((e) => e.toJson()).toList(),
      'lyric_segments': lyricSegments.map((e) => e.toJson()).toList(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
