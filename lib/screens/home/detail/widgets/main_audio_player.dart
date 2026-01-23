import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';

class MainAudioPlayer extends StatefulWidget {
  final AudioPlayer audioPlayer;
  final String audioUrl;
  final String title;
  final VoidCallback? onPlay;

  const MainAudioPlayer({
    super.key,
    required this.audioPlayer,
    required this.audioUrl,
    required this.title,
    this.onPlay,
  });

  @override
  State<MainAudioPlayer> createState() => _MainAudioPlayerState();
}

class _MainAudioPlayerState extends State<MainAudioPlayer> {
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _playbackSpeed = 1.0;

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

    widget.audioPlayer.onDurationChanged.listen((d) {
      if (mounted) {
        setState(() => _duration = d);
      }
    });

    widget.audioPlayer.onPositionChanged.listen((p) {
      if (mounted) {
        setState(() => _position = p);
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

  @override
  void dispose() {
    // We don't dispose the shared player here, owner (HymnDetailScreen) will handle it.
    super.dispose();
  }

  Future<void> _togglePlay() async {
    try {
      debugPrint('Attempting to play audio from URL: ${widget.audioUrl}');
      if (_isPlaying) {
        await widget.audioPlayer.pause();
      } else {
        await widget.audioPlayer.play(UrlSource(widget.audioUrl));
        widget.onPlay?.call();
      }
    } catch (e) {
      debugPrint('Audio playback error: $e');
      if (mounted) {
        String message = 'Audio playback error: $e';
        if (e.toString().contains('MEDIA_ELEMENT_ERROR') || e.toString().contains('Code: 4')) {
          message = 'Audio format not supported or CORS error (Web). \n\n'
                    'Troubleshooting:\n'
                    '1. Verify the audio URL directly in a browser.\n'
                    '2. If it works there, it is likely a CORS issue. Run with --web-browser-flag "--disable-web-security" for testing.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'Copy URL',
              textColor: Colors.white,
              onPressed: () {
                // You would typically use Clipboard here if needed
                debugPrint('User manually copying URL: ${widget.audioUrl}');
              },
            ),
          ),
        );
      }
    }
  }

  void _changeSpeed() {
    setState(() {
      if (_playbackSpeed == 1.0) {
        _playbackSpeed = 1.5;
      } else if (_playbackSpeed == 1.5) {
        _playbackSpeed = 2.0;
      } else if (_playbackSpeed == 2.0) {
        _playbackSpeed = 0.5;
      } else {
        _playbackSpeed = 1.0;
      }
      
      widget.audioPlayer.setPlaybackRate(_playbackSpeed);
    });
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.greyCard,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.music_note, color: AppColors.primary, size: 24),
              const SizedBox(width: 12),
              Text(
                widget.title,
                style: AppTextStyles.headerSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Icon(Icons.keyboard_arrow_up, color: AppColors.textSecondary),
            ],
          ),
          
          const SizedBox(height: 24),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _duration.inSeconds > 0 
                  ? _position.inSeconds / _duration.inSeconds 
                  : 0.0,
              backgroundColor: const Color(0xFFFDFBF7), // Pale yellow/beige from image
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary.withValues(alpha: 0.5)),
              minHeight: 8,
            ),
          ),
          
          const SizedBox(height: 8),

          // Timestamps
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(_position),
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                _formatDuration(_duration),
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Controls Row
          Row(
            children: [
              // Speed Control
              InkWell(
                onTap: _changeSpeed,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Speed:',
                        style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_playbackSpeed}x',
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Plays
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Plays: 0', 
                    style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              
              const Spacer(),

              // Play Button
              ElevatedButton.icon(
                onPressed: _togglePlay,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                label: Text(
                  _isPlaying ? 'Pause' : 'Play',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          Text(
            'Auto-stops after 15 more plays (max 15 per session).',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }
}
