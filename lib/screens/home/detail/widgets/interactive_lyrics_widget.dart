import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
  // Tracks furthest segment reached so the counter never goes backwards.
  int _highestPlayedIndex = -1;
  bool _isPlaying = false;
  // Set to true after the outer page has been scrolled to the karaoke widget.
  bool _hasScrolledPageToKaraoke = false;

  final ScrollController _scrollController = ScrollController();
  // Key on the 300px SizedBox — used to (a) compute inner-scroll offsets and
  // (b) on first play, scroll the outer CustomScrollView to reveal it.
  final GlobalKey _karaokeBoxKey = GlobalKey();
  List<GlobalKey> _itemKeys = [];
  final List<StreamSubscription> _subscriptions = [];

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
    _subscriptions.add(widget.audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state == PlayerState.playing;
        if (state == PlayerState.completed || state == PlayerState.stopped) {
          _playingIndex = -1;
          _highestPlayedIndex = -1;
          _hasScrolledPageToKaraoke = false;
        }
      });
    }));

    _subscriptions.add(widget.audioPlayer.onPositionChanged.listen((pos) {
      if (mounted) _syncHighlightToPosition(pos);
    }));

    _subscriptions.add(widget.audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _playingIndex = -1;
        _highestPlayedIndex = -1;
        _hasScrolledPageToKaraoke = false;
      });
    }));
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
      setState(() {
        _playingIndex = newIndex;
        if (newIndex > _highestPlayedIndex) _highestPlayedIndex = newIndex;
      });
      if (newIndex >= 0) {
        // Scroll the outer page to the karaoke widget the first time a segment
        // is actually matched — i.e. when audio has truly started playing.
        if (!_hasScrolledPageToKaraoke) {
          _hasScrolledPageToKaraoke = true;
          _scrollPageToKaraoke();
        }
        _scrollKaraokeToIndex(newIndex);
      }
    }
  }

  // Scrolls the OUTER CustomScrollView to reveal the karaoke box (first play only).
  void _scrollPageToKaraoke() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _karaokeBoxKey.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.1,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    });
  }

  // Scrolls the INNER karaoke ListView to center the active segment.
  // Only called while audio is playing (user can't manually scroll at that time).
  void _scrollKaraokeToIndex(int index) {
    if (index < 0 || index >= _itemKeys.length) return;
    if (!_scrollController.hasClients) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final itemCtx = _itemKeys[index].currentContext;
      final boxCtx = _karaokeBoxKey.currentContext;
      if (itemCtx == null || boxCtx == null) return;

      final itemBox = itemCtx.findRenderObject() as RenderBox?;
      final containerBox = boxCtx.findRenderObject() as RenderBox?;
      if (itemBox == null || containerBox == null) return;
      if (!itemBox.attached || !containerBox.attached) return;

      // Y of the item relative to the 300px container top (negative = above viewport).
      final itemY = itemBox.localToGlobal(Offset.zero, ancestor: containerBox).dy;
      final viewportHeight = _scrollController.position.viewportDimension;
      final targetOffset = (_scrollController.offset + itemY - viewportHeight * 0.35).clamp(
        _scrollController.position.minScrollExtent,
        _scrollController.position.maxScrollExtent,
      );

      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    });
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
        if (index > _highestPlayedIndex) _highestPlayedIndex = index;
      });
    }
    widget.onSectionPractice?.call();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
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

    final completedCount = _highestPlayedIndex >= 0 ? _highestPlayedIndex + 1 : 0;
    final progress = completedCount / segments.length;

    return Column(
      children: [
        SizedBox(
          key: _karaokeBoxKey,
          height: 300,
          child: ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
              stops: [0.0, 0.12, 0.88, 1.0],
            ).createShader(rect),
            blendMode: BlendMode.dstIn,
            child: ListView.builder(
              controller: _scrollController,
              // Lock the list while audio plays — segments auto-scroll instead.
              physics: _isPlaying
                  ? const NeverScrollableScrollPhysics()
                  : const AlwaysScrollableScrollPhysics(),
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

        // Progress bar — shown once playback has reached the first segment.
        if (_highestPlayedIndex >= 0) ...[
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
                    ? SvgPicture.asset(
                        'assets/images/Hohte_logo.optimized.svg',
                        width: 22,
                        height: 22,
                        colorFilter: ColorFilter.mode(
                          AppColors.primaryAccent,
                          BlendMode.srcIn,
                        ),
                      )
                    : (isPast && distanceFromCurrent == 1
                        ? Icon(
                            Icons.check_circle_outline_rounded,
                            size: 15,
                            color: AppColors.textSecondary,
                          )
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
