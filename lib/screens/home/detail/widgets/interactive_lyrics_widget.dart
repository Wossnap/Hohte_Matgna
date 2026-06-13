import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  int _playingIndex = -1;
  bool _isPlaying = false;
  bool _userScrolled = false;
  Timer? _scrollResumeTimer;
  final ScrollController _scrollController = ScrollController();
  List<GlobalKey> _itemKeys = [];

  List<LyricSegment> get _allLyricSegments {
    if (widget.lyricSegments != null) return widget.lyricSegments!;
    return widget.sections?.expand((section) => section.lyricSegments).toList() ?? [];
  }

  @override
  void initState() {
    super.initState();
    _initKeys();
    _setupAudioListeners();
  }

  @override
  void didUpdateWidget(InteractiveLyricsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lyricSegments != widget.lyricSegments ||
        oldWidget.sections != widget.sections) {
      _initKeys();
    }
  }

  void _initKeys() {
    final count = _allLyricSegments.length;
    _itemKeys = List.generate(count, (_) => GlobalKey());
  }

  void _setupAudioListeners() {
    widget.audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          if (state == PlayerState.completed || state == PlayerState.stopped) {
            _playingIndex = -1;
          }
        });
      }
    });

    widget.audioPlayer.onPositionChanged.listen((pos) {
      if (mounted) _syncHighlightToPosition(pos);
    });

    widget.audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() { _isPlaying = false; _playingIndex = -1; });
    });
  }

  void _syncHighlightToPosition(Duration pos) {
    if (!_isPlaying) return;
    final ms = pos.inMilliseconds;
    int newIndex = -1;
    final segments = _allLyricSegments;
    for (int i = 0; i < segments.length; i++) {
      if (ms >= segments[i].startMs && ms <= segments[i].endMs) {
        newIndex = i;
        break;
      }
    }
    if (newIndex != _playingIndex) {
      setState(() => _playingIndex = newIndex);
      if (newIndex >= 0) _scrollToIndex(newIndex);
    }
  }

  void _scrollToIndex(int index) {
    if (_userScrolled) return;
    if (index < 0 || index >= _itemKeys.length) return;
    final ctx = _itemKeys[index].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.35,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _playSegment(int index) async {
    final segments = _allLyricSegments;
    if (index < 0 || index >= segments.length) return;
    await widget.audioPlayer.seek(Duration(milliseconds: segments[index].startMs));
    if (!_isPlaying) await widget.audioPlayer.resume();
    if (mounted) {
      setState(() {
        _playingIndex = index;
        _isPlaying = true;
        _userScrolled = false;
      });
    }
    widget.onSectionPractice?.call();
  }

  @override
  void dispose() {
    _scrollResumeTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final segments = _allLyricSegments;

    if (segments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text('No interactive lyrics available', style: AppTextStyles.bodyMedium),
      );
    }

    final completedCount = _playingIndex >= 0 ? _playingIndex + 1 : 0;
    final progress = segments.isEmpty ? 0.0 : completedCount / segments.length;

    return Column(
      children: [
        // Karaoke window: fixed height, faded edges
        SizedBox(
          height: 300,
          child: ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
              stops: [0.0, 0.12, 0.88, 1.0],
            ).createShader(rect),
            blendMode: BlendMode.dstIn,
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is UserScrollNotification &&
                    notification.direction != ScrollDirection.idle) {
                  _userScrolled = true;
                  _scrollResumeTimer?.cancel();
                  _scrollResumeTimer = Timer(const Duration(seconds: 4), () {
                    if (mounted) setState(() => _userScrolled = false);
                  });
                }
                return false;
              },
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 90, horizontal: 8),
                itemCount: segments.length,
                itemBuilder: (context, index) {
                  final isCurrent = index == _playingIndex;
                  final isPast = _playingIndex >= 0 && index < _playingIndex;
                  final dist = _playingIndex >= 0 ? (index - _playingIndex).abs() : 99;
                  return _SegmentItem(
                    key: _itemKeys[index],
                    segment: segments[index],
                    isCurrent: isCurrent,
                    isPast: isPast,
                    distanceFromCurrent: dist,
                    onTap: () => _playSegment(index),
                  );
                },
              ),
            ),
          ),
        ),

        // Progress bar (only while playing)
        if (_playingIndex >= 0) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progress',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    Text(
                      '$completedCount / ${segments.length}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: AppColors.primaryAccent.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryAccent),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SegmentItem extends StatelessWidget {
  final LyricSegment segment;
  final bool isCurrent;
  final bool isPast;
  final int distanceFromCurrent;
  final VoidCallback onTap;

  const _SegmentItem({
    super.key,
    required this.segment,
    required this.isCurrent,
    required this.isPast,
    required this.distanceFromCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final opacity = isCurrent
        ? 1.0
        : distanceFromCurrent == 1
            ? (isPast ? 0.55 : 0.65)
            : distanceFromCurrent == 2
                ? 0.35
                : 0.2;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: opacity,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: isCurrent ? 18 : 10,
          ),
          decoration: BoxDecoration(
            gradient: isCurrent
                ? LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      AppColors.primaryAccent.withValues(alpha: 0.18),
                      AppColors.secondary.withValues(alpha: 0.08),
                    ],
                  )
                : null,
            borderRadius: BorderRadius.circular(14),
            border: isCurrent
                ? Border.all(
                    color: AppColors.primaryAccent.withValues(alpha: 0.4),
                    width: 1.5,
                  )
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 28,
                child: isCurrent
                    ? Icon(Icons.graphic_eq_rounded, size: 20, color: AppColors.primaryAccent)
                    : (isPast && distanceFromCurrent == 1
                        ? Icon(Icons.check_circle_outline_rounded, size: 15, color: AppColors.textSecondary)
                        : const SizedBox.shrink()),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  segment.text,
                  style: TextStyle(
                    fontSize: isCurrent ? 22 : 17,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                    color: isCurrent ? AppColors.primaryAccent : AppColors.textPrimary,
                    height: 1.5,
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
