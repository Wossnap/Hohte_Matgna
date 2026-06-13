import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme/app_colors.dart';

/// Manages the app's theme mode (system / light / dark), persists the choice,
/// and keeps the global [activePalette] in sync with the resolved brightness.
///
/// The root `MaterialApp` listens to this provider and rebuilds the whole tree
/// when [themeMode] changes, so every `AppColors.*` getter re-reads the active
/// palette.
class ThemeProvider with ChangeNotifier {
  static const String _prefsKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    // Re-resolve when the OS theme changes while we're following the system.
    final dispatcher = PlatformDispatcher.instance;
    dispatcher.onPlatformBrightnessChanged = () {
      if (_themeMode == ThemeMode.system) {
        _applyActivePalette();
        notifyListeners();
      }
    };
    _applyActivePalette();
    _load();
  }

  /// Brightness actually shown right now, accounting for system mode.
  Brightness get resolvedBrightness {
    switch (_themeMode) {
      case ThemeMode.light:
        return Brightness.light;
      case ThemeMode.dark:
        return Brightness.dark;
      case ThemeMode.system:
        return PlatformDispatcher.instance.platformBrightness;
    }
  }

  bool get isDark => resolvedBrightness == Brightness.dark;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_prefsKey);
      if (stored != null) {
        _themeMode = ThemeMode.values.firstWhere(
          (m) => m.name == stored,
          orElse: () => ThemeMode.system,
        );
        _applyActivePalette();
        notifyListeners();
      }
    } catch (_) {
      // Ignore — fall back to system default.
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    _applyActivePalette();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, mode.name);
    } catch (_) {
      // Persisting is best-effort.
    }
  }

  void _applyActivePalette() => setActivePalette(resolvedBrightness);
}
