import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../models/section_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/api/api_client.dart';

class InteractiveLyricsWidget extends StatefulWidget {
  final AudioPlayer audioPlayer;
  final List<Section> sections;
  final VoidCallback? onSectionPractice;

  const InteractiveLyricsWidget({
    super.key,
    required this.audioPlayer,
    required this.sections,
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

    // Find if the current time falls within any section's segments
    for (int i = 0; i < widget.sections.length; i++) {
      final segments = widget.sections[i].lyricSegments;
      if (segments.isNotEmpty) {
        final start = segments.first.startMs;
        final end = segments.last.endMs;
        
        if (ms >= start && ms <= end) {
          newIndex = i;
          break;
        }
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

  Future<void> _playSection(int index) async {
    if (index < 0 || index >= widget.sections.length) return;
    
    final section = widget.sections[index];
    if (section.audioUrl != null) {
      try {
        final segments = section.lyricSegments;
        final startMs = segments.isNotEmpty ? segments.first.startMs : 0;

        // Stop current playback before switching source
        await widget.audioPlayer.stop();
        
        if (kIsWeb) {
          try {
            final response = await ApiClient.fetchAudioBytes(section.audioUrl!);
            await widget.audioPlayer.play(BytesSource(response.bodyBytes));
          } catch (e) {
            debugPrint('InteractiveLyrics fallback to UrlSource: $e');
            await widget.audioPlayer.play(UrlSource(section.audioUrl!));
          }
        } else {
          await widget.audioPlayer.play(UrlSource(section.audioUrl!));
        }
        
        if (startMs > 0) {
          await widget.audioPlayer.seek(Duration(milliseconds: startMs));
        }
        
        if (mounted) {
          setState(() {
            _playingIndex = index;
            _isPlaying = true;
          });
        }
        
        widget.onSectionPractice?.call();
        _scrollToIndex(index);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Section $index playback error: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  void _scrollToIndex(int index) {
    if (_scrollController.hasClients) {
      // Average height of item is approx 80-90px
      final offset = (index * 80.0).clamp(0.0, _scrollController.position.maxScrollExtent);
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
                  '${widget.sections.length} lines',
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
                  _playSection(_playingIndex ?? 0);
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

        // Lyrics List
        Container(
          height: 380, // Increased height for better view
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: widget.sections.length,
            separatorBuilder: (c, i) => Divider(height: 1, color: AppColors.divider.withValues(alpha: 0.5)),
            itemBuilder: (context, index) {
              return _LineItem(
                section: widget.sections[index],
                isSectionPlaying: index == _playingIndex,
                onTap: () => _playSection(index),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LineItem extends StatefulWidget {
  final Section section;
  final bool isSectionPlaying;
  final VoidCallback onTap;

  const _LineItem({
    required this.section,
    required this.isSectionPlaying,
    required this.onTap,
  });

  @override
  State<_LineItem> createState() => _LineItemState();
}

class _LineItemState extends State<_LineItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: widget.isSectionPlaying 
                ? const Color(0xFFC77C2F)
                : (_isHovered ? const Color(0xFFC77C2F).withValues(alpha: 0.05) : Colors.white),
            borderRadius: BorderRadius.circular(16),
            boxShadow: (widget.isSectionPlaying || _isHovered) ? [
              BoxShadow(
                color: widget.isSectionPlaying 
                    ? const Color(0xFFC77C2F).withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: 0.08),
                blurRadius: widget.isSectionPlaying ? 15 : 10,
                spreadRadius: widget.isSectionPlaying ? 2 : 1,
                offset: const Offset(0, 6),
              )
            ] : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ],
          ),
          transform: (widget.isSectionPlaying || _isHovered) 
              ? (Matrix4.diagonal3Values(1.02, 1.02, 1.0)..setTranslationRaw(0.0, -4.0, 0.0)) 
              : Matrix4.identity(),
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: widget.isSectionPlaying 
                   ? const Icon(Icons.equalizer, color: Colors.white, size: 24, key: ValueKey('playing'))
                   : Icon(
                       _isHovered ? Icons.play_circle_filled : Icons.play_circle_outline, 
                       color: _isHovered ? const Color(0xFFC77C2F) : AppColors.textSecondary.withValues(alpha: 0.4), 
                       size: 24, 
                       key: ValueKey(_isHovered ? 'hover' : 'idle'),
                     ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  widget.section.content ?? widget.section.name,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: (widget.isSectionPlaying || _isHovered) ? FontWeight.bold : FontWeight.w500,
                    color: widget.isSectionPlaying ? Colors.white : AppColors.textPrimary,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
