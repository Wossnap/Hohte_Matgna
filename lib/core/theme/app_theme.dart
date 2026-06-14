import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

/// Defines the global theme configuration for the application.
///
/// Builds a [ThemeData] from a given [AppPalette] so the light and dark themes
/// share one definition and only differ by palette.
class AppTheme {
  static ThemeData _build(AppPalette p) {
    final bool isDark = p.brightness == Brightness.dark;
    return ThemeData(
      brightness: p.brightness,
      primaryColor: p.primary,
      scaffoldBackgroundColor: p.background,
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: AppTextStyles.headerMedium.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
        iconTheme: IconThemeData(color: p.textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: Colors.white, // white on navy in both modes
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          elevation: 2,
          shadowColor: p.primary.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle:
              AppTextStyles.buttonLarge.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.cardBackground,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? p.secondary : p.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.error),
        ),
        labelStyle: TextStyle(color: p.textSecondary, fontSize: 14),
        hintStyle: TextStyle(color: p.textSecondary, fontSize: 14),
        prefixIconColor: p.textSecondary,
      ),
      cardTheme: CardThemeData(
        color: p.cardBackground,
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8),
      ),
      dialogTheme: DialogThemeData(backgroundColor: p.cardBackground),
      bottomSheetTheme:
          BottomSheetThemeData(backgroundColor: p.cardBackground),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: isDark ? p.secondary : p.primary,
        selectionColor: (isDark ? p.secondary : p.primary).withValues(alpha: 0.3),
        selectionHandleColor: isDark ? p.secondary : p.primary,
      ),
      dividerColor: p.divider,
      colorScheme: ColorScheme(
        brightness: p.brightness,
        primary: p.primary,
        onPrimary: Colors.white,
        secondary: p.secondary,
        onSecondary: isDark ? p.background : Colors.white,
        surface: p.cardBackground,
        onSurface: p.textPrimary,
        error: p.error,
        onError: Colors.white,
      ),
    );
  }

  static final ThemeData lightTheme = _build(kLightPalette);
  static final ThemeData darkTheme = _build(kDarkPalette);
}
