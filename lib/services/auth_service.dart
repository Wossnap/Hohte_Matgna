import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api/api_endpoints.dart'; // Add this import
import '../models/user_model.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  Future<AuthResponse> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('https://hohte-matgna.batelew.com/api${ApiEndpoints.login}'), // Fixed URL
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final authResponse = AuthResponse.fromJson(responseData);
        
        // Store token and user data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', authResponse.accessToken);
        await prefs.setString('user_data', jsonEncode(authResponse.user.toJson()));
        await prefs.setBool('is_logged_in', true);
        
        return authResponse;
      } else {
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Login failed');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<AuthResponse> register(String name, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('https://hohte-matgna.batelew.com/api${ApiEndpoints.register}'), // Fixed URL
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': password,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final authResponse = AuthResponse.fromJson(responseData);
        
        // Store token and user data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', authResponse.accessToken);
        await prefs.setString('user_data', jsonEncode(authResponse.user.toJson()));
        await prefs.setBool('is_logged_in', true);
        
        return authResponse;
      } else {
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Registration failed');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      
      if (token != null) {
        await http.post(
          Uri.parse('https://hohte-matgna.batelew.com/api${ApiEndpoints.logout}'), // Fixed URL
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      }
      
      // Clear storage
      await prefs.remove('access_token');
      await prefs.remove('user_data');
      await prefs.setBool('is_logged_in', false);
    } catch (e) {
      // Even if logout fails on server, clear local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      rethrow;
    }
  }

  Future<UserModel?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString('user_data');
      
      if (userData != null) {
        return UserModel.fromJson(jsonDecode(userData));
      }
      
      // Try to fetch from API if token exists
      final token = prefs.getString('access_token');
      if (token != null) {
        final response = await http.get(
          Uri.parse('https://hohte-matgna.batelew.com/api${ApiEndpoints.user}'), // Fixed URL
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
        
        if (response.statusCode == 200) {
          final Map<String, dynamic> responseData = jsonDecode(response.body);
          final user = UserModel.fromJson(responseData);
          await prefs.setString('user_data', jsonEncode(user.toJson()));
          return user;
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    return token != null && isLoggedIn;
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }
}