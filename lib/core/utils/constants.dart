class AppConstants {
  // API Configuration
  static const String apiBaseUrl = 'https://hohte-matgna.batelew.com/api';
  
  // Storage Keys
  static const String accessTokenKey = 'access_token';
  static const String userDataKey = 'user_data';
  static const String isLoggedInKey = 'is_logged_in';
  
  // Pagination
  static const int itemsPerPage = 10;
  static const int defaultPage = 1;
  
  // Validation
  static const int minPasswordLength = 6;
  // Remove non-const RegExp
  // static const RegExp emailRegex = RegExp(r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+');
  
  // Messages
  static const String networkError = 'Network error occurred. Please check your connection.';
  static const String serverError = 'Server error occurred. Please try again later.';
  static const String invalidCredentials = 'Invalid email or password.';
  static const String registrationSuccess = 'Registration successful! Please login.';
  
  // Timeouts
  static const int apiTimeoutSeconds = 30;
  static const int connectTimeoutSeconds = 10;
  static const int receiveTimeoutSeconds = 10;
}