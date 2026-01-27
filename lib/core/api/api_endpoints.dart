/// Defines the API endpoint paths used in the application.
class ApiEndpoints {
  // Auth
  static const String login = '/login';
  static const String register = '/register';
  static const String logout = '/logout';
  static const String user = '/user';
  
  // Metadata
  static const String categories = '/categories';
  static const String scales = '/scales';
  
  // Hymns
  static const String hymns = '/hymns';
  
  // Practice
  static const String practiceDetail = '/practice'; // /practice/{id}
  static const String hymnPlay = '/practice/hymn'; // /practice/hymn/{id}/play
  static const String hymnPractice = '/practice/hymn'; // /practice/hymn/{id}/practice
  static const String sectionPlay = '/practice/section'; // /practice/section/{id}/play
  static const String sectionPractice = '/practice/section'; // /practice/section/{id}/practice
  static const String compareAudio = '/practice/compare';
  static const String latestAttempt = '/practice/attempt/latest';
  static const String breakpoints = '/practice/pause-breakpoints';
}