/// Defines the API endpoint paths used in the application.
class ApiEndpoints {
  // Auth
  static const String login = '/login';
  static const String register = '/register';
  static const String logout = '/logout';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String verifyEmail = '/email/verification-notification';
  static const String confirmPassword = '/confirm-password';
  
  // Profile & Settings
  static const String profile = '/settings/profile';
  static const String updatePassword = '/settings/password';
  static const String twoFactor = '/settings/two-factor';
  
  // Metadata
  static const String categories = '/categories';
  static const String scales = '/scales';
  
  // Hymns
  static const String hymns = '/hymns';
  static const String hymnAutocomplete = '/hymns/autocomplete';
  
  // Practice
  static const String practiceDetail = '/practice'; // /practice/{id}
  static const String compareAudio = '/practice/compare';
  static const String latestAttempt = '/practice/attempt/latest';
  static const String breakpoints = '/practice/pause-breakpoints';
  
  // Progress (Specific Routes)
  static String incrementHymnPlay(int id) => '/practice/hymn/$id/play';
  static String incrementHymnPractice(int id) => '/practice/hymn/$id/practice';
  static String incrementSectionPlay(int id) => '/practice/section/$id/play';
  static String incrementSectionPractice(int id) => '/practice/section/$id/practice';

  // Completion persistence (mirrors the web's HymnPracticeController).
  static const String batchSectionsComplete = '/practice/sections/complete';
  static String setHymnComplete(int id) => '/practice/$id/complete';
}