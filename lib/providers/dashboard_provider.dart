import 'package:flutter/material.dart';
import '../models/hymn_model.dart';
import '../models/playlist_model.dart';
import '../services/dashboard_service.dart';

class DashboardProvider with ChangeNotifier {
  final DashboardService _service = DashboardService();

  List<Hymn> _continueHymns = [];
  List<Hymn> _recentHymns = [];
  List<PlaylistSummary> _playlists = [];
  bool _isLoading = false;
  bool _isAuthInitialized = false;

  List<Hymn> get continueHymns => _continueHymns;
  List<Hymn> get recentHymns => _recentHymns;
  List<PlaylistSummary> get playlists => _playlists;
  bool get isLoading => _isLoading;

  void update(bool isAuthenticated) {
    if (isAuthenticated && !_isAuthInitialized) {
      _isAuthInitialized = true;
      load();
    } else if (!isAuthenticated) {
      _isAuthInitialized = false;
      _continueHymns = [];
      _recentHymns = [];
      _playlists = [];
      notifyListeners();
    }
  }

  Future<void> load() async {
    try {
      _isLoading = true;
      notifyListeners();
      final data = await _service.getDashboardData();
      _continueHymns = data.continueHymns;
      _recentHymns = data.recentHymns;
      _playlists = data.playlists;
    } catch (e) {
      debugPrint('DashboardProvider error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load();
}
