import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../models/section_model.dart';
import '../../../../../models/lyric_segment_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class InteractiveLyricsWidget extends StatefulWidget {
  final AudioPlayer audioPlayer;
  final List<Section>? sections;
  final List<LyricSegment>? lyricSegments;
  final VoidCallback? onSectionPractice;

  const InteractiveLyricsWidget({
    super.key,
    required this.audioPlayer,
    this.sections,
    this.lyricSegments,
    this.onSectionPractice,
  });

  @override
  State<InteractiveLyricsWidget> createState() => _InteractiveLyricsWidgetState();
}

class _InteractiveLyricsWidgetState extends State<InteractiveLyricsWidget> {
  int? _playingIndex;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  final ScrollController _scrollController = ScrollController();

  List<LyricSegment> get _allLyricSegments {
    if (widget.lyricSegments != null) return widget.lyricSegments!;
    return widget.sections?.expand((section) => section.lyricSegments).toList() ?? [];
  }

  @override
  void initState() {
    super.initState();
    _setupAudioListeners();
  }

  void _setupAudioListeners() {
    widget.audioPlayer.onLog.listen((msg) {
      // Log audio events
    });

    widget.audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
      }
    });

    widget.audioPlayer.onPositionChanged.listen((pos) {
      if (mounted) {
        setState(() {
          _position = pos;
          _syncHighlightToPosition(pos);
        });
      }
    });

    widget.audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
          _playingIndex = null;
        });
      }
    });
  }

  void _syncHighlightToPosition(Duration pos) {
    if (!_isPlaying) return;

    final ms = pos.inMilliseconds;
    int? newIndex;

    // Find if the current time falls within any lyric segment
    final segments = _allLyricSegments;
    for (int i = 0; i < segments.length; i++) {
      final segment = segments[i];
      if (ms >= segment.startMs && ms <= segment.endMs) {
        newIndex = i;
        break;
      }
    }

    if (newIndex != null && newIndex != _playingIndex) {
      setState(() {
        _playingIndex = newIndex;
      });
      _scrollToIndex(newIndex);
    }
  }

  @override
  void dispose() {
    // Shared player is disposed by HymnDetailScreen
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _playSegment(int index) async {
    final segments = _allLyricSegments;
    if (index < 0 || index >= segments.length) return;
    
    final segment = segments[index];
    final startMs = segment.startMs;

    // Seek to the segment start
    await widget.audioPlayer.seek(Duration(milliseconds: startMs));
    if (!_isPlaying) {
      await widget.audioPlayer.resume();
    }
    
    if (mounted) {
      setState(() {
        _playingIndex = index;
        _isPlaying = true;
      });
    }
    
    widget.onSectionPractice?.call();
    _scrollToIndex(index);
  }

  void _scrollToIndex(int index) {
    if (_scrollController.hasClients) {
      // Average width of item is approx 200px
      final offset = (index * 200.0).clamp(0.0, _scrollController.position.maxScrollExtent);
      _scrollController.animateTo(
        offset, 
        duration: const Duration(milliseconds: 500), 
        curve: Curves.easeOutCubic,
      );
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    final milliseconds = (duration.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(2, '0');
    return '$minutes:$seconds.$milliseconds';
  }

  @override
  Widget build(BuildContext context) {
    final segments = _allLyricSegments;
    if (segments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('No interactive lyrics available'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header Row
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFC77C2F),
                shape: BoxShape.circle,
              ),
              child: const Text('J', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                   'Interactive Lyrics',
                  style: AppTextStyles.headerSmall.copyWith(
                    fontWeight: FontWeight.bold, 
                    color: AppColors.textPrimary
                  ),
                ),
                Text(
                  '${_allLyricSegments.length} segments',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () {
                if (_isPlaying) {
                  widget.audioPlayer.pause();
                } else {
                  _playSegment(_playingIndex ?? 0);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
              label: Text(_isPlaying ? 'Pause' : 'Play'),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Timer (Centered)
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(20),
              color: Colors.white,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.access_time, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  _formatDuration(_position), 
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Horizontal Lyrics List
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.vertical,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: segments.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: _SegmentItem(
                  segment: segments[index],
                  isPlaying: index == _playingIndex,
                  onTap: () => _playSegment(index),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SegmentItem extends StatefulWidget {
  final LyricSegment segment;
  final bool isPlaying;
  final VoidCallback onTap;

  const _SegmentItem({
    required this.segment,
    required this.isPlaying,
    required this.onTap,
  });

  @override
  State<_SegmentItem> createState() => _SegmentItemState();
}

class _SegmentItemState extends State<_SegmentItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isInteractive = _isInteractiveSegment();

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isPlaying 
                ? AppColors.primary.withValues(alpha: 0.1) 
                : (_isHovered ? AppColors.primary.withValues(alpha: 0.05) : Colors.white),
            border: Border.all(
              color: widget.isPlaying ? AppColors.primary : AppColors.border,
              width: widget.isPlaying ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: widget.isPlaying ? [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ] : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.segment.text,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: widget.isPlaying ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: widget.isPlaying ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
              if (isInteractive) ...[
                const SizedBox(height: 4),
                Icon(
                  Icons.mic,
                  size: 16,
                  color: widget.isPlaying ? AppColors.primary : AppColors.textSecondary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool _isInteractiveSegment() {
    // Simple heuristic: if there's a gap before this segment, it's interactive
    return true; // Placeholder
  }
}

