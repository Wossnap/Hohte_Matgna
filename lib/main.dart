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
        ChangeNotifierProvider(create: (_) => PracticeProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: MaterialApp(
        title: 'Hohte Matgna',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: const AppWrapper(),
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