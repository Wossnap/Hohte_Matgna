import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

/// The top navigation bar for the dashboard/home screen.
///
/// Displays the screen title, language toggle, theme toggle, and user profile.
class DashboardNavbar extends StatelessWidget {
  const DashboardNavbar({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            /// LEFT — TITLE
            const Text(
              'Dashboard',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const Spacer(),

            /// LANGUAGE
            _Chip(label: 'EN'),
            const SizedBox(width: 8),
            _Chip(label: 'አማ'),

            const SizedBox(width: 16),

            /// THEME ICONS
            const Icon(Icons.light_mode_outlined, size: 20),
            const SizedBox(width: 10),
            const Icon(Icons.dark_mode_outlined, size: 20),

            const SizedBox(width: 24),

            /// USER
            Row(
              children: [
                const CircleAvatar(
                  radius: 14,
                  child: Icon(Icons.person, size: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  auth.user?.name ?? 'User',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const Icon(Icons.keyboard_arrow_down),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;

  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE8E0D9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}
