import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../models/attempt_model.dart';

class RecordingResultDialog extends StatelessWidget {
  final Attempt attempt;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  const RecordingResultDialog({
    super.key,
    required this.attempt,
    required this.onRetry,
    required this.onClose,
  });

  Color _getScoreColor(double score) {
    if (score >= 80) return AppColors.success;
    if (score >= 60) return AppColors.warning;
    return AppColors.error;
  }

  String _getScoreLabel(double score) {
    if (score >= 90) return 'Excellent!';
    if (score >= 80) return 'Great Job!';
    if (score >= 70) return 'Good';
    if (score >= 60) return 'Keep Practicing';
    return 'Needs Improvement';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.analytics, color: AppColors.primary),
          SizedBox(width: 8),
          Text('Comparison Result'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (attempt.score != null) ...[
            Center(
              child: Text(
                '${attempt.score!.toStringAsFixed(1)}%',
                style: AppTextStyles.headerLarge.copyWith(
                  color: _getScoreColor(attempt.score!),
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _getScoreLabel(attempt.score!),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
          if (attempt.feedback != null && attempt.feedback!.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Feedback:',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              attempt.feedback!,
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: onClose,
          child: const Text('Close'),
        ),
        ElevatedButton(
          onPressed: onRetry,
          child: const Text('Try Again'),
        ),
      ],
    );
  }
}
