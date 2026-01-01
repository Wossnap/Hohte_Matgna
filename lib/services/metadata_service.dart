import 'dart:convert';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/category_model.dart';
import '../models/scale_model.dart';

class MetadataService {
  Future<List<Category>> getCategories() async {
    try {
      final response = await ApiClient.get(ApiEndpoints.categories);
      
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> dataList = [];

        if (decoded is List) {
          dataList = decoded;
        } else if (decoded is Map<String, dynamic>) {
          if (decoded['data'] is List) {
            dataList = decoded['data'];
          } else if (decoded['categories'] is List) {
            dataList = decoded['categories'];
          }
        }

        final List<Category> categories = [];
        for (final item in dataList) {
          if (item is Map<String, dynamic>) {
            categories.add(Category.fromJson(item));
          } else if (item is List && item.isNotEmpty && item[0] is Map<String, dynamic>) {
            categories.add(Category.fromJson(item[0] as Map<String, dynamic>));
          } else {
            // unsupported shape; skip
          }
        }
        return categories;
      } else {
        throw Exception('Failed to load categories');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Scale>> getScales() async {
    try {
      final response = await ApiClient.get(ApiEndpoints.scales);
      
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> dataList = [];

        if (decoded is List) {
          dataList = decoded;
        } else if (decoded is Map<String, dynamic>) {
          if (decoded['data'] is List) {
            dataList = decoded['data'];
          } else if (decoded['scales'] is List) {
            dataList = decoded['scales'];
          }
        }

        final List<Scale> scales = [];
        for (final item in dataList) {
          if (item is Map<String, dynamic>) {
            scales.add(Scale.fromJson(item));
          } else if (item is List && item.isNotEmpty && item[0] is Map<String, dynamic>) {
            scales.add(Scale.fromJson(item[0] as Map<String, dynamic>));
          } else {
            // unsupported shape; skip
          }
        }
        return scales;
      } else {
        throw Exception('Failed to load scales');
      }
    } catch (e) {
      rethrow;
    }
  }
}