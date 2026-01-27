import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/models/section_model.dart';
import 'audio_player_widget.dart';
import 'compare_widget.dart';

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
  bool _isExpanded = false;
  late AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _isExpanded = false; // Always collapsed by default per user request
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
    final leftPadding = widget.depth * 12.0;

    return Container(
      margin: EdgeInsets.only(
        left: leftPadding,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Accordion Header
          InkWell(
            onTap: () {
              setState(() => _isExpanded = !_isExpanded);
              // Trigger auto-play logic if expanding
              if (_isExpanded && hasAudio) {
                // We don't have direct access to AudioPlayerWidget state,
                // but setting source is already done in initState.
                // The AudioPlayer is passed to AudioPlayerWidget, so we can control it.
                 _audioPlayer.resume();
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _isExpanded ? AppColors.primary.withValues(alpha: 0.05) : Colors.transparent,
                borderRadius: _isExpanded
                    ? const BorderRadius.vertical(top: Radius.circular(12))
                    : BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  // Logo/Icon Placeholder (using primary color for consistency)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.music_note,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Section Name
                  Expanded(
                    child: Text(
                      widget.section.name,
                      style: AppTextStyles.headerSmall.copyWith(fontSize: 18),
                    ),
                  ),

                  // Toggle Icon
                  Icon(
                    _isExpanded ? Icons.expand_more : Icons.chevron_right,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),

          // Accordion Content
          if (_isExpanded) ...[
            Container(
              color: AppColors.background,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Audio Player
                  if (hasAudio) ...[
                    AudioPlayerWidget(
                      audioUrl: widget.section.audioUrl!,
                      audioPlayer: _audioPlayer,
                      initialPlays: widget.section.plays,
                      playableId: widget.section.id,
                      playableType: 'App\\Models\\Section',
                    ),
                    const SizedBox(height: 16),
                    
                    // Practice/Compare Link
                    CompareWidget(
                      hymnId: widget.hymnId,
                      playableType: 'section',
                      playableId: widget.section.id,
                      label: 'Compare with Reference',
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Lyrics/Content
                  if (widget.section.content != null && widget.section.content!.isNotEmpty) ...[
                    const Text(
                      'Lyrics',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.section.content!,
                        style: AppTextStyles.bodyMedium.copyWith(height: 1.6),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Children Sections
                  if (hasChildren) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'ንፅፅሮች',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...widget.section.children.map((child) => SectionWidget(
                          section: child,
                          hymnId: widget.hymnId,
                          depth: widget.depth + 1,
                        )),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
