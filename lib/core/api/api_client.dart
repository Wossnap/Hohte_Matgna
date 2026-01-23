import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const String baseUrl = 'https://hohte-matgna.batelew.com/api';
  
  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    return headers;
  }

  static Future<http.Response> get(String endpoint, {Map<String, dynamic>? queryParams}) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('$baseUrl$endpoint').replace(
      queryParameters: queryParams?.map((key, value) => MapEntry(key, value.toString())),
    );
    
    final response = await http.get(uri, headers: headers);
    return response;
  }

  static Future<http.Response> post(String endpoint, {Map<String, dynamic>? body}) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return response;
  }

  static Future<http.Response> postMultipart(
    String endpoint, {
    required Map<String, String> fields,
    required List<http.MultipartFile> files,
  }) async {
    final token = (await SharedPreferences.getInstance()).getString('access_token');
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$endpoint'));
    
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';
    
    request.fields.addAll(fields);
    request.files.addAll(files);
    
    final streamedResponse = await request.send();
    return http.Response.fromStream(streamedResponse);
  }
}