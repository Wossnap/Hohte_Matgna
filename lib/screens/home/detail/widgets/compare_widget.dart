import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/providers/practice_provider.dart';
import 'package:mobile/screens/home/detail/view_models/hymn_detail_viewmodel.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/utils/wakelock_manager.dart';
import 'package:mobile/core/audio/audio_player.dart';
import 'package:mobile/screens/home/detail/widgets/note_comparison_graph.dart';
import 'live_compare_widget.dart';
import '../../../../../models/attempt_model.dart';

class CompareWidget extends StatefulWidget {
  final int hymnId;
  final String playableType;
  final int? playableId; // Optional section ID
  final String label;
  final bool isInteractive;
  // The main melody's audio player (hymn-level only). Passed to the alternating
  // playback so it reuses the already-prepared reference instead of downloading
  // it again (~20s on first tap) and so the karaoke follows it natively.
  final AudioPlayer? mainAudioPlayer;

  const CompareWidget({
    super.key,
    required this.hymnId,
    required this.playableType,
    this.playableId,
    this.label = 'Compare with reference',
    this.isInteractive = false,
    this.mainAudioPlayer,
  });

  @override
  State<CompareWidget> createState() => _CompareWidgetState();
}

class _CompareWidgetState extends State<CompareWidget> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _playbackPlayer = AudioPlayer();
  final AudioPlayer _helperPlayer = AudioPlayer();
  // A stable Tween instance (not recreated per build) so TweenAnimationBuilder
  // only plays the pop-in once when the score pill first appears, rather than
  // replaying on every unrelated rebuild while alternating playback runs.
  static final Tween<double> _scorePopTween = Tween(begin: 0.6, end: 1.0);
  
  // State
  bool _isRecording = false;
  bool _isPaused = false;
  bool _isSubmitting = false;
  bool _recordingCompleted = false; // New state
  bool _preparing = false; // Between countdown end and recorder actually starting
  int _countdown = 0;
  Timer? _countdownTimer;
  Duration _maxDuration = Duration.zero;
  Duration _elapsed = Duration.zero;
  Timer? _elapsedTimer;
  
  String? _recordedFilePath;
  bool _isPlayingPlayback = false;
  Duration _playbackPosition = Duration.zero;
  Duration _playbackDuration = Duration.zero;
  
  // Scoring State
  String? _errorMessage;
  String? _successMessage;
  Attempt? _latestAttempt;
  final String _algorithm = 'default';
  
  // UI State — graph shows automatically; note sequences are hidden until asked.
  bool _showGraph = true;
  bool _showNotes = false;
  
  List<double> _breakpoints = [];
  bool _isLiveActive = false;
  // While alternating playback runs, the score/analysis are hidden by default
  // (bug #60) but the user can reveal them without stopping playback.
  bool _showResultWhileLive = false;

  @override
  void initState() {
    super.initState();
    _playbackPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlayingPlayback = false;
          _playbackPosition = Duration.zero;
        });
      }
    });
    _playbackPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _playbackPosition = p);
    });
    _playbackPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _playbackDuration = d);
    });
    _loadBreakpoints();
  }

  // Drive the karaoke's recording sync (hymn-level only — a section recording
  // must not animate the main hymn karaoke). Mirrors the web passing
  // isRecording / recordingElapsedMs into KaraokeLyrics.
  void _setKaraokeRecording(bool recording, {int elapsedMs = 0}) {
    if (widget.playableType != 'hymn' || !mounted) return;
    try {
      final vm = Provider.of<HymnDetailViewModel>(context, listen: false);
      if (recording) vm.recordingElapsedMs.value = elapsedMs;
      vm.isRecording.value = recording;
    } catch (_) {}
  }

  void _updateKaraokeElapsed(int ms) {
    if (widget.playableType != 'hymn' || !mounted) return;
    try {
      Provider.of<HymnDetailViewModel>(context, listen: false)
          .recordingElapsedMs.value = ms;
    } catch (_) {}
  }

  Future<void> _loadBreakpoints() async {
    final provider = Provider.of<PracticeProvider>(context, listen: false);
    try {
      final pts = await provider.getBreakpoints(
        playableType: widget.playableType,
        playableId: widget.playableId ?? widget.hymnId,
      );
      if (mounted) setState(() => _breakpoints = pts);
    } catch (_) {}
  }

  @override
  void dispose() {
    // Safety net if we're torn down mid-recording.
    WakelockManager.release('recording');
    _audioRecorder.dispose();
    _playbackPlayer.dispose();
    _helperPlayer.dispose();
    _countdownTimer?.cancel();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  Future<void> _startFlow() async {
    // Ask for the mic up-front so the countdown isn't followed by a permission
    // prompt / failure, and so recording can start the instant it ends.
    final status = await Permission.microphone.request();
    if (!mounted) return;
    if (!status.isGranted) {
      setState(() => _errorMessage = 'Microphone permission denied');
      return;
    }

    setState(() {
      _errorMessage = null;
      _successMessage = null;
      _latestAttempt = null;
      _countdown = 3;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      // When the count would hit zero, begin immediately and switch straight to
      // the "preparing" state in the SAME frame — otherwise there's a ~1s window
      // where _countdown == 0 but recording hasn't started, and the Start button
      // flashes back.
      if (_countdown <= 1) {
        timer.cancel();
        _countdownTimer = null;
        setState(() {
          _countdown = 0;
          _preparing = true;
        });
        _beginRecording();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  Future<void> _beginRecording() async {
    if (!mounted) return;
    // Keep the "preparing" UI up so the Start button doesn't flash back while
    // the recorder spins up.
    setState(() => _preparing = true);

    try {
      String? path;
      if (!kIsWeb) {
        final tempDir = await getTemporaryDirectory();
        // Record AAC in an .m4a container on mobile. The server's mimetypes
        // validation detects this as audio/mp4 (an accepted type), whereas a
        // PCM .wav is detected as audio/x-wav and rejected.
        path = '${tempDir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
      }

      // Start the recorder IMMEDIATELY — do not block on loading the reference
      // audio for its duration first (that network load took several seconds,
      // during which the Start button reappeared and recording started late).
      await _audioRecorder.start(
        RecordConfig(
          encoder: kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc,
          numChannels: 1,
          sampleRate: 48000,
          bitRate: 128000,
        ),
        path: path ?? '',
      );

      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _preparing = false;
        _isPaused = false;
        _recordedFilePath = null;
        _elapsed = Duration.zero;
        _maxDuration = Duration.zero; // resolved in the background below
      });

      // Keep the screen on while recording so an auto-dim/lock doesn't suspend
      // the recorder/timer mid-take.
      WakelockManager.acquire('recording');
      _setKaraokeRecording(true, elapsedMs: 0); // start karaoke recording sync
      _startTimer();
      _resolveMaxDuration(); // fire-and-forget
    } catch (e) {
      if (mounted) {
        setState(() {
          _preparing = false;
          _errorMessage = 'Failed to start recording: $e';
        });
      }
    }
  }

  /// Reference duration (seconds) known from the model, without any network.
  int? _knownReferenceDurationSeconds() {
    final provider = Provider.of<PracticeProvider>(context, listen: false);
    if (widget.playableType == 'hymn') {
      return provider.currentHymn?.hymn.duration;
    }
    return provider.currentHymn?.sections
        .where((s) => s.id == widget.playableId)
        .firstOrNull
        ?.duration;
  }

  /// Determines the hard-stop duration = reference length + buffer, matching the
  /// web (`getRecordingBuffer`: at least 2s, at most 5s, ~50% of the clip).
  /// Prefers the model's known duration (instant); only falls back to loading
  /// the reference audio metadata if that's missing.
  Future<void> _resolveMaxDuration() async {
    int? refSeconds = _knownReferenceDurationSeconds();

    if (refSeconds == null || refSeconds <= 0) {
      try {
        final provider = Provider.of<PracticeProvider>(context, listen: false);
        final refUrl = widget.playableType == 'hymn'
            ? provider.currentHymn?.hymn.audioUrl
            : provider.currentHymn?.sections
                .where((s) => s.id == widget.playableId)
                .firstOrNull
                ?.audioUrl;
        if (refUrl != null) {
          if (kIsWeb) {
            try {
              final r = await ApiClient.fetchAudioBytes(refUrl);
              await _helperPlayer.setSource(BytesSource(r.bodyBytes));
            } catch (_) {
              await _helperPlayer.setSource(UrlSource(refUrl));
            }
          } else {
            await _helperPlayer.setSource(UrlSource(refUrl));
          }
          final d = await _helperPlayer.getDuration();
          if (d != null) refSeconds = d.inSeconds;
        }
      } catch (_) {}
    }

    if (!mounted || !_isRecording) return;
    final resolved = refSeconds;
    if (resolved != null && resolved > 0) {
      final buffer = (resolved * 0.5).clamp(2.0, 5.0);
      setState(() => _maxDuration =
          Duration(milliseconds: ((resolved + buffer) * 1000).round()));
    } else {
      // Safety cap if the duration can't be determined at all.
      setState(() => _maxDuration = const Duration(seconds: 180));
    }
  }

  void _startTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!_isPaused) {
        setState(() {
          _elapsed += const Duration(milliseconds: 100);
          // Auto-stop at reference length + buffer, once it's been resolved.
          if (_maxDuration > Duration.zero && _elapsed >= _maxDuration) {
            _stopRecording();
          }
        });
        _updateKaraokeElapsed(_elapsed.inMilliseconds); // sync karaoke highlight
      }
    });
  }

  Future<void> _pauseRecording() async {
    if (!_isRecording || _isPaused) return;
    await _audioRecorder.pause();
    setState(() => _isPaused = true);
  }

  Future<void> _resumeRecording() async {
    if (!_isRecording || !_isPaused) return;
    await _audioRecorder.resume();
    setState(() => _isPaused = false);
  }

  Future<void> _cancelRecording() async {
    _elapsedTimer?.cancel();
    _countdownTimer?.cancel();
    _setKaraokeRecording(false);
    WakelockManager.release('recording');
    await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _isPaused = false;
      _countdown = 0;
      _elapsed = Duration.zero;
      _errorMessage = 'Recording cancelled';
    });
  }

  Future<void> _stopRecording() async {
    _elapsedTimer?.cancel();
    _setKaraokeRecording(false);
    WakelockManager.release('recording');
    final path = await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _isPaused = false;
      _recordedFilePath = path;
      _recordingCompleted = true;
    });
    // Auto-compare straight away — no "Recording complete" popup.
    _showScore();
  }

  Future<void> _showScore() async {
    if (_recordedFilePath == null) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final provider = Provider.of<PracticeProvider>(context, listen: false);
      debugPrint('Starting comparison for playableType: ${widget.playableType}, playableId: ${widget.playableId ?? widget.hymnId}');
      final attempt = await provider.submitAndPollComparison(
        audioFilePath: _recordedFilePath!,
        playableType: widget.playableType,
        playableId: widget.playableId ?? widget.hymnId,
        algorithm: _algorithm,
      );

      debugPrint('Comparison result received: ${attempt?.score}');

      if (!mounted) return;

      // Result is shown INLINE (score badge + analysis + playback), like the
      // web — no popup. The recorded player stays available.
      setState(() {
        _latestAttempt = attempt;
        _recordingCompleted = false;
        _successMessage = attempt != null ? '${attempt.score?.toStringAsFixed(1)}%' : null;
        _isSubmitting = false;
        if (attempt == null) {
          _errorMessage = 'Comparison completed but no result received';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Comparison failed: $e';
        _isSubmitting = false;
      });
    }
  }

  void _cancelAfterRecording() {
    setState(() {
      _recordingCompleted = false;
      _recordedFilePath = null;
      _latestAttempt = null;
      _errorMessage = 'Recording discarded';
      _successMessage = null;
    });
  }

  void _playRecordedFile() {
    if (_recordedFilePath == null) return;
    if (_isPlayingPlayback) {
      _playbackPlayer.pause();
      setState(() => _isPlayingPlayback = false);
    } else {
      _playbackPlayer.play(
        kIsWeb ? UrlSource(_recordedFilePath!) : DeviceFileSource(_recordedFilePath!),
      );
      setState(() => _isPlayingPlayback = true);
    }
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PracticeProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final refUrl = widget.isInteractive || widget.playableType == 'hymn' 
          ? provider.currentHymn?.hymn.audioUrl 
          : provider.currentHymn?.sections.where((s) => s.id == widget.playableId).firstOrNull?.audioUrl;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (no algorithm selector — matches the web). Hidden during
          // alternating playback so the view collapses to just the live control.
          if (!_isLiveActive) ...[
            Text(
              widget.label,
              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),
          ],

          // Score stays visible (without stopping playback) once the user asks
          // for it via "Show result" — see the two conditions below.
          if (_isLiveActive && _latestAttempt?.score != null) ...[
            _buildLiveScorePop(_latestAttempt!.score!),
            const SizedBox(height: 8),
          ],

          // Action Buttons
          if (!_isRecording && _countdown == 0 && !_isSubmitting && !_preparing && !_isLiveActive)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _startFlow,
                icon: const Icon(Icons.mic_rounded),
                label: const Text('Start Recording'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

          if (_countdown > 0)
            Center(
              child: Column(
                children: [
                  Text(
                    'Get Ready!',
                    style: TextStyle(color: AppColors.primaryAccent, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_countdown',
                    style: AppTextStyles.headerLarge.copyWith(color: AppColors.primaryAccent, fontSize: 48),
                  ),
                ],
              ),
            ),

          if (_preparing && _countdown == 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Starting…',
                  style: TextStyle(color: AppColors.primaryAccent, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),

          if (_isRecording)
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        const Text('RECORDING', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 12)),
                      ],
                    ),
                    Text(
                      '${(_elapsed.inMilliseconds / 1000).toStringAsFixed(1)}s / ${_maxDuration > Duration.zero ? '${(_maxDuration.inMilliseconds / 1000).toStringAsFixed(1)}s' : '…'}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isPaused ? _resumeRecording : _pauseRecording,
                        icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                        label: Text(_isPaused ? 'Resume' : 'Pause'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _stopRecording,
                        icon: const Icon(Icons.stop),
                        label: const Text('End'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _cancelRecording,
                  child: const Text('Cancel Request', style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),

          if (_recordingCompleted && !_isSubmitting)
            Column(
              children: [
                const Text('Recording completed!', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _showScore,
                        icon: const Icon(Icons.show_chart),
                        label: const Text('Show Score'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _cancelAfterRecording,
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                  ],
                ),
              ],
            ),

          if (_isSubmitting)
            const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Analyzing your performance...', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),

          // Feedback Messages
          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1), 
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: AppColors.error, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_errorMessage!, style: TextStyle(color: AppColors.error, fontSize: 12))),
                ],
              ),
            ),

          if (_latestAttempt != null && _latestAttempt!.score != null && (!_isLiveActive || _showResultWhileLive)) ...[
            const SizedBox(height: 16),
            _buildFeedbackBadge(_latestAttempt!.score!),
            if (_latestAttempt!.analysis?['length_penalty'] != null && 
                (_latestAttempt!.analysis!['length_penalty']['penalty_percent'] ?? 0) > 0)
              _buildLengthPenalty(_latestAttempt!.analysis!['length_penalty']),
          ],

          if (_successMessage != null && _latestAttempt == null)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: AppColors.success, size: 16),
                  const SizedBox(width: 8),
                  Text(_successMessage!, style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),

          // Analysis Display (matching Vue logic)
          if (_latestAttempt != null && _latestAttempt!.analysis != null && (!_isLiveActive || _showResultWhileLive)) ...[
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            
            _buildInfoRow('Reference Duration', _latestAttempt!.analysis!['reference_audio']?['duration_formatted'] ?? 'N/A'),
            _buildInfoRow('Recorded Duration', _latestAttempt!.analysis!['recorded_audio']?['duration_formatted'] ?? 'N/A'),

            // Note comparison: the graph is shown automatically (hideable); the
            // raw note sequences stay hidden until the user asks for them.
            Builder(builder: (_) {
              final refNotes = List<String>.from(_latestAttempt!.analysis!['note_sequences']?['reference'] ?? []);
              final recNotes = List<String>.from(_latestAttempt!.analysis!['note_sequences']?['recorded'] ?? []);
              if (refNotes.isEmpty && recNotes.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Graph toggle (default visible)
                  _buildAnalysisToggle(
                    title: _showGraph ? 'Hide note graph' : 'Show note graph',
                    isActive: _showGraph,
                    onTap: () => setState(() => _showGraph = !_showGraph),
                    content: NoteComparisonGraph(
                      referenceNotes: refNotes,
                      recordedNotes: recNotes,
                    ),
                  ),

                  // Note sequences toggle (default hidden)
                  _buildAnalysisToggle(
                    title: _showNotes ? 'Hide note sequences' : 'Show note sequences',
                    isActive: _showNotes,
                    onTap: () => setState(() => _showNotes = !_showNotes),
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSubInfo('Reference notes', refNotes.isEmpty ? 'None' : refNotes.join(', ')),
                        _buildSubInfo('Recorded notes', recNotes.isEmpty ? 'None' : recNotes.join(', ')),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ],

          // Playback & Live Compare
          if (_recordedFilePath != null && !_isLiveActive && !_isRecording) ...[
            const SizedBox(height: 24),
            Text('Playback Recording', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton.filled(
                  onPressed: _playRecordedFile,
                  icon: Icon(_isPlayingPlayback ? Icons.pause : Icons.play_arrow),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                          activeTrackColor: AppColors.primaryAccent,
                          inactiveTrackColor: AppColors.primaryAccent.withValues(alpha: 0.2),
                          thumbColor: AppColors.primaryAccent,
                        ),
                        child: Slider(
                          value: _playbackPosition.inMilliseconds
                              .toDouble()
                              .clamp(0, _playbackDuration.inMilliseconds > 0 ? _playbackDuration.inMilliseconds.toDouble() : 1),
                          max: _playbackDuration.inMilliseconds > 0 ? _playbackDuration.inMilliseconds.toDouble() : 1,
                          onChanged: (v) => _playbackPlayer.seek(Duration(milliseconds: v.toInt())),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatDuration(_playbackPosition), style: AppTextStyles.caption),
                            Text(_formatDuration(_playbackDuration), style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],

          if (_recordedFilePath != null && refUrl != null && _breakpoints.isNotEmpty && !_isRecording) ...[
            const SizedBox(height: 20),
            LiveCompareWidget(
              referenceUrl: refUrl,
              recordedFilePath: _recordedFilePath!,
              breakpoints: _breakpoints,
              syncKaraoke: widget.playableType == 'hymn',
              // Reuse the already-prepared main melody player for the reference
              // phase (hymn-level only) — eliminates the first-tap download wait
              // and lets the karaoke follow natively.
              referencePlayer: widget.playableType == 'hymn' ? widget.mainAudioPlayer : null,
              referenceDurationSeconds: _knownReferenceDurationSeconds(),
              onActiveChange: (active) => setState(() {
                _isLiveActive = active;
                if (!active) _showResultWhileLive = false;
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildAnalysisToggle({required String title, required bool isActive, required VoidCallback onTap, required Widget content}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          child: Text(title, style: TextStyle(fontSize: 12, color: AppColors.primaryAccent, decoration: TextDecoration.underline)),
        ),
        if (isActive) Padding(padding: const EdgeInsets.only(top: 8, bottom: 8), child: content),
      ],
    );
  }

  Widget _buildSubInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 11, color: Colors.grey),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value.isEmpty ? 'None' : value),
          ],
        ),
      ),
    );
  }

  // The compact, tappable score pill shown during alternating playback (bug
  // #60): pops in once when the score first becomes available, colored the
  // same way as the full result badge (_buildFeedbackBadge) so it reads as
  // "great/good/needs work" at a glance without stopping playback to see it.
  Widget _buildLiveScorePop(double score) {
    final Color color;
    final Color bgColor;
    final String emoji;
    if (score >= 80) {
      color = AppColors.great;
      bgColor = AppColors.greatBg;
      emoji = '🎉';
    } else if (score >= 65) {
      color = AppColors.good;
      bgColor = AppColors.goodBg;
      emoji = '👍';
    } else {
      color = AppColors.work;
      bgColor = AppColors.workBg;
      emoji = '💪';
    }

    return TweenAnimationBuilder<double>(
      tween: _scorePopTween,
      duration: const Duration(milliseconds: 450),
      curve: Curves.elasticOut,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _showResultWhileLive = !_showResultWhileLive),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color, width: 1.5),
            ),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Text(
                  '${score.toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color),
                ),
                const Spacer(),
                Icon(
                  _showResultWhileLive ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: color,
                ),
                Text(
                  _showResultWhileLive ? 'Hide result' : 'Show result',
                  style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackBadge(double score) {
    Color color;
    Color bgColor;
    String label;
    String emoji;

    if (score >= 80) {
      color = AppColors.great;
      bgColor = AppColors.greatBg;
      label = 'GREAT';
      emoji = '🎉';
    } else if (score >= 65) {
      color = AppColors.good;
      bgColor = AppColors.goodBg;
      label = 'GOOD';
      emoji = '👍';
    } else {
      color = AppColors.work;
      bgColor = AppColors.workBg;
      label = 'NEEDS WORK';
      emoji = '💪';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$label: ${score.toStringAsFixed(1)}%',
                style: AppTextStyles.headerSmall.copyWith(color: color, fontWeight: FontWeight.w900, fontSize: 18),
              ),
              Text(
                'Performance accuracy',
                style: AppTextStyles.caption.copyWith(color: color.withValues(alpha: 0.7), fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLengthPenalty(Map<String, dynamic> penalty) {
    final double percent = (penalty['penalty_percent'] ?? 0).toDouble();
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.penaltyBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.penalty.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.penalty),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Length Penalty: -${percent.toStringAsFixed(1)}%',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.penalty, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Your recording duration differs significantly from the reference.',
                  style: AppTextStyles.caption.copyWith(color: AppColors.penalty.withValues(alpha: 0.8), fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

