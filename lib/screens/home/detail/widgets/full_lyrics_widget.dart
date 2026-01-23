import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';

class FullLyricsWidget extends StatelessWidget {
  final String lyrics; // In a real scenario, this might need parsing if it's structured
  
  const FullLyricsWidget({super.key, required this.lyrics});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.greyCard,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Full Lyrics',
                style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () {}, // Future feature
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF0EBEB), // Faded background
                  foregroundColor: AppColors.primary,
                  elevation: 0,
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.gamepad, size: 16),
                label: const Text('Play Fill-in-the-Blank'),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Lyrics Content (Placeholder for complex parsing, just displaying text now)
          Text(
            lyrics,
            style: AppTextStyles.bodyMedium.copyWith(
              height: 1.8,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
