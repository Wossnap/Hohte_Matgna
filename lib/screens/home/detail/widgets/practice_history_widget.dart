import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';

class PracticeHistoryWidget extends StatelessWidget {
  final int practices;
  
  const PracticeHistoryWidget({super.key, required this.practices});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.greyCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ExpansionTile(
        title: Text(
          'Practice history',
          style: AppTextStyles.headerSmall.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        trailing: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                const Icon(Icons.history_rounded, color: Colors.grey, size: 24),
                const SizedBox(width: 16),
                Text(
                  'No practice attempts yet',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
