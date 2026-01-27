/// Provider for managing app localization and language switching.
library;
import 'package:flutter/material.dart';

enum AppLanguage { english, amharic }

class LocaleProvider with ChangeNotifier {
  AppLanguage _language = AppLanguage.english;

  AppLanguage get language => _language;

  /// Updates the application language.
  void setLanguage(AppLanguage lang) {
    if (_language == lang) return;
    _language = lang;
    notifyListeners();
  }

  /// Translates a localized string key to the current language.
  String translate(String key) {
    if (_language == AppLanguage.english) {
      return _en[key] ?? key;
    } else {
      return _am[key] ?? key;
    }
  }

  static const Map<String, String> _en = {
    'nav_hymns': 'Hymns',
    'nav_history': 'History',
    'nav_profile': 'Profile',
    'home_title': 'Hymn Library',
    'search_hint': 'Search hymns...',
    'filter_category': 'Category',
    'filter_scale': 'Scale',
    'filter_sort': 'Sort By',
    'practice': 'Practice',
    'plays': 'Plays',
    'practices': 'Practices',
    'sections': 'Sections',
    'profile_title': 'My Profile',
    'settings_language': 'App Language',
    'settings_logout': 'Logout',
    'stats_summary': 'Performance Summary',
    'daily_focus': 'Daily Focus',
    'practice_now': 'Practice Now',
  };

  static const Map<String, String> _am = {
    'nav_hymns': 'መዝሙሮች',
    'nav_history': 'ታሪክ',
    'nav_profile': 'መገለጫ',
    'home_title': 'መዝሙር ቤት',
    'search_hint': 'መዝሙር ፈልግ...',
    'filter_category': 'ምድብ',
    'filter_scale': 'ቅኝት',
    'filter_sort': 'ደርድር',
    'practice': 'ተለማመድ',
    'plays': 'ተሰምቷል',
    'practices': 'ተለማምደዋል',
    'sections': 'ክፍሎች',
    'profile_title': 'መገለጫዬ',
    'settings_language': 'የመተግበሪያ ቋንቋ',
    'settings_logout': 'ውጣ',
    'stats_summary': 'የአፈጻጸም ማጠቃለያ',
    'daily_focus': 'የዛሬ ትኩረት',
    'practice_now': 'አሁን ተለማመድ',
  };
}
