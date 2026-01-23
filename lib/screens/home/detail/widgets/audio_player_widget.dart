import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  final AudioPlayer audioPlayer;
  final VoidCallback? onPlay;

  const AudioPlayerWidget({
    super.key,
    required this.audioUrl,
    required this.audioPlayer,
    this.onPlay,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  bool _hasPlayedOnce = false;

  @override
  void initState() {
    super.initState();
    _setupAudioPlayer();
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
        });
      }
    });

    widget.audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });

    widget.audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  Future<void> _playPause() async {
    try {
      debugPrint('Attempting to play audio from URL (Widget): ${widget.audioUrl}');
      if (_isPlaying) {
        await widget.audioPlayer.pause();
      } else {
        await widget.audioPlayer.play(UrlSource(widget.audioUrl));
        
        // Call onPlay callback only on first play
        if (!_hasPlayedOnce) {
          _hasPlayedOnce = true;
          widget.onPlay?.call();
        }
      }
    } catch (e) {
      debugPrint('Audio playback error: $e');
      if (mounted) {
        String message = 'Audio playback error: $e';
        if (e.toString().contains('MEDIA_ELEMENT_ERROR') || e.toString().contains('Code: 4')) {
          message = 'Audio format not supported or CORS error (Web). Check console for URL and verify direct access.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 7),
          ),
        );
      }
    }
  }

  Future<void> _seek(Duration position) async {
    await widget.audioPlayer.seek(position);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Play/Pause Button
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                    size: 56,
                  ),
                  color: AppColors.primary,
                  onPressed: _playPause,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Progress Slider
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.primary,
                inactiveTrackColor: AppColors.border,
                thumbColor: AppColors.primary,
                overlayColor: AppColors.primary.withAlpha((0.2 * 255).round()),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: _position.inSeconds.toDouble(),
                max: _duration.inSeconds.toDouble() > 0
                    ? _duration.inSeconds.toDouble()
                    : 1.0,
                onChanged: (value) {
                  _seek(Duration(seconds: value.toInt()));
                },
              ),
            ),

            // Time Display
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(_position),
                    style: AppTextStyles.caption,
                  ),
                  Text(
                    _formatDuration(_duration),
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
