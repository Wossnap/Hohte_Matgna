import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/user_model.dart';

/// Displays user profile information and settings.
///
/// Allows the user to view stats, change language, and logout.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final locale = Provider.of<LocaleProvider>(context);
    final user = auth.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(locale.translate('nav_profile'), style: AppTextStyles.headerMedium),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // User Header
          _buildUserHeader(user, locale),
          const SizedBox(height: 32),

          // Stats Summary
          Text(
            locale.translate('stats_summary'),
            style: AppTextStyles.headerSmall.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 16),
          _buildStatsGrid(locale),
          const SizedBox(height: 32),

          // Settings
          Text(
            'Settings', 
            style: AppTextStyles.headerSmall.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 16),
          _buildSettingsCard(locale),
          
          const SizedBox(height: 32),
          _buildLogoutButton(auth, locale),
        ],
      ),
    );
  }

  Widget _buildUserHeader(UserModel? user, LocaleProvider locale) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.greyCard,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.primary,
            child: Text(
              user != null ? user.name.substring(0, 1).toUpperCase() : 'U',
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.name ?? 'User',
                  style: AppTextStyles.headerMedium.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  user?.email ?? 'email@example.com',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(LocaleProvider locale) {
    return Row(
      children: [
        Expanded(child: _buildStatCard(locale.translate('plays'), '124', Icons.play_circle_outline)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard(locale.translate('practices'), '42', Icons.school_outlined)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.greyCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 28),
          const SizedBox(height: 16),
          Text(value, style: AppTextStyles.headerMedium.copyWith(fontWeight: FontWeight.w900, fontSize: 24)),
          Text(label, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(LocaleProvider locale) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.greyCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _buildSettingTile(
            locale.translate('settings_language'),
            locale.language == AppLanguage.english ? 'English' : 'አማርኛ',
            Icons.language_rounded,
            onTap: () {
              locale.setLanguage(
                locale.language == AppLanguage.english ? AppLanguage.amharic : AppLanguage.english
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile(String title, String trailing, IconData icon, {required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(title, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(trailing, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(AuthProvider auth, LocaleProvider locale) {
    return ElevatedButton.icon(
      onPressed: () => auth.logout(),
      icon: const Icon(Icons.logout_rounded),
      label: Text(locale.translate('settings_logout')),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.greyCard,
        foregroundColor: AppColors.error,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: AppTextStyles.buttonMedium.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}
