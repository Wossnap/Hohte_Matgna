import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/models/section_model.dart';
import 'package:mobile/providers/practice_provider.dart';
import 'audio_player_widget.dart';
import 'compare_widget.dart';

class SectionWidget extends StatefulWidget {
  final Section section;
  final int hymnId;
  final int depth;
  final bool isInteractive;
  final int? bpm;
  final List<double>? beatTimestamps;
  final VoidCallback? onPlay; // Added callback

  const SectionWidget({
    super.key,
    required this.section,
    required this.hymnId,
    this.depth = 0,
    this.isInteractive = false,
    this.bpm,
    this.beatTimestamps,
    this.onPlay,
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
    _isExpanded = false;
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _startSectionPlayback() async {
    try {
      if (widget.section.audioUrl != null) {
        await _audioPlayer.play(UrlSource(widget.section.audioUrl!));
      }
    } catch (e) {
      debugPrint('Error starting section playback: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final practiceProvider = context.watch<PracticeProvider>();
    final isCompleted = practiceProvider.isSectionCompleted(widget.section.id);
    
    final hasChildren = widget.section.children.isNotEmpty;
    final hasAudio = widget.section.audioUrl != null && widget.section.audioUrl!.isNotEmpty;
    final leftPadding = widget.depth * 12.0;

    return Container(
      margin: EdgeInsets.only(
        left: leftPadding,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        color: isCompleted ? AppColors.greatBg : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted 
            ? Color(0xFF10B981).withValues(alpha: 0.4) 
            : AppColors.primary.withValues(alpha: 0.1),
          width: isCompleted ? 2.0 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () {
              setState(() => _isExpanded = !_isExpanded);
              if (_isExpanded && hasAudio) {
                _startSectionPlayback();
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _isExpanded 
                    ? AppColors.primary.withValues(alpha: 0.05) 
                    : Colors.transparent,
                borderRadius: _isExpanded
                    ? const BorderRadius.vertical(top: Radius.circular(12))
                    : BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  // Completion Checkmark Toggle (Synced with Website)
                  GestureDetector(
                    onTap: () {
                      practiceProvider.toggleSectionCompletion(widget.section.id);
                    },
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: isCompleted ? const Color(0xFF10B981) : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isCompleted ? const Color(0xFF10B981) : Colors.grey.shade400,
                          width: 2,
                        ),
                      ),
                      child: isCompleted 
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.section.name,
                      style: AppTextStyles.headerSmall.copyWith(
                        fontSize: 18,
                        color: isCompleted ? const Color(0xFF047857) : AppColors.textPrimary,
                        fontWeight: isCompleted ? FontWeight.bold : FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_more : Icons.chevron_right,
                    color: AppColors.primaryAccent,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasAudio) ...[
                    // Practice History Summary (Synced with Website)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildHistoryItem(
                            'BEST SCORE', 
                            widget.section.bestScore != null 
                              ? '${widget.section.bestScore!.toStringAsFixed(1)}%' 
                              : '-',
                            Icons.emoji_events_rounded, 
                            AppColors.accentGold,
                          ),
                          const SizedBox(width: 12),
                          _buildHistoryItem(
                            'PRACTICES', 
                            widget.section.practices.toString(), 
                            Icons.history_rounded, 
                            AppColors.primary,
                          ),
                          const SizedBox(width: 12),
                          _buildHistoryItem(
                            'PLAYS', 
                            widget.section.plays.toString(), 
                            Icons.play_circle_outline, 
                            AppColors.accentGreen,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    AudioPlayerWidget(
                      audioUrl: widget.section.audioUrl!,
                      audioPlayer: _audioPlayer,
                      playableId: widget.section.id,
                      playableType: 'section',
                      initialPlays: widget.section.plays, // Added initial plays
                      initialPractices: widget.section.practices, // Added initial practices
                      onPlay: () {
                        practiceProvider.incrementSectionPlay(widget.section.id);
                        widget.onPlay?.call();
                      },
                      bpm: widget.bpm,
                      beatTimestamps: widget.beatTimestamps,
                    ),
                    const SizedBox(height: 16),
                    CompareWidget(
                      hymnId: widget.hymnId,
                      playableType: 'section',
                      playableId: widget.section.id,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (widget.section.content != null && widget.section.content!.isNotEmpty) ...[
                    Text(
                      'Lyrics',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryAccent,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.section.content!,
                        style: AppTextStyles.bodyMedium.copyWith(height: 1.6),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (hasChildren) ...[
                    ...widget.section.children.map((child) => SectionWidget(
                          section: child,
                          hymnId: widget.hymnId,
                          depth: widget.depth + 1,
                          isInteractive: widget.isInteractive,
                          bpm: widget.bpm,
                          beatTimestamps: widget.beatTimestamps,
                          onPlay: widget.onPlay,
                        )),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w900,
                  color: color,
                  fontSize: 13,
                ),
              ),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 8,
                  letterSpacing: 0.5,
                  color: color.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

