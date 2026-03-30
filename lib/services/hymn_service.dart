import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/hymn_model.dart';
import '../models/pagination_model.dart';

class HymnService {
  Future<Pagination<Hymn>> getHymns({
    String? search,
    int? categoryId,
    int? scaleId,
    String? sort,
    int page = 1,
  }) async {
    final response = await ApiClient.get(
      ApiEndpoints.hymns,
      queryParams: {
        'page': page,
        if (search != null) 'search': search,
        if (categoryId != null) 'category': categoryId,
        if (scaleId != null) 'scale': scaleId,
        if (sort != null) 'sort': sort,
      },
    );

    debugPrint('HymnService response status: ${response.statusCode}');
    debugPrint('HymnService response body length: ${response.body.length}');
    if (response.statusCode != 200) {
      debugPrint('HymnService error response: ${response.body}');
      throw Exception('Failed to load hymns: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);

    // ✅ Laravel/Inertia paginated response
    if (decoded is Map<String, dynamic>) {
      return Pagination<Hymn>.fromJson(decoded, (json) => Hymn.fromJson(json));
    }

    throw Exception('Unexpected hymns response format');
  }
}
