import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Defines the text styles used throughout the application.
///
/// This includes styles for headers, body text, buttons, and captions.
class AppTextStyles {
  // Headers
  static TextStyle headerLarge = TextStyle(
    fontSize: 28, // Adjusted for mobile
    fontWeight: FontWeight.w900,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );
  
  static TextStyle headerMedium = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );
  
  static TextStyle headerSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );
  
  // Body
  static TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    color: AppColors.textPrimary,
    height: 1.5,
  );
  
  static TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    color: AppColors.textPrimary,
    height: 1.5,
  );
  
  static TextStyle bodySmall = TextStyle(
    fontSize: 12,
    color: AppColors.textPrimary,
  );
  
  // Buttons
  static TextStyle buttonLarge = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    letterSpacing: 0.5,
  );
  
  static TextStyle buttonMedium = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );
  
  // Caption
  static TextStyle caption = TextStyle(
    fontSize: 11,
    color: AppColors.textSecondary,
    fontWeight: FontWeight.w500,
  );
}