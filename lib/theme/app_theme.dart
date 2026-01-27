import 'package:flutter/material.dart';

/// Basic theme configuration.
///
/// Note: Consider using [lib/core/theme/app_theme.dart] for more comprehensive theme definitions.
class AppTheme {
  static ThemeData lightTheme = ThemeData(
    scaffoldBackgroundColor: const Color(0xFFF6EFEA),
    fontFamily: 'Roboto',
    useMaterial3: true,
  );
}
