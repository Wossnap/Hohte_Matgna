// Provider for fetching and managing the list of hymns, including filtering and searching.

import 'package:flutter/material.dart';
import '../models/hymn_model.dart';
import '../models/pagination_model.dart';
import '../services/hymn_service.dart';

class HymnProvider with ChangeNotifier {
  final HymnService _hymnService = HymnService();

  // Data
  List<Hymn> _hymns = [];
  List<Hymn> _topHymns = [];
  Pagination<Hymn>? _pagination;

  // State
  bool _isLoading = false;
  bool _loadingMore = false;
  bool _loadingTop = false;
  String? _error;

  // Filters
  String _searchQuery = '';
  int? _selectedCategoryId;
  int? _selectedScaleId;
  String? _sortBy;

  // Getters
  List<Hymn> get hymns => _hymns;
  List<Hymn> get topHymns => _topHymns;
  Pagination<Hymn>? get pagination => _pagination;
  bool get isLoading => _isLoading;
  bool get loadingMore => _loadingMore;
  bool get loadingTop => _loadingTop;
  String? get error => _error;
  bool get hasMore => _pagination?.hasNextPage ?? false;

  String get searchQuery => _searchQuery;
  int? get selectedCategoryId => _selectedCategoryId;
  int? get selectedScaleId => _selectedScaleId;
  String? get sortBy => _sortBy;

  bool _isAuthInitialized = false;

  HymnProvider() {
    // Initial load will be handled by update() once AuthProvider is ready
  }

  /// Called by ChangeNotifierProxyProvider when AuthProvider changes
  void update(bool isAuthenticated) {
    if (isAuthenticated && !_isAuthInitialized) {
      _isAuthInitialized = true;
      loadHymns();
      loadTopHymns();
    } else if (!isAuthenticated) {
      _isAuthInitialized = false;
      _hymns = [];
      _topHymns = [];
      _pagination = null;
      notifyListeners();
    }
  }

  /// Load hymns (initial load or load more)
  Future<void> loadHymns({bool loadMore = false}) async {
    if (loadMore && (_loadingMore || !hasMore)) return;
    
    // In current backend, dashboard requires auth
    if (!_isAuthInitialized) {
      debugPrint('HymnProvider: Skipping loadHymns (not authenticated)');
      return;
    }

    try {
      _error = null;

      if (loadMore) {
        _loadingMore = true;
      } else {
        _isLoading = true;
        _pagination = null; // Clear pagination on fresh load
      }

      notifyListeners();

      final int pageToLoad = loadMore
          ? (_pagination?.currentPage ?? 0) + 1
          : 1;

      final Pagination<Hymn> result = await _hymnService.getHymns(
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        categoryId: _selectedCategoryId,
        scaleId: _selectedScaleId,
        sort: _sortBy,
        page: pageToLoad,
      );

      if (loadMore) {
        _hymns.addAll(result.data);
      } else {
        _hymns = result.data;
      }

      _pagination = result;
    } catch (e) {
      _error = e.toString();
      if (!loadMore) {
        _hymns = [];
        _pagination = null;
      }
    } finally {
      _isLoading = false;
      _loadingMore = false;
      notifyListeners();
    }
  }

  /// Load top hymns for Daily Focus slideshow
  Future<void> loadTopHymns() async {
    try {
      _loadingTop = true;
      notifyListeners();

      // website uses ?sort=plays to get trending hymns
      final Pagination<Hymn> result = await _hymnService.getHymns(
        sort: 'plays',
        page: 1,
      );

      _topHymns = result.data.take(5).toList(); // Take top 5 for slideshow
    } catch (e) {
      debugPrint('Error loading top hymns: $e');
    } finally {
      _loadingTop = false;
      notifyListeners();
    }
  }

  /// Search
  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    _pagination = null; // Reset pagination
    loadHymns();
  }

  /// Set Category Filter
  void setCategoryId(int? categoryId) {
    if (_selectedCategoryId == categoryId) return;
    _selectedCategoryId = categoryId;
    _pagination = null; // Reset pagination
    loadHymns();
  }

  /// Set Scale Filter
  void setScaleId(int? scaleId) {
    if (_selectedScaleId == scaleId) return;
    _selectedScaleId = scaleId;
    _pagination = null; // Reset pagination
    loadHymns();
  }

  /// Set Sort
  void setSort(String? sort) {
    if (_sortBy == sort) return;
    _sortBy = sort;
    _pagination = null; // Reset pagination
    loadHymns();
  }

  /// Clear filters
  void clearFilters() {
    _searchQuery = '';
    _selectedCategoryId = null;
    _selectedScaleId = null;
    _sortBy = null;
    loadHymns();
  }

  /// Pull-to-refresh
  /// Patches a hymn's completion state in the already-loaded lists.
  ///
  /// Used when returning from the detail screen so the completion tick appears
  /// immediately. A full refresh would work too, but it resets pagination and
  /// the user's scroll position.
  void applyHymnCompletion(int hymnId, bool isCompleted) {
    var changed = false;
    for (final list in [_hymns, _topHymns]) {
      for (final hymn in list) {
        if (hymn.id == hymnId && hymn.isCompleted != isCompleted) {
          hymn.isCompleted = isCompleted;
          changed = true;
        }
      }
    }
    if (changed) notifyListeners();
  }

  Future<void> refresh() async {
    await loadHymns();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Get hymn by ID
  Hymn? getHymnById(int id) {
    try {
      return _hymns.firstWhere((h) => h.id == id);
    } catch (e) {
      return null;
    }
  }
}
