import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/utils/constants.dart';
import '../models/user_model.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  Future<AuthResponse> login(String email, String password) async {
    try {
      final response = await ApiClient.post(
        ApiEndpoints.login,
        body: {
          'email': email,
          'password': password,
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final authResponse = AuthResponse.fromJson(responseData);

        // Store token and user data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.accessTokenKey, authResponse.accessToken);
        await prefs.setString(AppConstants.userDataKey, jsonEncode(authResponse.user.toJson()));
        await prefs.setBool(AppConstants.isLoggedInKey, true);

        return authResponse;
      } else {
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Login failed');
      }
    } on SocketException {
      throw Exception('Network error: please check your internet connection.');
    } on TimeoutException {
      throw Exception('Request timed out. Please try again.');
    }
  }

  Future<AuthResponse> register(String name, String email, String password) async {
    try {
      final response = await ApiClient.post(
        ApiEndpoints.register,
        body: {
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': password,
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final authResponse = AuthResponse.fromJson(responseData);

        // Store token and user data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.accessTokenKey, authResponse.accessToken);
        await prefs.setString(AppConstants.userDataKey, jsonEncode(authResponse.user.toJson()));
        await prefs.setBool(AppConstants.isLoggedInKey, true);

        return authResponse;
      } else {
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Registration failed');
      }
    } on SocketException {
      throw Exception('Network error: please check your internet connection.');
    } on TimeoutException {
      throw Exception('Request timed out. Please try again.');
    }
  }

  Future<void> logout() async {
    try {
      await ApiClient.post(ApiEndpoints.logout).timeout(const Duration(seconds: 10));

      // Clear storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.accessTokenKey);
      await prefs.remove(AppConstants.userDataKey);
      await prefs.setBool(AppConstants.isLoggedInKey, false);
    } on SocketException {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      rethrow;
    } on TimeoutException {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      rethrow;
    }
  }

  Future<UserModel?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString(AppConstants.userDataKey);

      if (userData != null) {
        return UserModel.fromJson(jsonDecode(userData));
      }

      // Try to fetch from API if token exists
      final token = prefs.getString(AppConstants.accessTokenKey);
      if (token != null) {
        final response = await ApiClient.get(ApiEndpoints.profile)
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final Map<String, dynamic> responseData = jsonDecode(response.body);
          final user = UserModel.fromJson(responseData);
          await prefs.setString('user_data', jsonEncode(user.toJson()));
          return user;
        }
      }

      return null;
    } on SocketException {
      return null;
    } on TimeoutException {
      return null;
    }
  }

  /// Update the authenticated user's profile (name/email).
  Future<UserModel> updateProfile({required String name, required String email}) async {
    try {
      final response = await ApiClient.patch(ApiEndpoints.profile, body: {
        'name': name,
        'email': email,
      }).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        // API may return the updated user object directly or under 'user'
        final userJson = responseData['user'] ?? responseData;
        final user = UserModel.fromJson(userJson);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.userDataKey, jsonEncode(user.toJson()));

        return user;
      }

      final Map<String, dynamic> errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to update profile');
    } on SocketException {
      throw Exception('Network error: please check your internet connection.');
    } on TimeoutException {
      throw Exception('Request timed out. Please try again.');
    }
  }

  /// Delete the authenticated user's account.
  Future<void> deleteProfile() async {
    try {
      final response = await ApiClient.delete(ApiEndpoints.profile).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200 || response.statusCode == 204) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        return;
      }

      final Map<String, dynamic> errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to delete profile');
    } on SocketException {
      throw Exception('Network error: please check your internet connection.');
    } on TimeoutException {
      throw Exception('Request timed out. Please try again.');
    }
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.accessTokenKey);
    final isLoggedIn = prefs.getBool(AppConstants.isLoggedInKey) ?? false;
    return token != null && isLoggedIn;
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.accessTokenKey);
  }
}