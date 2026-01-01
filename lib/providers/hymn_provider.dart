import 'package:flutter/material.dart';
import '../models/hymn_model.dart';
import '../models/pagination_model.dart';
import '../services/hymn_service.dart';

class HymnProvider with ChangeNotifier {
  final HymnService _hymnService = HymnService();

  // Data
  List<Hymn> _hymns = [];
  Pagination<Hymn>? _pagination;

  // State
  bool _isLoading = false;
  bool _loadingMore = false;
  String? _error;

  // Filters
  String _searchQuery = '';
  int? _selectedCategoryId;
  int? _selectedScaleId;
  String? _sortBy;

  // Getters
  List<Hymn> get hymns => _hymns;
  Pagination<Hymn>? get pagination => _pagination;
  bool get isLoading => _isLoading;
  bool get loadingMore => _loadingMore;
  String? get error => _error;
  bool get hasMore => _pagination?.hasNextPage ?? false;

  String get searchQuery => _searchQuery;
  int? get selectedCategoryId => _selectedCategoryId;
  int? get selectedScaleId => _selectedScaleId;
  String? get sortBy => _sortBy;

  HymnProvider() {
    loadHymns();
  }

  /// Load hymns (initial load or load more)
  Future<void> loadHymns({bool loadMore = false}) async {
    if (loadMore && (_loadingMore || !hasMore)) return;

    try {
      _error = null;

      if (loadMore) {
        _loadingMore = true;
      } else {
        _isLoading = true;
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

  /// Search
  void setSearchQuery(String query) {
    _searchQuery = query;
    loadHymns();
  }

  /// Filters
  void setFilters({int? categoryId, int? scaleId, String? sort}) {
    _selectedCategoryId = categoryId;
    _selectedScaleId = scaleId;
    _sortBy = sort;
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
