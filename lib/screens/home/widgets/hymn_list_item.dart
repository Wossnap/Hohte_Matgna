import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/hymn_model.dart';

class HymnListItem extends StatelessWidget {
  final Hymn hymn;
  final VoidCallback onTap;

  const HymnListItem({
    super.key,
    required this.hymn,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.secondary.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              // Left circle: green check if completed, logo otherwise
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hymn.isCompleted
                      ? AppColors.success.withValues(alpha: 0.12)
                      : AppColors.primary.withValues(alpha: 0.07),
                ),
                child: hymn.isCompleted
                    ? const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: AppColors.success,
                      )
                    : Center(
                        child: SvgPicture.asset(
                          'assets/images/Hohte_logo.svg',
                          width: 18,
                          height: 18,
                          colorFilter: ColorFilter.mode(
                            AppColors.primary.withValues(alpha: 0.5),
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
              ),

              const SizedBox(width: 12),

              // Title + badges
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hymn.title,
                      style: AppTextStyles.headerSmall.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (hymn.category != null || hymn.scale != null) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        children: [
                          if (hymn.category != null)
                            _badge(hymn.category!.name,
                                AppColors.secondary.withValues(alpha: 0.15),
                                AppColors.secondary),
                          if (hymn.scale != null)
                            _badge(hymn.scale!.name,
                                AppColors.primary.withValues(alpha: 0.1),
                                AppColors.primary),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Stats + chevron
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hymn.plays > 0)
                    _stat(Icons.play_arrow_rounded, hymn.plays),
                  if (hymn.practices > 0) ...[
                    const SizedBox(width: 6),
                    _stat(Icons.history_edu_rounded, hymn.practices),
                  ],
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.textSecondary.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _stat(IconData icon, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textSecondary),
        const SizedBox(width: 2),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
