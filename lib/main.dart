import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/metadata_provider.dart';
import 'providers/hymn_provider.dart';
import 'providers/practice_provider.dart';
import 'screens/splash_screen.dart';
// auth_service not used here; AuthProvider handles auth checks

// Login screen import
import 'screens/auth/login_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'providers/locale_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/theme_provider.dart';

import 'dart:async';

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('FLUTTER ERROR: ${details.exception}');
    };
    debugPrint('Starting App...');
    runApp(const MyApp());
  }, (error, stack) {
    debugPrint('GLOBAL ERROR: $error');
    debugPrint('STACK TRACE: $stack');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, MetadataProvider>(
          create: (_) => MetadataProvider(),
          update: (_, auth, metadata) => metadata!..update(auth.isAuthenticated),
        ),
        ChangeNotifierProxyProvider<AuthProvider, HymnProvider>(
          create: (_) => HymnProvider(),
          update: (_, auth, hymn) => hymn!..update(auth.isAuthenticated),
        ),
        ChangeNotifierProxyProvider<AuthProvider, DashboardProvider>(
          create: (_) => DashboardProvider(),
          update: (_, auth, dashboard) => dashboard!..update(auth.isAuthenticated),
        ),
        ChangeNotifierProvider(create: (_) => PracticeProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            // Colors come from the global `activePalette` (not Theme.of), so
            // cached/inactive subtrees won't repaint on a theme change on their
            // own. Keying on the resolved brightness forces a full rebuild so
            // every screen (bottom nav, inactive tabs) flips at once. Toggling
            // is rare and only reachable from the Profile tab, so there are no
            // pushed routes to lose.
            key: ValueKey(themeProvider.isDark),
            title: 'Hohte Matgna',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            debugShowCheckedModeBanner: false,
            home: const AppWrapper(),
          );
        },
      ),
    );
  }
}

class AppWrapper extends StatefulWidget {
  const AppWrapper({super.key});

  @override
  State<AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (authProvider.isLoading) {
          return const SplashScreen();
        }

        return authProvider.isAuthenticated
            ? const MainNavigationScreen()
            : LoginScreen(); // Now properly imported
      },
    );
  }
}