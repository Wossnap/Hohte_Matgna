import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';

class RecordingFileInfoWidget extends StatelessWidget {
  const RecordingFileInfoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: AppColors.success, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Recording ready for comparison',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

