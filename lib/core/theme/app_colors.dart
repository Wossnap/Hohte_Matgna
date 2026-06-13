import 'package:flutter/material.dart';

/// One concrete set of colors (a light or a dark palette).
///
/// All semantic colors used across the app live here so a single object fully
/// describes the look of one theme. [AppColors] exposes static getters that
/// delegate to the currently-active palette ([activePalette]); the root
/// `MaterialApp` rebuilds the whole tree when the theme changes, so every
/// `AppColors.*` read picks up the new palette automatically.
@immutable
class AppPalette {
  final Brightness brightness;

  // Brand
  final Color primary;
  final Color primaryLight;
  final Color primaryDark;
  final Color secondary;
  final Color accentGold;
  final Color accentGreen;

  // Surfaces
  final Color background;
  final Color cardBackground;
  final Color cardBackgroundAlt;

  // Text
  final Color textPrimary;
  final Color textSecondary;
  final Color textLight;

  // Status
  final Color success;
  final Color warning;
  final Color error;
  final Color info;

  // Practice feedback levels (foreground + background tint)
  final Color great;
  final Color greatBg;
  final Color good;
  final Color goodBg;
  final Color work;
  final Color workBg;
  final Color penalty;
  final Color penaltyBg;

  // UI
  final Color border;
  final Color divider;
  final Color shimmerBase;
  final Color shimmerHighlight;

  const AppPalette({
    required this.brightness,
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.secondary,
    required this.accentGold,
    required this.accentGreen,
    required this.background,
    required this.cardBackground,
    required this.cardBackgroundAlt,
    required this.textPrimary,
    required this.textSecondary,
    required this.textLight,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.great,
    required this.greatBg,
    required this.good,
    required this.goodBg,
    required this.work,
    required this.workBg,
    required this.penalty,
    required this.penaltyBg,
    required this.border,
    required this.divider,
    required this.shimmerBase,
    required this.shimmerHighlight,
  });
}

/// Light palette — matches the web app's light theme.
const AppPalette kLightPalette = AppPalette(
  brightness: Brightness.light,
  primary: Color(0xFF021859), // Navy
  primaryLight: Color(0xFF1A3A8F),
  primaryDark: Color(0xFF010E35),
  secondary: Color(0xFFEAA406), // Gold
  accentGold: Color(0xFFEAA406),
  accentGreen: Color(0xFF2E8B57),
  background: Color(0xFFFDFBF7), // Beige/off-white
  cardBackground: Colors.white,
  cardBackgroundAlt: Color(0xFFF2F2F7),
  textPrimary: Color(0xFF2C1810),
  textSecondary: Color(0xFF5D4037),
  textLight: Colors.white,
  success: Color(0xFF2E8B57),
  warning: Color(0xFFED6C02),
  error: Color(0xFFD32F2F),
  info: Color(0xFF0288D1),
  great: Color(0xFF059669),
  greatBg: Color(0xFFECFDF5),
  good: Color(0xFF0284C7),
  goodBg: Color(0xFFF0F9FF),
  work: Color(0xFFD97706),
  workBg: Color(0xFFFFFBEB),
  penalty: Color(0xFF9A3412),
  penaltyBg: Color(0xFFFFF7ED),
  border: Color(0x66EAA406),
  divider: Color(0xFFE5E7EB),
  shimmerBase: Color(0xFFE5E7EB),
  shimmerHighlight: Color(0xFFF3F4F6),
);

/// Dark palette — matches the web app's dark theme: neutral Tailwind gray
/// surfaces (gray-900/800/700), gold kept as the main accent, and blue-400 for
/// blue accents/text so the deep navy brand stays legible on dark.
const AppPalette kDarkPalette = AppPalette(
  brightness: Brightness.dark,
  // Brand navy & gold kept identical to light mode — brand surfaces
  // (Continue Practicing cards, Recently Added cards, hymn hero gradient)
  // must stay branded in dark mode, never shift.
  primary: Color(0xFF021859), // Navy
  primaryLight: Color(0xFF1A3A8F),
  primaryDark: Color(0xFF010E35),
  secondary: Color(0xFFEAA406), // Gold
  accentGold: Color(0xFFEAA406),
  accentGreen: Color(0xFF4ADE80), // green-400
  background: Color(0xFF111827), // gray-900
  cardBackground: Color(0xFF1F2937), // gray-800
  cardBackgroundAlt: Color(0xFF374151), // gray-700
  textPrimary: Color(0xFFF3F4F6), // gray-100
  textSecondary: Color(0xFF9CA3AF), // gray-400
  textLight: Colors.white,
  success: Color(0xFF4ADE80), // green-400
  warning: Color(0xFFFBBF24), // amber-400
  error: Color(0xFFF87171), // red-400
  info: Color(0xFF60A5FA), // blue-400
  great: Color(0xFF34D399), // emerald-400
  greatBg: Color(0xFF0F2A1E),
  good: Color(0xFF38BDF8), // sky-400
  goodBg: Color(0xFF0C2A3A),
  work: Color(0xFFFBBF24), // amber-400
  workBg: Color(0xFF2A2410),
  penalty: Color(0xFFFB923C), // orange-400
  penaltyBg: Color(0xFF2A1A0E),
  border: Color(0x66EAA406),
  divider: Color(0xFF374151), // gray-700
  shimmerBase: Color(0xFF1F2937), // gray-800
  shimmerHighlight: Color(0xFF374151), // gray-700
);

/// The globally-active palette. Swapped by `ThemeProvider`; never mutate this
/// directly from widgets — go through the provider so the tree rebuilds.
AppPalette activePalette = kLightPalette;

/// Sets the active palette. Called by `ThemeProvider` when the resolved
/// brightness changes (theme toggle or OS theme change in system mode).
void setActivePalette(Brightness brightness) {
  activePalette =
      brightness == Brightness.dark ? kDarkPalette : kLightPalette;
}

/// Whether the active palette is the dark one.
bool get appIsDark => activePalette.brightness == Brightness.dark;

/// Semantic color palette for the app, theme-aware.
///
/// Every member delegates to [activePalette]. Because these are getters (not
/// `const`), widgets reading them must not be `const` at the point of use.
class AppColors {
  // Brand
  static Color get primary => activePalette.primary;

  /// Brand primary used as a FOREGROUND accent (text, icons, selected states)
  /// sitting on a neutral page/card surface. Navy in light; white in dark,
  /// because brand navy is invisible on dark surfaces. Use [primary] for brand
  /// FILLS (buttons, hero gradient, badges) which must stay navy in both modes.
  static Color get primaryAccent =>
      appIsDark ? const Color(0xFFFFFFFF) : activePalette.primary;
  static Color get primaryLight => activePalette.primaryLight;
  static Color get primaryDark => activePalette.primaryDark;
  static Color get secondary => activePalette.secondary;
  static Color get accentGold => activePalette.accentGold;
  static Color get accentGreen => activePalette.accentGreen;

  // Surfaces
  static Color get background => activePalette.background;
  static Color get cardBackground => activePalette.cardBackground;
  static Color get cardBackgroundAlt => activePalette.cardBackgroundAlt;

  // Text
  static Color get textPrimary => activePalette.textPrimary;
  static Color get textSecondary => activePalette.textSecondary;
  static Color get textLight => activePalette.textLight;

  // Status
  static Color get success => activePalette.success;
  static Color get warning => activePalette.warning;
  static Color get error => activePalette.error;
  static Color get info => activePalette.info;

  // Practice feedback levels
  static Color get great => activePalette.great;
  static Color get greatBg => activePalette.greatBg;
  static Color get good => activePalette.good;
  static Color get goodBg => activePalette.goodBg;
  static Color get work => activePalette.work;
  static Color get workBg => activePalette.workBg;
  static Color get penalty => activePalette.penalty;
  static Color get penaltyBg => activePalette.penaltyBg;

  // UI
  static Color get border => activePalette.border;
  static Color get divider => activePalette.divider;
  static Color get shimmerBase => activePalette.shimmerBase;
  static Color get shimmerHighlight => activePalette.shimmerHighlight;
}
