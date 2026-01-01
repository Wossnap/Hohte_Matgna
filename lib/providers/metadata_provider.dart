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

  MetadataProvider() {
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      // Load categories and scales in parallel
      final categoriesFuture = _metadataService.getCategories();
      final scalesFuture = _metadataService.getScales();
      
      final categoriesData = await categoriesFuture;
      final scalesData = await scalesFuture;
      
      _categories = categoriesData;
      _scales = scalesData;
      
      // Print for debugging (as per requirement)
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

  Category? getCategoryById(int? id) {
    if (id == null) return null;
    try {
      return _categories.firstWhere((category) => category.id == id);
    } catch (e) {
      return null;
    }
  }

  Scale? getScaleById(int? id) {
    if (id == null) return null;
    try {
      return _scales.firstWhere((scale) => scale.id == id);
    } catch (e) {
      return null;
    }
  }

  void refresh() {
    _loadMetadata();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}