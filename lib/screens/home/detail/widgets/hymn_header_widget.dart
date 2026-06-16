import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../models/hymn_detail_model.dart';
import '../../../../models/category_model.dart';

class HymnHeaderWidget extends StatelessWidget {
  final HymnDetail hymn;

  const HymnHeaderWidget({super.key, required this.hymn});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24), // Slightly reduced top/bottom padding
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min, // Use min size to avoid pushing too far
          children: [
            // Logo Area with Scale Integrated
            Stack(
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(16), // Slightly reduced from 20
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                  ),
                  child: SvgPicture.asset(
                    'assets/images/Hohte_logo.svg',
                    height: 70, // Slightly reduced from 80
                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                  ),
                ),
                if (hymn.hymn.scale != null)
                  Positioned(
                    bottom: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        hymn.hymn.scale!.name.toUpperCase(),
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 9, // Slightly smaller
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24), // Reduced from 38
            
            // Title
            Text(
              hymn.hymn.title,
              textAlign: TextAlign.center,
              style: AppTextStyles.headerLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 38,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    offset: const Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12), // Reduced from 16
            
            // Category Badge
            if (hymn.hymn.category != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Text(
                  hymn.hymn.category!.name,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14, // Slightly smaller
                  ),
                ),
              ),

            // Category hierarchy breadcrumb ("Parent → Child"), matching the web
            // hero. Only shown when the category has a parent chain.
            if (hymn.hymn.category != null &&
                hymn.hymn.category!.hierarchy.length > 1) ...[
              const SizedBox(height: 8),
              _buildCategoryBreadcrumb(hymn.hymn.category!.hierarchy),
            ],

          ],
        ),
      ),
    );
  }

  // Renders the category chain as "Root → … → Leaf". The leaf is emphasised;
  // ancestors are dimmed, separated by a → arrow (matches the web hero).
  Widget _buildCategoryBreadcrumb(List<Category> chain) {
    final spans = <Widget>[];
    for (var i = 0; i < chain.length; i++) {
      final isLeaf = i == chain.length - 1;
      spans.add(Text(
        chain[i].name,
        style: AppTextStyles.bodySmall.copyWith(
          color: Colors.white.withValues(alpha: isLeaf ? 0.95 : 0.7),
          fontStyle: FontStyle.italic,
          fontWeight: isLeaf ? FontWeight.w600 : FontWeight.normal,
          fontSize: 12,
        ),
      ));
      if (!isLeaf) {
        spans.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            '→',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
          ),
        ));
      }
    }
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: spans,
    );
  }
}

