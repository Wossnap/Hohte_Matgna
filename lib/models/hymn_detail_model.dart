/// Comprehensive model for hymn details, including the base hymn and its split sections.
import 'hymn_model.dart';
import 'section_model.dart';

class HymnDetail {
  final Hymn hymn;
  final List<Section> sections;
  final Map<String, dynamic>? progress;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  HymnDetail({
    required this.hymn,
    required this.sections,
    this.progress,
    this.createdAt,
    this.updatedAt,
  });

  factory HymnDetail.fromJson(Map<String, dynamic> json) {
    // Handle potential 'data' wrapper from Laravel Resource
    final data = json['data'] is Map<String, dynamic> ? json['data'] : json;
    
    final hymnRaw = data['hymn'];
    Map<String, dynamic> hymnMap;
    if (hymnRaw is Map<String, dynamic>) {
      hymnMap = hymnRaw;
    } else if (hymnRaw is List && hymnRaw.isNotEmpty && hymnRaw[0] is Map<String, dynamic>) {
      hymnMap = hymnRaw[0] as Map<String, dynamic>;
    } else {
      // If hymn is at root of data
      hymnMap = data;
    }

    // Try to find sections in data['sections'] or data['hymn']['sections']
    var sectionsRaw = data['sections'] ?? hymnMap['sections'];
    
    return HymnDetail(
      hymn: Hymn.fromJson(hymnMap),
      sections: sectionsRaw != null && sectionsRaw is List
          ? sectionsRaw.map((e) => Section.fromJson(e as Map<String, dynamic>)).toList()
          : [],
      progress: data['progress'],
      createdAt: data['created_at'] != null ? DateTime.parse(data['created_at']) : null,
      updatedAt: data['updated_at'] != null ? DateTime.parse(data['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hymn': hymn.toJson(),
      'sections': sections.map((e) => e.toJson()).toList(),
      'progress': progress,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}