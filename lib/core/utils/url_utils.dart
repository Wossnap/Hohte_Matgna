import 'constants.dart';

class UrlUtils {
  /// Resolves a media path into a full URL.
  /// 
  /// Logic:
  /// 1. If path is already a full URL (starts with http), return as-is.
  /// 2. If path already starts with /storage/, strip the storage part and append to storageBaseUrl.
  /// 3. Otherwise, append to storageBaseUrl.
  static String resolveStorageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    
    // Normalize path by removing leading slash if present
    String normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    
    // If it starts with storage/, we want to point to our storageBaseUrl
    if (normalizedPath.startsWith('storage/')) {
      normalizedPath = normalizedPath.substring(8);
    }
    
    return '${AppConstants.storageBaseUrl}/$normalizedPath';
  }
}
