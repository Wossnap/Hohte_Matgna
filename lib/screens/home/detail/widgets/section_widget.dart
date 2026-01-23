import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/models/section_model.dart';
import 'package:mobile/providers/practice_provider.dart';
import 'audio_player_widget.dart';

class SectionWidget extends StatefulWidget {
  final Section section;
  final int hymnId;
  final int depth;

  const SectionWidget({
    super.key,
    required this.section,
    required this.hymnId,
    this.depth = 0,
  });

  @override
  State<SectionWidget> createState() => _SectionWidgetState();
}

class _SectionWidgetState extends State<SectionWidget> {
  bool _isExpanded = true;
  late AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasChildren = widget.section.children.isNotEmpty;
    final hasAudio = widget.section.audioUrl != null && widget.section.audioUrl!.isNotEmpty;
    final leftPadding = widget.depth * 16.0;

    return Container(
      margin: EdgeInsets.only(
        left: leftPadding,
        bottom: 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section Header
          InkWell(
            onTap: hasChildren ? () => setState(() => _isExpanded = !_isExpanded) : null,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.depth == 0
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  // Expand/Collapse Icon
                  if (hasChildren)
                    Icon(
                      _isExpanded ? Icons.expand_more : Icons.chevron_right,
                      color: AppColors.primary,
                      size: 24,
                    )
                  else
                    Icon(
                      Icons.subdirectory_arrow_right,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),

                  const SizedBox(width: 8),

                  // Section Name
                  Expanded(
                    child: Text(
                      widget.section.name,
                      style: widget.depth == 0
                          ? AppTextStyles.headerSmall
                          : AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                    ),
                  ),

                  // Progress Badges
                  if (widget.section.plays > 0 || widget.section.practices > 0) ...[
                    _buildBadge(
                      Icons.play_circle_outline,
                      widget.section.plays,
                      AppColors.info,
                    ),
                    const SizedBox(width: 8),
                    _buildBadge(
                      Icons.school_outlined,
                      widget.section.practices,
                      AppColors.success,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Section Content (when expanded)
          if (_isExpanded) ...[
            // Section Lyrics/Content
            if (widget.section.content != null && widget.section.content!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  widget.section.content!,
                  style: AppTextStyles.bodyMedium.copyWith(height: 1.5),
                ),
              ),

            // Section Audio Player
            if (hasAudio)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: AudioPlayerWidget(
                  audioUrl: widget.section.audioUrl!,
                  audioPlayer: _audioPlayer,
                  onPlay: () => _onSectionPlay(),
                ),
              ),

            // Practice Button
            if (hasAudio)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ElevatedButton.icon(
                  onPressed: _onPractice,
                  icon: const Icon(Icons.school, size: 18),
                  label: const Text('Mark as Practiced'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),

            // Recursive Children Sections
            if (hasChildren)
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
                child: Column(
                  children: widget.section.children.map((childSection) {
                    return SectionWidget(
                      section: childSection,
                      hymnId: widget.hymnId,
                      depth: widget.depth + 1,
                    );
                  }).toList(),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadge(IconData icon, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            count.toString(),
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _onSectionPlay() {
    final provider = Provider.of<PracticeProvider>(context, listen: false);
    provider.incrementSectionPlay(widget.section.id);
  }

  void _onPractice() {
    final provider = Provider.of<PracticeProvider>(context, listen: false);
    provider.incrementSectionPractice(widget.section.id);
    
    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.section.name} marked as practiced!'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
