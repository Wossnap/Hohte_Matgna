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
    final hymnRaw = json['hymn'];
    Map<String, dynamic> hymnMap;
    if (hymnRaw is Map<String, dynamic>) {
      hymnMap = hymnRaw;
    } else if (hymnRaw is List && hymnRaw.isNotEmpty && hymnRaw[0] is Map<String, dynamic>) {
      hymnMap = hymnRaw[0] as Map<String, dynamic>;
    } else {
      hymnMap = {};
    }

    return HymnDetail(
      hymn: Hymn.fromJson(hymnMap),
        sections: json['sections'] != null && json['sections'] is List
          ? (json['sections'] as List).map((e) => Section.fromJson(e)).toList()
          : [],
      progress: json['progress'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
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