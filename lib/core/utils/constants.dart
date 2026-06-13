/// Holds constant values used across the application.
///
/// This includes API configuration, storage keys, validation rules,
/// and static messages.
class AppConstants {
  // API Configuration
  // LOCAL TESTING: phone reaches host via `adb reverse tcp:8000 tcp:8000`.
  // Revert these two lines to the batelew.com URLs before committing.
  // static const String apiBaseUrl = 'http://localhost:8000/api';
  // static const String storageBaseUrl = 'http://localhost:8000/storage';
  static const String apiBaseUrl = 'https://hohte-matgna.batelew.com/api';
  static const String storageBaseUrl = 'https://hohte-matgna.batelew.com/storage';
  
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