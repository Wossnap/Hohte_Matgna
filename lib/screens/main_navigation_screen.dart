import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import 'home/home_screen.dart';
import 'profile_screen.dart';
import '../core/theme/app_colors.dart';

/// The main shell of the application, handling bottom navigation.
///
/// Switches between Home, History, and Profile screens.
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const Center(child: Text('Saints (Coming Soon)')),
    const Center(child: Text('Guzo (Coming Soon)')),
    const Center(child: Text('Fund (Coming Soon)')),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LocaleProvider>(context);

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary.withValues(alpha: 0.5),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
          type: BottomNavigationBarType.fixed,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.library_music_rounded),
              label: locale.translate('nav_hymns'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.auto_awesome_rounded),
              label: locale.translate('nav_saints'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.explore_rounded),
              label: locale.translate('nav_guzo'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.volunteer_activism_rounded),
              label: locale.translate('nav_fund'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person_rounded),
              label: locale.translate('nav_profile'),
            ),
          ],
        ),
      ),
    );
  }
}

