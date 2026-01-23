import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';

class RecordingStatusWidget extends StatelessWidget {
  final Duration duration;

  const RecordingStatusWidget({super.key, required this.duration});

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Icon(Icons.fiber_manual_record, color: AppColors.error, size: 48),
          const SizedBox(height: 8),
          Text(
            'Recording...',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            _formatDuration(duration),
            style: AppTextStyles.headerMedium.copyWith(
              color: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
}
