import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/playlist_model.dart';
import '../../../providers/dashboard_provider.dart';

class PlaylistsWidget extends StatelessWidget {
  const PlaylistsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final dashboard = Provider.of<DashboardProvider>(context);

    if (dashboard.isLoading) {
      return _buildSkeleton();
    }

    if (dashboard.playlists.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Playlists',
          style: AppTextStyles.headerSmall.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppColors.primaryAccent.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: dashboard.playlists.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              return _PlaylistCard(playlist: dashboard.playlists[index]);
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 80,
          height: 13,
          decoration: BoxDecoration(
            color: AppColors.shimmerBase,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, __) => Container(
              width: 180,
              decoration: BoxDecoration(
                color: AppColors.shimmerBase,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  final PlaylistSummary playlist;

  const _PlaylistCard({required this.playlist});

  @override
  Widget build(BuildContext context) {
    final progressPercent = (playlist.progress * 100).round();

    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: playlist.coverImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          playlist.coverImage!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _musicIcon(),
                        ),
                      )
                    : _musicIcon(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  playlist.title,
                  style: AppTextStyles.headerSmall.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${playlist.completedCount} / ${playlist.hymnsCount}',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '$progressPercent%',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: playlist.isCompleted ? AppColors.success : AppColors.primaryAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: playlist.progress,
              minHeight: 5,
              backgroundColor: AppColors.shimmerBase,
              valueColor: AlwaysStoppedAnimation<Color>(
                playlist.isCompleted ? AppColors.success : AppColors.primaryAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _musicIcon() {
    return Icon(Icons.queue_music, size: 18, color: AppColors.primaryAccent);
  }
}
