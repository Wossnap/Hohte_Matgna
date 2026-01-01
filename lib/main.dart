import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/metadata_provider.dart';
import 'providers/hymn_provider.dart';
import 'screens/home/home_screen.dart';
import 'screens/splash_screen.dart';
// auth_service not used here; AuthProvider handles auth checks

// Login screen import
import 'screens/login_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => MetadataProvider()),
        ChangeNotifierProvider(create: (_) => HymnProvider()),
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
            ? const HomeScreen()
            : LoginScreen(); // Now properly imported
      },
    );
  }
}