import 'dart:convert';
import '../core/api/api_client.dart';
import '../models/hymn_model.dart';
import '../models/playlist_model.dart';

class DashboardData {
  final List<Hymn> continueHymns;
  final List<Hymn> recentHymns;
  final List<PlaylistSummary> playlists;

  DashboardData({
    required this.continueHymns,
    required this.recentHymns,
    required this.playlists,
  });
}

class DashboardService {
  Future<DashboardData> getDashboardData() async {
    final response = await ApiClient.get('/dashboard');
    if (response.statusCode != 200) {
      throw Exception('Failed to load dashboard: ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return DashboardData(
      continueHymns: (data['continueHymns'] as List)
          .map((h) => Hymn.fromJson(h as Map<String, dynamic>))
          .toList(),
      recentHymns: (data['recentHymns'] as List)
          .map((h) => Hymn.fromJson(h as Map<String, dynamic>))
          .toList(),
      playlists: (data['playlists'] as List)
          .map((p) => PlaylistSummary.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }
}
