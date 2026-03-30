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

  /// Create Pagination from JSON returned by Laravel API (Inertia or Direct)
  factory Pagination.fromJson(
      Map<String, dynamic> json, T Function(Map<String, dynamic>) fromJson) {
    // Handle Inertia/Laravel wrap: { props: { hymns: { data: [...] } } }
    final props = json['props'] is Map<String, dynamic> ? json['props'] : json;
    
    // Look for the paginated object (e.g., 'hymns')
    Map<String, dynamic> paginated;
    if (props['hymns'] is Map<String, dynamic>) {
      paginated = props['hymns'];
    } else {
      paginated = props;
    }

    final List<dynamic> dataJson = paginated['data'] ?? [];
    final List<T> data = [];
    for (final item in dataJson) {
      if (item is Map<String, dynamic>) {
        try {
          data.add(fromJson(item));
        } catch (e) {
          // Skip invalid items
        }
      }
    }

    return Pagination<T>(
      currentPage: paginated['current_page'] ?? 1,
      lastPage: paginated['last_page'] ?? 1,
      total: paginated['total'] ?? data.length,
      perPage: paginated['per_page'] ?? data.length,
      data: data,
    );
  }
}
