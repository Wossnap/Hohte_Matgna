import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:mobile/core/audio/audio_player.dart';
import 'package:mobile/core/utils/wakelock_manager.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/core/api/api_client.dart';
import '../view_models/hymn_detail_viewmodel.dart';

class LiveCompareWidget extends StatefulWidget {
  final String referenceUrl;
  final String recordedFilePath;
  final List<double> breakpoints;
  final Function(bool isActive) onActiveChange;
  // When true, drive the shared hymn karaoke from the reference phase position
  // (hymn-level only — a section's alternating playback must not move the main
  // hymn karaoke).
  final bool syncKaraoke;
  // The already-prepared main melody player. Reusing it for the reference phase
  // avoids re-downloading the reference mp3 (~20s on first tap) and lets the
  // karaoke follow the proven main-player path. When null, an own player is
  // created and the source is loaded lazily.
  final AudioPlayer? referencePlayer;
  // Reference duration known from the model (instant) — used to bound the final
  // segment without polling getDuration over the network.
  final int? referenceDurationSeconds;

  const LiveCompareWidget({
    super.key,
    required this.referenceUrl,
    required this.recordedFilePath,
    required this.breakpoints,
    required this.onActiveChange,
    this.syncKaraoke = false,
    this.referencePlayer,
    this.referenceDurationSeconds,
  });

  @override
  State<LiveCompareWidget> createState() => _LiveCompareWidgetState();
}

class _LiveCompareWidgetState extends State<LiveCompareWidget> {
  // Created only when no shared reference player is supplied.
  AudioPlayer? _ownRefPlayer;
  final AudioPlayer _recPlayer = AudioPlayer();

  // The reference player actually used — the shared main melody player when
  // provided, otherwise our own. We NEVER dispose the shared player.
  AudioPlayer get _refPlayer => widget.referencePlayer ?? _ownRefPlayer!;
  bool get _ownsRefPlayer => widget.referencePlayer == null;

  // Subscriptions we add (on whichever ref player + the rec player); cancelled
  // in dispose so we stop driving a shared player after this widget is gone.
  final List<StreamSubscription> _subscriptions = [];

  bool _isActive = false;
  bool _isPreparing = false; // loading sources / computing ranges
  bool _isPaused = false;
  // Guards _advanceFromReference/_advanceFromRecorded against double-firing
  // when both the position-based check and the onPlayerComplete fallback
  // detect the same phase ending. Reset whenever a new phase starts.
  bool _advancedThisPhase = false;
  int _currentSegmentIndex = 0;
  String _phase = 'reference'; // 'reference' or 'recorded'
  Duration _startTime = Duration.zero;
  Duration _endTime = Duration.zero;
  Duration _position = Duration.zero;

  // Reference duration, captured from onDurationChanged once the source is
  // prepared (more reliable than polling getDuration right after setSource).
  Duration _refDuration = Duration.zero;
  // The recorded source is pre-warmed as soon as the widget mounts so the FIRST
  // tap on play works.
  bool _sourcesReady = false;
  Future<void>? _preloadFuture;

  HymnDetailViewModel? _viewModel;

  List<({Duration start, Duration end})> _ranges = [];

  AudioPlayer get _activePlayer => _phase == 'reference' ? _refPlayer : _recPlayer;

  @override
  void initState() {
    super.initState();
    if (_ownsRefPlayer) _ownRefPlayer = AudioPlayer();
    // Seed the duration from the model when available.
    final known = widget.referenceDurationSeconds;
    if (known != null && known > 0) {
      _refDuration = Duration(seconds: known);
    }
    _setupPlayers();
    // Begin preparing the recorded (and, if owned, reference) source immediately.
    _preloadFuture = _preloadSources();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.syncKaraoke && _viewModel == null) {
      try {
        _viewModel = Provider.of<HymnDetailViewModel>(context, listen: false);
      } catch (_) {
        _viewModel = null;
      }
    }
  }

  void _setupPlayers() {
    _refPlayer.setReleaseMode(ReleaseMode.stop);
    _recPlayer.setReleaseMode(ReleaseMode.stop);

    _subscriptions.add(_refPlayer.onDurationChanged.listen((d) {
      if (d > Duration.zero) _refDuration = d;
    }));

    _subscriptions.add(_refPlayer.onPositionChanged.listen((pos) {
      if (_isActive && _phase == 'reference' && !_isPaused) {
        if (mounted) setState(() => _position = pos);
        // Drive the karaoke from the reference phase (absolute hymn position).
        _viewModel?.alternateElapsedMs.value = pos.inMilliseconds;
        if (pos >= _endTime - const Duration(milliseconds: 100)) {
          _advanceFromReference();
        }
      }
    }));

    _subscriptions.add(_recPlayer.onPositionChanged.listen((pos) {
      if (_isActive && _phase == 'recorded' && !_isPaused) {
        if (mounted) setState(() => _position = pos);
        if (pos >= _endTime - const Duration(milliseconds: 100)) {
          _advanceFromRecorded();
        }
      }
    }));

    // Fallback for the FINAL segment specifically: its range end equals the
    // true end of the source, and on that last stretch the position stream
    // sometimes stops delivering updates (platform-dependent) before it ever
    // reports a value within 100ms of the end — so the position-based check
    // above never fires and the sequence hangs on "reference" forever with no
    // way to reach the recorded phase. The player's own completion event is a
    // reliable fallback for exactly that case. Guarded by _advancedThisPhase
    // so whichever signal arrives first wins and the other is a no-op.
    _subscriptions.add(_refPlayer.onPlayerComplete.listen((_) {
      if (_isActive && _phase == 'reference') _advanceFromReference();
    }));
    _subscriptions.add(_recPlayer.onPlayerComplete.listen((_) {
      if (_isActive && _phase == 'recorded') _advanceFromRecorded();
    }));
  }

  void _advanceFromReference() {
    if (_advancedThisPhase) return;
    _advancedThisPhase = true;
    _refPlayer.pause();
    _startRecordedSegment(_currentSegmentIndex);
  }

  void _advanceFromRecorded() {
    if (_advancedThisPhase) return;
    _advancedThisPhase = true;
    _recPlayer.pause();
    if (_currentSegmentIndex < _ranges.length - 1) {
      _startReferenceSegment(_currentSegmentIndex + 1);
    } else {
      _stop();
    }
  }

  // Prepares the recorded player's source up-front. The reference player is the
  // shared main melody player (already prepared) when provided; we only load a
  // reference source when we own the player, or as a safety net if the shared
  // one somehow has no source yet (user never played the main melody).
  Future<void> _preloadSources() async {
    try {
      if (_ownsRefPlayer) {
        await _setReferenceSource(_refPlayer);
      } else if (_refPlayer.source == null) {
        // Safety net: the main melody hasn't been loaded yet.
        await _setReferenceSource(_refPlayer);
      }

      if (kIsWeb) {
        await _recPlayer.setSource(UrlSource(widget.recordedFilePath));
      } else {
        await _recPlayer.setSource(DeviceFileSource(widget.recordedFilePath));
      }
      _sourcesReady = true;
    } catch (e) {
      debugPrint('LiveCompare preload error: $e');
    }
  }

  Future<void> _setReferenceSource(AudioPlayer player) async {
    if (kIsWeb) {
      try {
        final response = await ApiClient.fetchAudioBytes(widget.referenceUrl);
        await player.setSource(BytesSource(response.bodyBytes));
      } catch (e) {
        debugPrint('LiveCompare ref fallback to UrlSource: $e');
        await player.setSource(UrlSource(widget.referenceUrl));
      }
    } else {
      await player.setSource(UrlSource(widget.referenceUrl));
    }
  }

  @override
  void dispose() {
    // Release the wakelock if we're torn down mid-session (e.g. user navigates
    // away without hitting stop).
    WakelockManager.release('alternating');
    if (widget.syncKaraoke && _isActive) {
      _viewModel?.setAlternatePlaybackActive(false);
    }
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    // Never dispose the shared main melody player.
    _ownRefPlayer?.dispose();
    _recPlayer.dispose();
    super.dispose();
  }

  // Computes the [start,end] segments from the breakpoints. Waits for the
  // reference duration to arrive (only the final segment needs it).
  Future<void> _computeRanges() async {
    if (_refDuration <= Duration.zero) {
      for (int i = 0; i < 20 && _refDuration <= Duration.zero; i++) {
        final d = await _refPlayer.getDuration();
        if (d != null && d > Duration.zero) {
          _refDuration = d;
          break;
        }
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    final sortedBreakpoints = [...widget.breakpoints]..sort();
    final boundaries = [0.0, ...sortedBreakpoints];

    final ranges = <({Duration start, Duration end})>[];
    for (int i = 0; i < boundaries.length; i++) {
      final start = Duration(milliseconds: (boundaries[i] * 1000).toInt());
      final end = i < boundaries.length - 1
          ? Duration(milliseconds: (boundaries[i + 1] * 1000).toInt())
          : _refDuration;
      if (end > start) {
        ranges.add((start: start, end: end));
      }
    }
    _ranges = ranges;
  }

  Future<void> _start() async {
    setState(() {
      _isActive = true;
      _isPreparing = true;
      _isPaused = false;
    });
    widget.onActiveChange(true);
    // Only hymn-level alternating playback collapses the whole screen — a
    // section's own control uses its local onActiveChange instead. Sections
    // are hidden entirely while the screen is collapsed, so if a section
    // triggered this it would tear itself down mid-session.
    if (widget.syncKaraoke) _viewModel?.setAlternatePlaybackActive(true);
    // Keep the screen on for the whole session. Alternating playback advances by
    // listening to each player's position updates; if the screen dims/locks those
    // get throttled/suspended and the sequence stalls.
    WakelockManager.acquire('alternating');

    // Make sure the sources finished preparing before we play.
    await (_preloadFuture ?? _preloadSources());
    if (!_sourcesReady) {
      // Retry once if the initial preload failed.
      await _preloadSources();
    }

    await _computeRanges();
    if (!mounted) return;
    if (_ranges.isEmpty) {
      _stop();
      return;
    }

    setState(() => _isPreparing = false);
    _startReferenceSegment(0);
  }

  void _stop() {
    _refPlayer.pause();
    _recPlayer.pause();
    setState(() {
      _isActive = false;
      _isPreparing = false;
      _isPaused = false;
      _currentSegmentIndex = 0;
    });
    widget.onActiveChange(false);
    if (widget.syncKaraoke) _viewModel?.setAlternatePlaybackActive(false);
    WakelockManager.release('alternating');
  }

  void _startReferenceSegment(int index) {
    if (!mounted) return;
    final range = _ranges[index];
    _recPlayer.pause();
    setState(() {
      _currentSegmentIndex = index;
      _phase = 'reference';
      _startTime = range.start;
      _endTime = range.end;
      _position = range.start;
      _isPaused = false;
      _advancedThisPhase = false;
    });
    _refPlayer.seek(range.start);
    _refPlayer.resume();
  }

  void _startRecordedSegment(int index) {
    if (!mounted) return;
    final range = _ranges[index];
    _refPlayer.pause();
    setState(() {
      _phase = 'recorded';
      _startTime = range.start;
      _endTime = range.end;
      _position = range.start;
      _isPaused = false;
      _advancedThisPhase = false;
    });
    _recPlayer.seek(range.start);
    _recPlayer.resume();
  }

  // Pause / resume the currently-playing phase.
  void _togglePause() {
    if (!_isActive) return;
    if (_isPaused) {
      _activePlayer.resume();
      setState(() => _isPaused = false);
    } else {
      _activePlayer.pause();
      setState(() => _isPaused = true);
    }
  }

  // Jump to the previous / next segment (always restarting at its reference phase).
  void _prevSegment() {
    if (!_isActive) return;
    final target = (_currentSegmentIndex - 1).clamp(0, _ranges.length - 1);
    _startReferenceSegment(target);
  }

  void _nextSegment() {
    if (!_isActive) return;
    final target = _currentSegmentIndex + 1;
    if (target >= _ranges.length) {
      _stop();
    } else {
      _startReferenceSegment(target);
    }
  }

  // Scrub within the currently-playing segment.
  void _seek(double ms) {
    final target = Duration(milliseconds: ms.toInt());
    setState(() => _position = target);
    _activePlayer.seek(target);
    if (_phase == 'reference') {
      _viewModel?.alternateElapsedMs.value = target.inMilliseconds;
    }
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.inMinutes}:${two(d.inSeconds.remainder(60))}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isPreparing ? null : (_isActive ? _stop : _start),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isActive ? Colors.red : AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(
              _isPreparing
                  ? 'Starting…'
                  : (_isActive ? 'Stop Alternating Playback' : 'Start Alternating Playback'),
            ),
          ),
        ),
        if (_isActive && !_isPreparing) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.compare_arrows, size: 16, color: AppColors.primaryAccent),
                    const SizedBox(width: 8),
                    Text(
                      _phase == 'reference' ? 'Reference' : 'Recorded',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _phase == 'reference' ? Colors.blue : Colors.green,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Segment ${_currentSegmentIndex + 1}/${_ranges.length}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
                // Seek within the current segment.
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: AppColors.primaryAccent,
                    inactiveTrackColor: AppColors.primaryAccent.withValues(alpha: 0.2),
                    thumbColor: AppColors.primaryAccent,
                  ),
                  child: Slider(
                    min: _startTime.inMilliseconds.toDouble(),
                    max: _endTime.inMilliseconds.toDouble() > _startTime.inMilliseconds.toDouble()
                        ? _endTime.inMilliseconds.toDouble()
                        : _startTime.inMilliseconds.toDouble() + 1,
                    value: _position.inMilliseconds
                        .toDouble()
                        .clamp(_startTime.inMilliseconds.toDouble(), _endTime.inMilliseconds.toDouble()),
                    onChanged: _seek,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmt(_position), style: AppTextStyles.caption),
                    Text(_fmt(_endTime), style: AppTextStyles.caption),
                  ],
                ),
                const SizedBox(height: 4),
                // Prev / Pause / Next controls.
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: _currentSegmentIndex > 0 ? _prevSegment : null,
                      icon: const Icon(Icons.skip_previous_rounded, size: 20),
                      label: const Text('Prev'),
                      style: TextButton.styleFrom(foregroundColor: AppColors.primaryAccent),
                    ),
                    // Pause / resume the current phase.
                    Material(
                      color: AppColors.primary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _togglePause,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            _isPaused ? Icons.play_arrow : Icons.pause,
                            size: 22,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _currentSegmentIndex < _ranges.length - 1 ? _nextSegment : null,
                      icon: const Icon(Icons.skip_next_rounded, size: 20),
                      label: const Text('Next'),
                      style: TextButton.styleFrom(foregroundColor: AppColors.primaryAccent),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
