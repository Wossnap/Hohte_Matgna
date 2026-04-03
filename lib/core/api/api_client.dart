import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class ApiClient {
  static const String baseUrl = AppConstants.apiBaseUrl;

  /// Retrieves the headers for API requests, including the authentication token if available.
  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.accessTokenKey);
    
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Performs a GET request to the specified [endpoint].
  static Future<http.Response> get(String endpoint, {Map<String, dynamic>? queryParams}) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('$baseUrl$endpoint').replace(
      queryParameters: queryParams?.map((key, value) => MapEntry(key, value.toString())),
    );
    
    debugPrint('ApiClient GET: $uri');
    final response = await http.get(uri, headers: headers);
    _handleResponse(response);
    
    return response;
  }

  /// Performs a POST request to the specified [endpoint].
  static Future<http.Response> post(String endpoint, {Map<String, dynamic>? body}) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('$baseUrl$endpoint');
    
    debugPrint('ApiClient POST: $uri');
    if (body != null) debugPrint('ApiClient Body: ${jsonEncode(body)}');
    
    final response = await http.post(
      uri,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
    _handleResponse(response);
    
    return response;
  }

  /// Performs a PATCH request to the specified [endpoint].
  static Future<http.Response> patch(String endpoint, {Map<String, dynamic>? body}) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('$baseUrl$endpoint');

    debugPrint('ApiClient PATCH: $uri');
    if (body != null) debugPrint('ApiClient Body: ${jsonEncode(body)}');

    final response = await http.patch(
      uri,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
    _handleResponse(response);

    return response;
  }

  /// Performs a DELETE request to the specified [endpoint].
  static Future<http.Response> delete(String endpoint, {Map<String, dynamic>? queryParams, Map<String, dynamic>? body}) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('$baseUrl$endpoint').replace(
      queryParameters: queryParams?.map((key, value) => MapEntry(key, value.toString())),
    );

    debugPrint('ApiClient DELETE: $uri');

    // Some servers expect a body with DELETE; http.delete supports body from Dart 2.14+
    final response = await http.delete(
      uri,
      headers: headers,
    );
    _handleResponse(response);

    return response;
  }

  /// Performs a multipart POST request. Supports both automated file loading from path
  /// and manual MultipartFile injection (useful for Web/Bytes).
  static Future<http.Response> postMultipart(
    String endpoint, {
    Map<String, String>? fields,
    String? filePath,
    String? fieldName,
    List<http.MultipartFile>? files,
  }) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('$baseUrl$endpoint');
    
    debugPrint('ApiClient Multipart POST: $uri');
    
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(headers);

    // MultipartRequest will set its own Content-Type with boundary.
    // Remove any fixed JSON Content-Type header coming from _getHeaders().
    request.headers.remove('Content-Type');

    // Debug: print headers and file content types for troubleshooting
    debugPrint('Multipart request headers before adding files: ${request.headers}');
    
    if (fields != null) {
      request.fields.addAll(fields);
    }
    
    if (files != null) {
      for (final f in files) {
        debugPrint('Adding multipart file: field=${f.field}, filename=${f.filename}, contentType=${f.contentType}');
      }
      request.files.addAll(files);
    } else if (filePath != null && fieldName != null) {
      request.files.add(await http.MultipartFile.fromPath(fieldName, filePath));
    }
    
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    _handleResponse(response);
    
    return response;
  }

  /// Global response handler for logging and session expiration
  static void _handleResponse(http.Response response) {
    debugPrint('ApiClient Response [${response.statusCode}]: ${response.body.length > 500 ? '${response.body.substring(0, 500)}...' : response.body}');
    
    if (response.statusCode == 401 || response.statusCode == 419) {
      debugPrint('SESSION EXPIRED: Received ${response.statusCode}');
      // Note: In a larger app, we would use a GlobalKey<NavigatorState>
      // to redirect to the login screen or show an overlay like the website.
    }
  }

  /// Special method to fetch audio bytes
  static Future<http.Response> fetchAudioBytes(String url) async {
    debugPrint('ApiClient fetchAudioBytes: $url');
    final response = await http.get(Uri.parse(url));
    return response;
  }
}
