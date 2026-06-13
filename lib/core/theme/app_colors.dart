import 'package:flutter/material.dart';

/// Defines the color palette and semantic colors for the application.
class AppColors {
  // Brand Colors
  static const Color primary = Color(0xFF021859); // Navy (matches web primary)
  static const Color primaryLight = Color(0xFF1A3A8F);
  static const Color primaryDark = Color(0xFF010E35);
  static const Color secondary = Color(0xFFEAA406); // Gold (matches web secondary)
  static const Color accentGold = Color(0xFFEAA406);
  static const Color accentGreen = Color(0xFF2E8B57);
  
  static const Color background = Color(0xFFFDFBF7); // Beige/Off-white
  static const Color cardBackground = Colors.white;
  static const Color cardBackgroundAlt = Color(0xFFF2F2F7);
  
  // Text Colors
  static const Color textPrimary = Color(0xFF2C1810); // text_main
  static const Color textSecondary = Color(0xFF5D4037);
  static const Color textLight = Colors.white;

  // Status & Feedback Colors (Synced with Website)
  static const Color success = Color(0xFF2E8B57);
  static const Color warning = Color(0xFFED6C02);
  static const Color error = Color(0xFFD32F2F);
  static const Color info = Color(0xFF0288D1);

  // Practice Feedback Levels
  static const Color great = Color(0xFF059669); // Emerald-600
  static const Color greatBg = Color(0xFFECFDF5); // Emerald-50
  static const Color good = Color(0xFF0284C7); // Sky-600
  static const Color goodBg = Color(0xFFF0F9FF); // Sky-50
  static const Color work = Color(0xFFD97706); // Amber-600
  static const Color workBg = Color(0xFFFFFBEB); // Amber-50
  static const Color penalty = Color(0xFF9A3412); // Orange-800
  static const Color penaltyBg = Color(0xFFFFF7ED); // Orange-50

  // UI Colors
  static const Color border = Color(0x66EAA406);
  static const Color divider = Color(0xFFE5E7EB);
  static const Color shimmerBase = Color(0xFFE5E7EB);
  static const Color shimmerHighlight = Color(0xFFF3F4F6);
}