import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/screens/home/detail/view_models/hymn_detail_viewmodel.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:url_launcher/url_launcher.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  final AudioPlayer audioPlayer;
  final VoidCallback? onPlay;
  final int? playableId;
  final String? playableType;
  final int initialPlays;

  const AudioPlayerWidget({
    super.key,
    required this.audioUrl,
    required this.audioPlayer,
    this.onPlay,
    this.playableId,
    this.playableType,
    this.initialPlays = 0,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  bool _isLoading = true;
  final List<double> _playbackRates = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
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
        final viewModel = Provider.of<HymnDetailViewModel>(context, listen: false);
        viewModel.incrementLoop();
        
        if (viewModel.loopCount < viewModel.maxLoops) {
          widget.audioPlayer.seek(Duration.zero);
          widget.audioPlayer.resume();
        } else {
          setState(() {
            _isPlaying = false;
            _position = Duration.zero;
          });
        }
      }
    });
  }

  Future<void> _togglePlayPause() async {
    final viewModel = Provider.of<HymnDetailViewModel>(context, listen: false);
    try {
      if (_isPlaying) {
        await widget.audioPlayer.pause();
      } else {
        if (viewModel.loopCount >= viewModel.maxLoops) {
          viewModel.resetLoops();
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
        widget.onPlay?.call();
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
    await widget.audioPlayer.seek(position);
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
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isLoading)
            const Column(
              children: [
                Center(child: CircularProgressIndicator()),
                SizedBox(height: 8),
                Text('Pre-buffering audio...', style: TextStyle(fontSize: 10, color: AppColors.primary)),
              ],
            )
          else ...[
            // Progress Bar
            Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: AppColors.primary.withValues(alpha: 0.1),
                    thumbColor: AppColors.primary,
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  ),
                  child: Slider(
                    value: _position.inSeconds.toDouble().clamp(0, _duration.inSeconds.toDouble()),
                    max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0,
                    onChanged: (value) => _seek(Duration(seconds: value.toInt())),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDuration(_position), style: AppTextStyles.caption),
                      Text(_formatDuration(_duration), style: AppTextStyles.caption),
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
                      icon: const Icon(Icons.download_rounded, color: AppColors.primary),
                      onPressed: _downloadAudio,
                      tooltip: 'Download Audio',
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.only(right: 12),
                    ),
                    _buildSpeedSelector(viewModel),
                  ],
                ),

                ElevatedButton.icon(
                  onPressed: _togglePlayPause,
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  label: Text(_isPlaying ? 'Pause' : 'Play'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
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
                      'Plays: ${widget.initialPlays + viewModel.loopCount}',
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
                    onPressed: viewModel.resetLoops,
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
            color: Colors.white,
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
