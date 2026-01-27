import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// A centered loading indicator with an optional message.
///
/// Used to indicate that a process is active (e.g., fetching data).
class AppLoader extends StatelessWidget {
  final String? message;
  
  const AppLoader({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }
}