import 'dart:convert';
import 'package:flutter/foundation.dart' hide Category;
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/category_model.dart';
import '../models/scale_model.dart';

class MetadataService {
  /// Fetches all metadata (categories and scales) needed for the dashboard.
  /// 
  /// Attempts to use dedicated endpoints first, with a fallback to the hymns index
  /// props (standard Inertia pattern).
  Future<Map<String, List<dynamic>>> getDashboardMetadata() async {
    try {
      // Try dedicated endpoints first for better modularity
      try {
        final catResponse = await ApiClient.get(ApiEndpoints.categories);
        final scaleResponse = await ApiClient.get(ApiEndpoints.scales);

        if (catResponse.statusCode == 200 && scaleResponse.statusCode == 200) {
          final catData = jsonDecode(catResponse.body);
          final scaleData = jsonDecode(scaleResponse.body);

          final cats = (catData is List ? catData : (catData['data'] ?? [])) as List;
          final scales = (scaleData is List ? scaleData : (scaleData['data'] ?? [])) as List;

          return {
            'categories': cats.map((e) => Category.fromJson(e)).toList(),
            'scales': scales.map((e) => Scale.fromJson(e)).toList(),
          };
        }
      } catch (e) {
        debugPrint('Dedicated metadata endpoints failed, falling back to dashboard props: $e');
      }

      // Fallback to dashboard props pattern
      final response = await ApiClient.get(ApiEndpoints.hymns);
      
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final props = decoded['props'] is Map<String, dynamic> ? decoded['props'] : decoded;
        
        final catsRaw = props['categories'] ?? [];
        final scalesRaw = props['scales'] ?? [];

        return {
          'categories': (catsRaw as List).map((item) => Category.fromJson(item)).toList(),
          'scales': (scalesRaw as List).map((item) => Scale.fromJson(item)).toList(),
        };
      } else {
        throw Exception('Failed to load dashboard metadata');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Retrieves categories using the unified metadata fetch.
  Future<List<Category>> getCategories() async => (await getDashboardMetadata())['categories'] as List<Category>;
  
  /// Retrieves scales using the unified metadata fetch.
  Future<List<Scale>> getScales() async => (await getDashboardMetadata())['scales'] as List<Scale>;
}