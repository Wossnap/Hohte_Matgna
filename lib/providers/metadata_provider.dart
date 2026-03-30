// Provider for fetching and caching static metadata like categories and scales.

import 'package:flutter/material.dart';
import '../models/category_model.dart';
import '../models/scale_model.dart';
import '../services/metadata_service.dart';

class MetadataProvider with ChangeNotifier {
  final MetadataService _metadataService = MetadataService();
  
  List<Category> _categories = [];
  List<Scale> _scales = [];
  bool _isLoading = true;
  String? _error;

  List<Category> get categories => _categories;
  List<Scale> get scales => _scales;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool _isAuthInitialized = false;

  MetadataProvider() {
    // Initial load will be handled by update()
  }

  void update(bool isAuthenticated) {
    if (isAuthenticated && !_isAuthInitialized) {
      _isAuthInitialized = true;
      _loadMetadata();
    } else if (!isAuthenticated) {
      _isAuthInitialized = false;
      _categories = [];
      _scales = [];
      notifyListeners();
    }
  }

  Future<void> _loadMetadata() async {
    if (!_isAuthInitialized) return;
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final data = await _metadataService.getDashboardMetadata();
      
      _categories = data['categories'] as List<Category>;
      _scales = data['scales'] as List<Scale>;
      
      debugPrint('Loaded ${_categories.length} categories');
      debugPrint('Loaded ${_scales.length} scales');
      
      _error = null;
    } catch (e) {
      _error = e.toString();
      _categories = [];
      _scales = [];
      
      debugPrint('Error loading metadata: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Retrieves a category by its [id].
  Category? getCategoryById(int? id) {
    if (id == null) return null;
    try {
      return _categories.firstWhere((category) => category.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Retrieves a scale by its [id].
  Scale? getScaleById(int? id) {
    if (id == null) return null;
    try {
      return _scales.firstWhere((scale) => scale.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Refreshes metadata from the backend.
  void refresh() {
    _loadMetadata();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}