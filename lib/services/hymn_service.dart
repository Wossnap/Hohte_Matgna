import 'dart:convert';
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

    if (response.statusCode != 200) {
      throw Exception('Failed to load hymns');
    }

    final decoded = jsonDecode(response.body);

    // ✅ Laravel-style paginated response
    if (decoded is Map<String, dynamic>) {
      return Pagination<Hymn>.fromJson(decoded, (json) => Hymn.fromJson(json));
    }

    // ✅ Plain list fallback
    if (decoded is List) {
      final hymns = decoded
          .whereType<Map<String, dynamic>>()
          .map((json) => Hymn.fromJson(json))
          .toList();

      return Pagination<Hymn>(
        data: hymns,
        currentPage: 1,
        lastPage: 1,
        total: hymns.length,
        perPage: hymns.length,
      );
    }

    throw Exception('Unexpected hymns response format');
  }
}
