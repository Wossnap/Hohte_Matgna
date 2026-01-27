import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Defines the text styles used throughout the application.
///
/// This includes styles for headers, body text, buttons, and captions.
class AppTextStyles {
  // Headers
  static TextStyle headerLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );
  
  static TextStyle headerMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );
  
  static TextStyle headerSmall = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );
  
  // Body
  static TextStyle bodyLarge = TextStyle(
    fontSize: 18,
    color: AppColors.textPrimary,
    height: 1.4,
  );
  
  static TextStyle bodyMedium = TextStyle(
    fontSize: 16,
    color: AppColors.textPrimary,
    height: 1.4,
  );
  
  static TextStyle bodySmall = TextStyle(
    fontSize: 14,
    color: AppColors.textPrimary,
  );
  
  // Buttons
  static TextStyle buttonLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );
  
  static TextStyle buttonMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );
  
  // Caption
  static TextStyle caption = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
  );
}