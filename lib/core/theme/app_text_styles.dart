import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Defines the text styles used throughout the application.
///
/// This includes styles for headers, body text, buttons, and captions.
class AppTextStyles {
  // NOTE: these are getters (not cached fields) so the color reflects the
  // currently-active palette. A cached `static TextStyle` would bake in the
  // light color at first access and never update on theme change.

  // Headers
  static TextStyle get headerLarge => TextStyle(
        fontSize: 28, // Adjusted for mobile
        fontWeight: FontWeight.w900,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
      );

  static TextStyle get headerMedium => TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: -0.3,
      );

  static TextStyle get headerSmall => TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      );

  // Body
  static TextStyle get bodyLarge => TextStyle(
        fontSize: 16,
        color: AppColors.textPrimary,
        height: 1.5,
      );

  static TextStyle get bodyMedium => TextStyle(
        fontSize: 14,
        color: AppColors.textPrimary,
        height: 1.5,
      );

  static TextStyle get bodySmall => TextStyle(
        fontSize: 12,
        color: AppColors.textPrimary,
      );

  // Buttons
  static TextStyle get buttonLarge => const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        letterSpacing: 0.5,
      );

  static TextStyle get buttonMedium => const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      );

  // Caption
  static TextStyle get caption => TextStyle(
        fontSize: 11,
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w500,
      );
}