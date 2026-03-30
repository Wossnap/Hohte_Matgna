// Provider managing authentication state and user sessions.

import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  UserModel? _user;
  bool _isAuthenticated = false;
  bool _isLoading = true;
  String? _error;

  UserModel? get user => _user;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get error => _error;

  final AuthService _authService = AuthService();

  AuthProvider() {
    checkAuthStatus();
  }

  /// Checks the current authentication status from persistent storage.
  ///
  /// Updates [user] and [isAuthenticated] state accordingly.
  Future<void> checkAuthStatus() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final isLoggedIn = await _authService.isLoggedIn();
      
      if (isLoggedIn) {
        _user = await _authService.getCurrentUser();
        _isAuthenticated = true;
      } else {
        _user = null;
        _isAuthenticated = false;
      }
      
      _error = null;
    } catch (e) {
      _error = e.toString();
      _user = null;
      _isAuthenticated = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Logs in the user with [email] and [password].
  Future<void> login(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final authResponse = await _authService.login(email, password);
      _user = authResponse.user;
      _isAuthenticated = true;
      _error = null;
    } catch (e) {
      _error = e.toString();
      _user = null;
      _isAuthenticated = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Registers a new user with [name], [email], and [password].
  Future<void> register(String name, String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final authResponse = await _authService.register(name, email, password);
      _user = authResponse.user;
      _isAuthenticated = true;
      _error = null;
    } catch (e) {
      _error = e.toString();
      _user = null;
      _isAuthenticated = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Logs out the current user and clears session data.
  Future<void> logout() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      await _authService.logout();
      _user = null;
      _isAuthenticated = false;
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}