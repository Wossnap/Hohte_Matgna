// Comprehensive model for hymn details, including the base hymn and its split sections.

import 'hymn_model.dart';
import 'section_model.dart';
import 'lyric_segment_model.dart';

class HymnDetail {
  final Hymn hymn;
  final List<Section> sections;
  final List<LyricSegment> hymnLyricSegments;
  final Map<String, dynamic>? progress;
  final int? userPlays;
  final int? userPractices;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  HymnDetail({
    required this.hymn,
    required this.sections,
    required this.hymnLyricSegments,
    this.progress,
    this.userPlays,
    this.userPractices,
    this.createdAt,
    this.updatedAt,
  });

  factory HymnDetail.fromJson(Map<String, dynamic> json) {
    // Handle Inertia response structure: { component: '...', props: { hymn: {...}, sections: [...] } }
    final props = json['props'] is Map<String, dynamic> ? json['props'] : json;
    
    final hymnRaw = props['hymn'];
    
    // Support sections at root (Inertia/Web) or nested in hymn (API)
    final sectionsRaw = props['sections'] ?? (hymnRaw is Map ? hymnRaw['sections'] : null);
    
    // Support lyric_segments at root, or nested in hymn (API), with camelCase fallback
    final lyricSegmentsRaw = props['lyric_segments'] ?? 
                         props['lyricSegments'] ?? 
                         (hymnRaw is Map ? (hymnRaw['lyric_segments'] ?? hymnRaw['lyricSegments']) : null);
    
    final progress = props['progress'] is Map<String, dynamic> ? props['progress'] : null;
    
    // Extract hymn-level progress
    final hymnProgress = progress?['hymn'] is Map<String, dynamic> ? progress!['hymn'] : null;
    final userPlays = hymnProgress?['play_count'] is int ? hymnProgress!['play_count'] : (props['user_plays'] is int ? props['user_plays'] : null);
    final userPractices = hymnProgress?['practice_count'] is int ? hymnProgress!['practice_count'] : (props['user_practices'] is int ? props['user_practices'] : null);
    
    // Extract section progress map
    final sectionProgressMap = progress?['sections'] is Map<String, dynamic> ? Map<String, dynamic>.from(progress!['sections']) : null;
    
    return HymnDetail(
      hymn: Hymn.fromJson(hymnRaw is Map<String, dynamic> ? hymnRaw : {}, progress),
      sections: sectionsRaw != null && sectionsRaw is List
          ? sectionsRaw.map((e) => Section.fromJson(e, sectionProgressMap)).toList()
          : [],
      hymnLyricSegments: lyricSegmentsRaw != null && lyricSegmentsRaw is List
          ? lyricSegmentsRaw.map((e) => LyricSegment.fromJson(e)).toList()
          : [],
      progress: progress,
      userPlays: userPlays,
      userPractices: userPractices,
      createdAt: props['created_at'] != null ? DateTime.parse(props['created_at']) : null,
      updatedAt: props['updated_at'] != null ? DateTime.parse(props['updated_at']) : null,
    );
  }

  /// Get a consolidated string of all lyrics
  String get fullLyrics {
    // 1. Prefer explicit hymn content
    if (hymn.content != null && hymn.content!.trim().isNotEmpty) {
      return hymn.content!.trim();
    }

    // 2. Fallback to combining lyrics from sections
    if (sections.isNotEmpty) {
      final buffer = StringBuffer();
      for (var i = 0; i < sections.length; i++) {
        final section = sections[i];
        final sectionName = section.name.trim();
        final content = section.content?.trim() ?? '';
        
        if (sectionName.isNotEmpty) {
          buffer.writeln('[$sectionName]');
        }
        
        if (content.isNotEmpty) {
          buffer.writeln(content);
          if (i < sections.length - 1) buffer.writeln(); // Spacing
        } else if (section.lyricSegments.isNotEmpty) {
          // Fallback to segments if section content is null
          final segmentText = section.lyricSegments.map((s) => s.text).join(' ');
          buffer.writeln(segmentText);
          if (i < sections.length - 1) buffer.writeln(); 
        }
      }
      if (buffer.isNotEmpty) return buffer.toString().trim();
    }

    // 3. Fallback to flat segments
    if (hymnLyricSegments.isNotEmpty) {
      return hymnLyricSegments.map((s) => s.text).join(' ').trim();
    }

    return 'No lyrics available';
  }

  Map<String, dynamic> toJson() {
    return {
      'hymn': hymn.toJson(),
      'sections': sections.map((e) => e.toJson()).toList(),
      'lyric_segments': hymnLyricSegments.map((e) => e.toJson()).toList(),
      'progress': progress,
      'user_plays': userPlays,
      'user_practices': userPractices,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}