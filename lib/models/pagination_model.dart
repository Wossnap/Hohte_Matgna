/// Generic model for handling paginated API responses.
class Pagination<T> {
  final int currentPage;
  final int lastPage;
  final int total;
  final int perPage;
  final List<T> data;

  Pagination({
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.perPage,
    required this.data,
  });

  /// Returns true if there are more pages to fetch
  bool get hasNextPage => currentPage < lastPage;

  /// Create Pagination from JSON returned by Laravel API
  factory Pagination.fromJson(
      Map<String, dynamic> json, T Function(Map<String, dynamic>) fromJson) {
    final List<dynamic> dataJson = json['data'] ?? [];
    return Pagination<T>(
      currentPage: json['current_page'] ?? 1,
      lastPage: json['last_page'] ?? 1,
      total: json['total'] ?? dataJson.length,
      perPage: json['per_page'] ?? dataJson.length,
      data: dataJson.map((item) => fromJson(item)).toList(),
    );
  }
}
