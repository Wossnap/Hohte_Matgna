import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../../../core/utils/wakelock_manager.dart';
import '../../../../models/section_model.dart';
import '../../../../../models/lyric_segment_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../view_models/hymn_detail_viewmodel.dart';

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

class _InteractiveLyricsWidgetState extends State<InteractiveLyricsWidget>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  // Keep alive when scrolled off-screen in the detail screen's SliverList, so
  // audio listeners and karaoke state survive scrolling (matches the audio
  // player widget, which shares the same AudioPlayer).
  @override
  bool get wantKeepAlive => true;

  int _playingIndex = -1;
  // Tracks furthest segment reached so the counter never goes backwards.
  int _highestPlayedIndex = -1;
  bool _isPlaying = false;
  // True while the hymn is being recorded — the karaoke then follows the
  // recording's elapsed time instead of audio playback (matches the web).
  bool _isRecording = false;
  // True while alternating playback is running — the karaoke then follows the
  // reference phase's position pushed via the view-model.
  bool _isAlternate = false;
  HymnDetailViewModel? _viewModel;
  // Set to true after the outer page has been scrolled to the karaoke widget.
  bool _hasScrolledPageToKaraoke = false;

  // Gentle "breathing" pulse on the active lyric line, matching the web's
  // animate-pulse-once (continuous subtle scale on the current segment).
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;

  // Whether the karaoke is currently on-screen. Combined with playback state to
  // hold a wakelock only while the user is actually watching the karaoke during
  // main-audio playback (so the screen doesn't dim/lock mid-song).
  bool _isKaraokeVisible = false;
  final Key _visibilityKey = UniqueKey();

  final ScrollController _scrollController = ScrollController();
  // Key on the 300px SizedBox — used to (a) compute inner-scroll offsets and
  // (b) on first play, scroll the outer CustomScrollView to reveal it.
  final GlobalKey _karaokeBoxKey = GlobalKey();
  List<GlobalKey> _itemKeys = [];
  final List<StreamSubscription> _subscriptions = [];

  List<LyricSegment> get _allLyricSegments {
    final segments = widget.lyricSegments ??
        widget.sections?.expand((section) => section.lyricSegments).toList() ??
        [];
    // Sort chronologically by start time — the API does not guarantee order, and
    // the highlight/counter logic matches by array index, so an unsorted list
    // makes the first position match land mid-way through (e.g. 9/10) and the
    // monotonic counter then freezes. Matches the web app's sortedSegments.
    final sorted = List<LyricSegment>.from(segments)
      ..sort((a, b) => a.startMs.compareTo(b.startMs));
    return sorted;
  }

  @override
  void initState() {
    super.initState();
    _initKeys();
    _setupAudioListeners();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseScale = Tween<double>(begin: 1.0, end: 1.03)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Attach to the shared view-model's recording notifiers once, so the karaoke
    // can follow the recording's elapsed time while recording.
    if (_viewModel == null) {
      try {
        _viewModel = Provider.of<HymnDetailViewModel>(context, listen: false);
        _viewModel!.isRecording.addListener(_onRecordingChanged);
        _viewModel!.recordingElapsedMs.addListener(_onRecordingElapsed);
        _viewModel!.isAlternatePlaybackActive.addListener(_onAlternateChanged);
        _viewModel!.alternateElapsedMs.addListener(_onAlternateElapsed);
        // Seed current values: addListener does NOT fire with the existing value,
        // so if this widget is (re)built while a mode is already active — e.g. the
        // karaoke is rebuilt when the screen collapses into alternating playback —
        // we'd otherwise miss the transition and never follow along.
        _isRecording = _viewModel!.isRecording.value;
        _isAlternate = _viewModel!.isAlternatePlaybackActive.value;
      } catch (_) {
        _viewModel = null; // no view-model ancestor — recording sync unavailable
      }
    }
  }

  @override
  void didUpdateWidget(InteractiveLyricsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lyricSegments != widget.lyricSegments ||
        oldWidget.sections != widget.sections) {
      _initKeys();
    }
  }

  void _onRecordingChanged() {
    final rec = _viewModel?.isRecording.value ?? false;
    if (rec == _isRecording || !mounted) return;
    setState(() {
      _isRecording = rec;
      _playingIndex = -1;
      _highestPlayedIndex = -1;
    });
    _scrollKaraokeToTop();
  }

  void _onRecordingElapsed() {
    if (!_isRecording || !mounted) return;
    // Inner viewport follows the segment; never move the outer page while the
    // user is at the recorder below.
    _applyHighlightForMs(_viewModel!.recordingElapsedMs.value, allowPageScroll: false);
  }

  void _onAlternateChanged() {
    final active = _viewModel?.isAlternatePlaybackActive.value ?? false;
    if (active == _isAlternate || !mounted) return;
    setState(() {
      _isAlternate = active;
      _playingIndex = -1;
      _highestPlayedIndex = -1;
    });
    _scrollKaraokeToTop();
  }

  void _onAlternateElapsed() {
    if (!_isAlternate || !mounted) return;
    _applyHighlightForMs(_viewModel!.alternateElapsedMs.value, allowPageScroll: false);
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
          // Note: _hasScrolledPageToKaraoke is intentionally NOT reset here — the
          // outer page should auto-scroll to the karaoke only once (first play),
          // never again on replay or a later manual play.
        }
      });
      _updateKaraokeWakelock();
      // On auto-replay the audio restarts from the top, so reset the karaoke's
      // INNER viewport back to the first segment — otherwise it stays scrolled
      // down near where the previous loop ended. (Inner viewport only — does not
      // move the outer page.)
      if (state == PlayerState.completed || state == PlayerState.stopped) {
        _scrollKaraokeToTop();
      }
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
        // _hasScrolledPageToKaraoke intentionally left set (one-time page scroll).
      });
      _scrollKaraokeToTop();
    }));
  }

  // Resets the INNER karaoke ListView back to the first segment. Used on
  // completion so the next auto-replay starts with the viewport at the top.
  void _scrollKaraokeToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.minScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    });
  }

  // Hold a wakelock only while the main audio is playing AND the karaoke is on
  // screen — so watching the lyrics doesn't let the screen dim/lock, but it's
  // released as soon as playback stops or the user scrolls away.
  void _updateKaraokeWakelock() {
    if (_isPlaying && _isKaraokeVisible) {
      WakelockManager.acquire('karaoke');
    } else {
      WakelockManager.release('karaoke');
    }
  }

  void _syncHighlightToPosition(Duration pos) {
    // Recording / alternating playback drive the karaoke from their own elapsed
    // notifiers, so ignore raw audio-position updates while either is active —
    // otherwise the two sources fight and the highlight glitches when recording
    // is started mid-playback.
    if (_isRecording || _isAlternate) return;
    // Apply on every position change — including while paused — so seeking on the
    // audio progress bar jumps the highlight straight to the segment at that
    // time (previously a paused seek was dropped, leaving nothing highlighted).
    // The one-time outer-page scroll is gated to real playback so a paused seek
    // doesn't yank the whole page.
    _applyHighlightForMs(pos.inMilliseconds, allowPageScroll: _isPlaying);
  }

  // Highlights the segment containing [ms] and scrolls to follow it. Shared by
  // audio playback (allowPageScroll: true) and recording (allowPageScroll: false).
  void _applyHighlightForMs(int ms, {required bool allowPageScroll}) {
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
        if (allowPageScroll && !_hasScrolledPageToKaraoke) {
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

      // Y of the item relative to the container top (negative = above viewport).
      final itemY = itemBox.localToGlobal(Offset.zero, ancestor: containerBox).dy;
      final viewportHeight = _scrollController.position.viewportDimension;
      // Center the active line vertically so the window shows exactly one past
      // and one upcoming segment around it (matches the Laravel 3-line window).
      final itemHeight = itemBox.size.height;
      final targetOffset = (_scrollController.offset + itemY - (viewportHeight - itemHeight) / 2).clamp(
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
    _viewModel?.isRecording.removeListener(_onRecordingChanged);
    _viewModel?.recordingElapsedMs.removeListener(_onRecordingElapsed);
    _viewModel?.isAlternatePlaybackActive.removeListener(_onAlternateChanged);
    _viewModel?.alternateElapsedMs.removeListener(_onAlternateElapsed);
    WakelockManager.release('karaoke');
    _pulseController.dispose();
    _scrollController.dispose();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
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
        VisibilityDetector(
          key: _visibilityKey,
          onVisibilityChanged: (info) {
            if (!mounted) return;
            final visible = info.visibleFraction > 0.1;
            if (visible != _isKaraokeVisible) {
              _isKaraokeVisible = visible;
              _updateKaraokeWakelock();
            }
          },
          child: SizedBox(
          key: _karaokeBoxKey,
          // Sized to show a 3-segment window (1 past · current · 1 upcoming),
          // matching the Laravel KaraokeLyrics.vue which renders exactly those
          // three. The edge fade (ShaderMask) hides any sliver of a 4th line.
          height: 220,
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
              // Never manually scrollable — the list always auto-scrolls to the
              // active segment, even when paused. Tapping a segment seeks audio.
              physics: const NeverScrollableScrollPhysics(),
              // Keep every segment built (lyric lists are short). Otherwise a
              // large seek jumps the highlight to an off-screen segment the lazy
              // builder hasn't realised yet, so _scrollKaraokeToIndex can't find
              // its context to scroll to it and the window stays on the old lines.
              cacheExtent: 100000,
              padding: const EdgeInsets.symmetric(vertical: 90, horizontal: 8),
              itemCount: segments.length,
              itemBuilder: (context, index) {
                final isCurrent = index == _playingIndex;
                final isPast = _playingIndex >= 0 && index < _playingIndex;
                final dist = _playingIndex >= 0 ? (index - _playingIndex).abs() : 99;
                final item = _SegmentItem(
                  key: _itemKeys[index],
                  segment: segments[index],
                  isCurrent: isCurrent,
                  isPast: isPast,
                  distanceFromCurrent: dist,
                  onTap: () => _playSegment(index),
                );
                // Breathe the active line. ScaleTransition uses a Transform, so
                // it doesn't affect layout — the scroll-centering math (which
                // measures the unscaled render box) is unaffected.
                return isCurrent ? ScaleTransition(scale: _pulseScale, child: item) : item;
              },
            ),
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
                  child: Container(
                    height: 4,
                    color: AppColors.primaryAccent.withValues(alpha: 0.15),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      builder: (context, value, _) => FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: value,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.primaryAccent, AppColors.secondary],
                            ),
                          ),
                        ),
                      ),
                    ),
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

  // Per-line leading glyph, matching the web: brand logo on the active line,
  // a check on the immediate past line, and a clock on the next upcoming line
  // (the last two inside subtle tinted circles). Neutral tints so both
  // light and dark mode stay legible.
  Widget _buildLeadingIcon() {
    if (isCurrent) {
      return SvgPicture.asset(
        'assets/images/Hohte_logo.svg',
        width: 22,
        height: 22,
        colorFilter: ColorFilter.mode(AppColors.primaryAccent, BlendMode.srcIn),
      );
    }
    if (isPast && distanceFromCurrent == 1) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.textSecondary.withValues(alpha: 0.15),
        ),
        child: Icon(Icons.check_rounded, size: 14, color: AppColors.textSecondary),
      );
    }
    if (!isPast && distanceFromCurrent == 1) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.textSecondary.withValues(alpha: 0.08),
        ),
        child: Icon(
          Icons.schedule_rounded,
          size: 13,
          color: AppColors.textSecondary.withValues(alpha: 0.7),
        ),
      );
    }
    return const SizedBox.shrink();
  }

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
              SizedBox(width: 34, child: Center(child: _buildLeadingIcon())),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  segment.text,
                  style: TextStyle(
                    fontFamily: 'serif',
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
