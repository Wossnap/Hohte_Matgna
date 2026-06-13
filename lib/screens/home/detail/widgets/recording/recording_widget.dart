import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../providers/practice_provider.dart';
import '../../../../../models/attempt_model.dart';
import 'recording_status_widget.dart';
import 'recording_file_info_widget.dart';
import 'recording_result_dialog.dart';

class RecordingWidget extends StatefulWidget {
  final int hymnId;
  final String playableType;

  const RecordingWidget({
    super.key,
    required this.hymnId,
    required this.playableType,
  });

  @override
  State<RecordingWidget> createState() => _RecordingWidgetState();
}

class _RecordingWidgetState extends State<RecordingWidget> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordedFilePath;
  Duration _recordingDuration = Duration.zero;
  DateTime? _recordingStartTime;

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<bool> _requestMicrophonePermission() async {
    if (kIsWeb) {
      return await _audioRecorder.hasPermission();
    }
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<void> _startRecording() async {
    final hasPermission = await _requestMicrophonePermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Microphone permission is required to record audio'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    try {
      String? filePath;
      if (!kIsWeb) {
        final tempDir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        // Use WebM/Opus on mobile to match website behavior
        filePath = '${tempDir.path}/recording_$timestamp.webm';
      }

      await _audioRecorder.start(
        RecordConfig(
          // Use Opus encoder on both web and mobile so uploaded file is webm/opus
          encoder: AudioEncoder.opus,
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: filePath ?? '',
      );

      setState(() {
        _isRecording = true;
        _recordingStartTime = DateTime.now();
        _recordedFilePath = null;
      });

      // Update duration every second
      _updateRecordingDuration();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not start recording: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _updateRecordingDuration() {
    if (!_isRecording) return;

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || !_isRecording) return;

      setState(() {
        _recordingDuration = DateTime.now().difference(_recordingStartTime!);
      });

      _updateRecordingDuration();
    });
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();

      setState(() {
        _isRecording = false;
        _recordedFilePath = path;
        _recordingDuration = Duration.zero;
      });

      if (path != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Recording saved! Comparing...'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        // Automatically submit for comparison after recording stops
        await _submitForComparison();
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      setState(() {
        _isRecording = false;
      });
    }
  }

  Future<void> _submitForComparison() async {
    if (_recordedFilePath == null) return;

    final provider = Provider.of<PracticeProvider>(context, listen: false);

    // Submit audio
    final attempt = await provider.submitAndPollComparison(
      audioFilePath: _recordedFilePath!,
      playableType: widget.playableType,
      playableId: widget.hymnId,
    );

    // Show result
    if (mounted && attempt != null) {
      _showResultDialog(attempt);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.comparisonError ?? 'Failed to get comparison results'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showResultDialog(Attempt attempt) {
    showDialog(
      context: context,
      builder: (context) => RecordingResultDialog(
        attempt: attempt,
        onRetry: () {
          Navigator.of(context).pop();
          _startRecording();
        },
        onClose: () => Navigator.of(context).pop(),
      ),
    );
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.mic, color: AppColors.error, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Record Your Performance',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Recording Status
            if (_isRecording) ...[
              RecordingStatusWidget(duration: _recordingDuration),
              const SizedBox(height: 12),
            ],

            // Recorded File Info
            if (_recordedFilePath != null && !_isRecording) ...[
              const RecordingFileInfoWidget(),
              const SizedBox(height: 12),
            ],

            // Action Buttons
            Row(
              children: [
                if (!_isRecording && _recordedFilePath == null)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _startRecording,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                        shadowColor: AppColors.error.withValues(alpha: 0.5),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.mic, size: 28),
                          SizedBox(width: 12),
                          Text(
                            'Record',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (_isRecording)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _stopRecording,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                        shadowColor: AppColors.error.withValues(alpha: 0.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.stop, size: 28),
                          SizedBox(width: 12),
                          Text(
                            _formatDuration(_recordingDuration),
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Stop',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (_recordedFilePath != null && !_isRecording)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _submitForComparison,
                      icon: const Icon(Icons.compare),
                      label: const Text('Compare'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                        shadowColor: AppColors.primary.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Removed unused _buildLabelButton helper
}

