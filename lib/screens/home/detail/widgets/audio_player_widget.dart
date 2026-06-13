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
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  bool _isLoading = true;
  int _sessionPlayIncrements = 0; // Track increments during this session
  final List<double> _playbackRates = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  
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
    widget.audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    widget.audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration;
          _isLoading = false;
        });
      }
    });

    widget.audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted && (state == PlayerState.playing || state == PlayerState.paused || state == PlayerState.completed)) {
        setState(() => _isLoading = false);
      }
    });

    widget.audioPlayer.onPositionChanged.listen((position) {
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
          _handleFinish();
          return;
        }
        
        setState(() {
          _position = position;
        });
      }
    });

    // Error handling to prevent infinite spinner
    widget.audioPlayer.onLog.listen((log) {
      if (mounted) {
        final logLower = log.toLowerCase();
        if (logLower.contains('error') || logLower.contains('failed to set source')) {
          debugPrint('AudioPlayer Log Error: $log');
          if (_isLoading) setState(() => _isLoading = false);
        }
      }
    });

    widget.audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        // Increment progress on every completion/loop to match website parity
        widget.onPlay?.call();
        
        // Locally increment session plays for immediate feedback
        setState(() {
          _sessionPlayIncrements++;
        });

        // For sections, auto-replay from section start
        if (_isSectionMode) {
          // Small delay before replaying to avoid immediate restart
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              widget.audioPlayer.seek(_sectionStart);
              widget.audioPlayer.resume();
            }
          });
          return;
        }
        
        // For full hymns, handle looping logic
        final viewModel = Provider.of<HymnDetailViewModel>(context, listen: false);
        viewModel.incrementLoop();
        
        if (viewModel.loopCount < viewModel.maxLoops) {
          _handleFinish(autoResume: true);
        } else {
          _handleFinish(autoResume: false);
        }
      }
    });
  }

  void _handleFinish({bool autoResume = false}) {
    final viewModel = Provider.of<HymnDetailViewModel>(context, listen: false);
    
    // Anti-cheat verification
    final totalDuration = _sectionDuration.inSeconds.toDouble();
    final isValidPlay = totalDuration > 0 && (_listenedTimeSeconds >= totalDuration * _minListenRatio);
    
    if (isValidPlay) {
      // Only call onPlay (which increments backend play count) if valid
      widget.onPlay?.call();
    }
    
    // Reset listening state for next loop
    _listenedTimeSeconds = 0;
    
    if (_isSectionMode) {
      widget.audioPlayer.pause();
      widget.audioPlayer.seek(_sectionStart);
      setState(() {
        _isPlaying = false;
        _position = _sectionStart;
      });
      
      if (autoResume) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) widget.audioPlayer.resume();
        });
      }
    } else {
      viewModel.incrementLoop();
      if (autoResume) {
        widget.audioPlayer.seek(Duration.zero);
        widget.audioPlayer.resume();
      } else {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    }
  }

  Future<void> _togglePlayPause() async {
    final viewModel = Provider.of<HymnDetailViewModel>(context, listen: false);
    try {
      if (_isPlaying) {
        await widget.audioPlayer.pause();
      } else {
        if (viewModel.loopCount >= viewModel.maxLoops) {
          viewModel.resetLoops();
          setState(() {
             _sessionPlayIncrements = 0;
          });
        }
        
        // In section mode, ensure we're at the section start before playing
        if (_isSectionMode && _position < _sectionStart) {
          await widget.audioPlayer.seek(_sectionStart);
        }
        
        // Use resume if already set, or play if not
        if (widget.audioPlayer.source == null) {
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
        } else {
          await widget.audioPlayer.resume();
        }
        
        widget.audioPlayer.setPlaybackRate(viewModel.playbackRate);
        _lastPositionUpdate = DateTime.now(); // Reset for anti-cheat
        // widget.onPlay?.call(); // Removed: call in _handleFinish instead for anti-cheat
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
    final viewModel = Provider.of<HymnDetailViewModel>(context);
    final remainingLoops = viewModel.maxLoops - viewModel.loopCount;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
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
            const SizedBox(height: 16),

            // Controls Row: Download, Speed, Play/Pause
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

                IconButton(
                  onPressed: _togglePlayPause,
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, size: 28),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  tooltip: _isPlaying ? 'Pause' : 'Play',
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
            
            const SizedBox(height: 16),

            // Loop Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Plays: ${widget.initialPlays + _sessionPlayIncrements} | Practices: ${widget.initialPractices}',
                      style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Auto-stops after $remainingLoops more play${remainingLoops == 1 ? '' : 's'}.',
                      style: AppTextStyles.caption.copyWith(fontSize: 10),
                    ),
                  ],
                ),
                if (viewModel.loopCount > 0)
                  TextButton(
                    onPressed: () {
                      viewModel.resetLoops();
                      setState(() {
                        _sessionPlayIncrements = 0;
                      });
                    },
                    child: const Text('Reset'),
                  ),
              ],
            ),
          ],
        ],
      ),
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

