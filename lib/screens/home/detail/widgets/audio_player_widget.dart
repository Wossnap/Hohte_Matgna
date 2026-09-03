import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/screens/home/detail/view_models/hymn_detail_viewmodel.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobile/screens/home/detail/widgets/metronome_widget.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  final AudioPlayer audioPlayer;
  final VoidCallback? onPlay;
  final int? playableId;
  final String? playableType;
  final int initialPlays;
  final int initialPractices;
  final double? startTime;
  final double? endTime;
  final int? bpm;
  final List<double>? beatTimestamps;
  // Optional content rendered between the controls and the subtle stats line —
  // used for the main melody to embed the karaoke right under the player, like
  // the web (player → karaoke → progress → plays/auto-stop).
  final Widget? embeddedContent;
  // When true, only the embedded content (the karaoke) is shown — the progress
  // bar, controls, stats and metronome are hidden. Used during alternating
  // playback so the screen collapses to just the karaoke + the live control.
  final bool hideChrome;

  const AudioPlayerWidget({
    super.key,
    required this.audioUrl,
    required this.audioPlayer,
    this.onPlay,
    this.playableId,
    this.playableType,
    this.initialPlays = 0,
    this.initialPractices = 0,
    this.startTime,
    this.endTime,
    this.bpm,
    this.beatTimestamps,
    this.embeddedContent,
    this.hideChrome = false,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget>
    with AutomaticKeepAliveClientMixin {
  // Keep this widget's State alive when it scrolls off-screen inside the
  // detail screen's SliverList. Otherwise scrolling away destroys the State
  // mid-playback: the auto-replay logic (guarded by `mounted`) stops firing, and
  // scrolling back recreates the State fresh — losing _completed/_loopCount and
  // resuming into the native completed state (frozen progress bar, garbled audio).
  @override
  bool get wantKeepAlive => true;

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  bool _isLoading = true;
  int _sessionPlayIncrements = 0; // Track increments during this session
  final List<double> _playbackRates = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  // All audio stream subscriptions, cancelled in dispose() to avoid leaks.
  final List<StreamSubscription> _subscriptions = [];

  // Auto-replay / loop state — LOCAL to this player so the main melody and each
  // section loop independently. Previously this was shared via the view-model,
  // which made a finishing section pause the *main* player and mis-count loops
  // (it also double-counted, auto-stopping at ~7 plays instead of 15).
  int _loopCount = 0;
  static const int _maxLoops = 15;
  bool _handlingCompletion = false;
  // True once playback has reached the end. resume() from a completed state is
  // unreliable on Android (fails to restart / leaves the position stream
  // frozen), so when this is set we restart with a fresh play() instead.
  bool _completed = false;
  // Mirror of the view-model playback rate, synced in build() so the restart
  // path (which runs outside build, without context) can re-apply it.
  double _playbackRate = 1.0;

  // Section boundaries
  Duration _sectionStart = Duration.zero;
  Duration _sectionEnd = Duration.zero;
  bool get _isSectionMode => widget.startTime != null || widget.endTime != null;
  
  // Section-relative position and duration
  Duration get _sectionPosition => _isSectionMode ? _position - _sectionStart : _position;
  Duration get _sectionDuration => _isSectionMode && _sectionEnd > _sectionStart ? _sectionEnd - _sectionStart : _duration;

  // Anti-cheat tracking
  double _listenedTimeSeconds = 0;
  DateTime? _lastPositionUpdate;
  static const double _minListenRatio = 0.8; // 80% threshold like website

  @override
  void initState() {
    super.initState();
    // Initialize section boundaries
    _sectionStart = widget.startTime != null ? Duration(seconds: widget.startTime!.toInt()) : Duration.zero;
    _sectionEnd = widget.endTime != null ? Duration(seconds: widget.endTime!.toInt()) : Duration.zero;
    
    _setupAudioPlayer();
    _setInitialSource();
    _startLoadingTimeout();
  }

  Future<void> _setInitialSource() async {
    try {
      _isLoading = true;
      if (kIsWeb) {
        debugPrint('Setting audio source for Web: ${widget.audioUrl}');
        try {
          final response = await ApiClient.fetchAudioBytes(widget.audioUrl);
          if (response.statusCode == 200) {
            debugPrint('Successfully fetched audio bytes for Web.');
            await widget.audioPlayer.setSource(BytesSource(response.bodyBytes));
            return;
          }
        } catch (e) {
          debugPrint('Web fallback: BytesSource failed (likely CORS), trying UrlSource directly. Error: $e');
        }
        debugPrint('Using UrlSource as fallback for Web.');
        await widget.audioPlayer.setSource(UrlSource(widget.audioUrl));
      } else {
        await widget.audioPlayer.setSource(UrlSource(widget.audioUrl));
      }
    } catch (e) {
      debugPrint('Error setting initial source: $e');
    } finally {
      if (widget.startTime != null) {
        await widget.audioPlayer.seek(Duration(seconds: widget.startTime!.toInt()));
      }
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startLoadingTimeout() {
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    });
  }

  void _setupAudioPlayer() {
    // CRITICAL for auto-replay: the default ReleaseMode.release frees the
    // native player when playback completes, so onPlayerComplete fires but the
    // subsequent seek()+resume() silently do nothing (the source is gone) — the
    // audio never loops. ReleaseMode.stop keeps the source loaded after the end
    // so we can seek back to the start and resume for each loop. (We can't use
    // ReleaseMode.loop: it loops natively forever and never fires
    // onPlayerComplete, so we couldn't count loops or auto-stop at the limit.)
    widget.audioPlayer.setReleaseMode(ReleaseMode.stop);

    _subscriptions.add(widget.audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    }));

    _subscriptions.add(widget.audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration;
          _isLoading = false;
        });
      }
    }));

    _subscriptions.add(widget.audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted && (state == PlayerState.playing || state == PlayerState.paused || state == PlayerState.completed)) {
        setState(() => _isLoading = false);
      }
    }));

    _subscriptions.add(widget.audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        // Track listened time for anti-cheat
        final now = DateTime.now();
        if (_isPlaying && _lastPositionUpdate != null) {
          final delta = now.difference(_lastPositionUpdate!).inMilliseconds / 1000.0;
          // If delta is reasonable (not a seek), add to listened time
          if (delta > 0 && delta < 1.0) {
            _listenedTimeSeconds += delta;
          }
        }
        _lastPositionUpdate = now;

        // Check if we've reached the section end
        if (_isSectionMode && _sectionEnd > Duration.zero && position >= _sectionEnd) {
          _onPlaybackFinished();
          return;
        }
        
        setState(() {
          _position = position;
        });
      }
    }));

    // Error handling to prevent infinite spinner
    _subscriptions.add(widget.audioPlayer.onLog.listen((log) {
      if (mounted) {
        final logLower = log.toLowerCase();
        if (logLower.contains('error') || logLower.contains('failed to set source')) {
          debugPrint('AudioPlayer Log Error: $log');
          if (_isLoading) setState(() => _isLoading = false);
        }
      }
    }));

    _subscriptions.add(widget.audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) _onPlaybackFinished();
    }));
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }

  /// Called when the current play reaches its end (full-file completion for the
  /// main melody / section audio, or the section boundary in section mode).
  /// Auto-replays the same audio until the per-player loop limit is hit, then
  /// stops and resets to the start — matching the Laravel web app's behaviour.
  void _onPlaybackFinished() {
    if (_handlingCompletion) return;
    // During hymn-level alternating playback, LiveCompareWidget takes over this
    // exact AudioPlayer instance (as its reference player) to play segments back
    // to back. Without this guard, the natural end-of-track completion on the
    // last segment also fires here, and this widget's own auto-replay restarts
    // the main hymn from zero mid-alternating-session — hijacking playback right
    // when the recorded phase should start, and again after a clean stop.
    if (widget.hideChrome) return;
    _handlingCompletion = true;
    // Mark completed up-front: if the replay below fails for any reason, the
    // manual play button will then take the fresh-restart path and recover,
    // instead of resume()-ing into a frozen state.
    _completed = true;

    // Anti-cheat: only count a play if enough of it was actually listened to.
    final totalDuration = _sectionDuration.inSeconds.toDouble();
    final isValidPlay = totalDuration > 0 &&
        (_listenedTimeSeconds >= totalDuration * _minListenRatio);
    if (isValidPlay) {
      widget.onPlay?.call();
      if (mounted) setState(() => _sessionPlayIncrements++);
    }
    _listenedTimeSeconds = 0;

    _loopCount++;
    final restartPosition = _isSectionMode ? _sectionStart : Duration.zero;

    if (_loopCount < _maxLoops) {
      // Auto-replay this same audio. Small delay lets the player settle after
      // completion before we start the fresh play().
      Future.delayed(const Duration(milliseconds: 300), () async {
        if (!mounted) {
          _handlingCompletion = false;
          return;
        }
        await _restartPlayback();
        _handlingCompletion = false;
      });
    } else {
      // Reached the auto-stop limit — stop and reset to the start.
      widget.audioPlayer.pause();
      widget.audioPlayer.seek(restartPosition);
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = restartPosition;
        });
      }
      _handlingCompletion = false;
    }
  }

  /// Restarts this audio from the beginning (section start in section mode) with
  /// a fresh play(). Unlike resume() from a completed state, play() reliably
  /// resets the native player and its position stream, so it's used for both
  /// auto-replay and the manual play button after playback has ended.
  Future<void> _restartPlayback() async {
    final restartPosition = _isSectionMode ? _sectionStart : Duration.zero;
    try {
      if (kIsWeb) {
        try {
          final response = await ApiClient.fetchAudioBytes(widget.audioUrl);
          await widget.audioPlayer.play(BytesSource(response.bodyBytes));
        } catch (e) {
          debugPrint('Web restart fallback to UrlSource: $e');
          await widget.audioPlayer.play(UrlSource(widget.audioUrl));
        }
      } else {
        await widget.audioPlayer.play(UrlSource(widget.audioUrl));
      }
      if (restartPosition > Duration.zero) {
        await widget.audioPlayer.seek(restartPosition);
      }
      await widget.audioPlayer.setPlaybackRate(_playbackRate);
      _completed = false;
      _listenedTimeSeconds = 0;
      _lastPositionUpdate = DateTime.now();
      if (mounted) setState(() => _position = restartPosition);
    } catch (e) {
      debugPrint('Error restarting playback: $e');
    }
  }

  Future<void> _togglePlayPause() async {
    final viewModel = Provider.of<HymnDetailViewModel>(context, listen: false);
    try {
      if (_isPlaying) {
        await widget.audioPlayer.pause();
      } else {
        if (_loopCount >= _maxLoops) {
          setState(() {
            _loopCount = 0;
            _sessionPlayIncrements = 0;
          });
        }
        _handlingCompletion = false;

        if (_completed) {
          // Playback had ended — start fresh so the position stream resets
          // (resume() from a completed state leaves the progress bar frozen).
          await _restartPlayback();
        } else if (widget.audioPlayer.source == null) {
          // First play of this widget — set source and play.
          if (kIsWeb) {
            try {
              final response = await ApiClient.fetchAudioBytes(widget.audioUrl);
              await widget.audioPlayer.play(BytesSource(response.bodyBytes));
            } catch (e) {
              debugPrint('Web play fallback to UrlSource: $e');
              await widget.audioPlayer.play(UrlSource(widget.audioUrl));
            }
          } else {
            await widget.audioPlayer.play(UrlSource(widget.audioUrl));
          }
          widget.audioPlayer.setPlaybackRate(viewModel.playbackRate);
          _lastPositionUpdate = DateTime.now(); // Reset for anti-cheat
        } else {
          // Un-pausing mid-track — resume from current position.
          if (_isSectionMode && _position < _sectionStart) {
            await widget.audioPlayer.seek(_sectionStart);
          }
          await widget.audioPlayer.resume();
          widget.audioPlayer.setPlaybackRate(viewModel.playbackRate);
          _lastPositionUpdate = DateTime.now(); // Reset for anti-cheat
        }
        // widget.onPlay?.call(); // Removed: call in _onPlaybackFinished instead for anti-cheat
      }
    } catch (e) {
      debugPrint('Audio playback error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        String errorMsg = e.toString();
        if (errorMsg.contains('NotSupportedError')) {
          errorMsg = 'This audio format is not supported by your browser.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Audio Error: $errorMsg')),
        );
      }
    }
  }

  Future<void> _seek(Duration position) async {
    if (_isSectionMode) {
      // For sections, position is relative to section start
      final absolutePosition = _sectionStart + position;
      // Constrain within section boundaries
      final constrainedPosition = absolutePosition.inSeconds < _sectionStart.inSeconds 
          ? _sectionStart 
          : (absolutePosition.inSeconds > _sectionEnd.inSeconds ? _sectionEnd : absolutePosition);
      await widget.audioPlayer.seek(constrainedPosition);
    } else {
      await widget.audioPlayer.seek(position);
    }
    // Reset anti-cheat on seek
    _listenedTimeSeconds = 0;
    _lastPositionUpdate = DateTime.now();
  }

  Future<void> _downloadAudio() async {
    final url = Uri.parse(widget.audioUrl);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not download audio: $e')),
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    final viewModel = Provider.of<HymnDetailViewModel>(context);
    _playbackRate = viewModel.playbackRate;
    final remainingLoops = _maxLoops - _loopCount;

    // Focused alternating-playback mode: show only the karaoke. The State stays
    // mounted (the chrome is just dropped from the tree), so playback/loop state
    // survives toggling in and out.
    if (widget.hideChrome) {
      return widget.embeddedContent ?? const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isLoading)
          Column(
            children: [
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 8),
              Text('Pre-buffering audio...', style: TextStyle(fontSize: 10, color: AppColors.primaryAccent)),
            ],
          )
        else ...[
          // Progress Bar
          Column(
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.primaryAccent,
                  inactiveTrackColor: AppColors.primaryAccent.withValues(alpha: 0.2),
                  thumbColor: AppColors.primaryAccent,
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                ),
                child: Slider(
                  value: _sectionPosition.inSeconds.toDouble().clamp(0, _sectionDuration.inSeconds.toDouble()),
                  max: _sectionDuration.inSeconds.toDouble() > 0 ? _sectionDuration.inSeconds.toDouble() : 1.0,
                  onChanged: (value) => _seek(Duration(seconds: value.toInt())),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDuration(_sectionPosition), style: AppTextStyles.caption),
                    Text(_formatDuration(_sectionDuration), style: AppTextStyles.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Controls Row: Download + Speed (left), circular Play/Pause (right)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.download_rounded, color: AppColors.primaryAccent),
                    onPressed: _downloadAudio,
                    tooltip: 'Download Audio',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.only(right: 12),
                  ),
                  _buildSpeedSelector(viewModel),
                ],
              ),

              // Circular play button (smaller), matching the web.
              Material(
                color: AppColors.primary,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _togglePlayPause,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 22,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Embedded content (e.g. the karaoke for the main melody), rendered
          // right under the player like the web.
          if (widget.embeddedContent != null) ...[
            const SizedBox(height: 12),
            widget.embeddedContent!,
          ],

          const SizedBox(height: 10),

          // Subtle playback stats (plays + auto-stop), muted and small, under
          // the karaoke/progress — matching the web's understated summary line.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'Plays: ${widget.initialPlays + _sessionPlayIncrements}   ·   '
                  'Auto-stops after $remainingLoops more play${remainingLoops == 1 ? '' : 's'}',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                  ),
                ),
              ),
              if (_loopCount > 0)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _loopCount = 0;
                      _sessionPlayIncrements = 0;
                    });
                  },
                  child: Text(
                    'Reset',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryAccent,
                    ),
                  ),
                ),
            ],
          ),

          // Metronome
          MetronomeWidget(
            bpm: widget.bpm,
            beatTimestamps: widget.beatTimestamps,
            currentPosition: _position,
            isPlaying: _isPlaying,
          ),
        ],
      ],
    );
  }

  Widget _buildSpeedSelector(HymnDetailViewModel viewModel) {
    return Row(
      children: [
        Text('Speed:', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<double>(
              value: viewModel.playbackRate,
              items: _playbackRates.map((rate) {
                return DropdownMenuItem(
                  value: rate,
                  child: Text('${rate}x', style: AppTextStyles.bodySmall.copyWith(fontSize: 10)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) viewModel.setPlaybackRate(val);
              },
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
}

