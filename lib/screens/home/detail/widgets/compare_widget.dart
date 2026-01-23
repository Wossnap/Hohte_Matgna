
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/providers/practice_provider.dart';
import 'package:mobile/models/attempt_model.dart';

class CompareWidget extends StatefulWidget {
  final int hymnId;
  final String playableType;

  const CompareWidget({
    super.key,
    required this.hymnId,
    required this.playableType,
  });

  @override
  State<CompareWidget> createState() => _CompareWidgetState();
}

class _CompareWidgetState extends State<CompareWidget> {
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
    if (kIsWeb) return true; // Browser handles this on start()
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<void> _handleRecordPress() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final hasPermission = await _requestMicrophonePermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required to record audio'),
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
        filePath = '${tempDir.path}/recording_$timestamp.wav';
      }

      await _audioRecorder.start(
        RecordConfig(
          encoder: kIsWeb ? AudioEncoder.opus : AudioEncoder.pcm16bits,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: filePath ?? '',
      );

      setState(() {
        _isRecording = true;
        _recordingStartTime = DateTime.now();
        _recordedFilePath = null;
      });

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
        _submitForComparison(); // Auto submit
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      setState(() => _isRecording = false);
    }
  }

  Future<void> _submitForComparison() async {
    if (_recordedFilePath == null) return;
    final provider = Provider.of<PracticeProvider>(context, listen: false);

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Analyzing performance...'),
            ],
          ),
        ),
      );
    }

    final attempt = await provider.submitAndPollComparison(
      audioFilePath: _recordedFilePath!,
      playableType: widget.playableType,
      playableId: widget.hymnId,
    );

    if (mounted) Navigator.of(context).pop();

    if (mounted && attempt != null) {
      _showResultDialog(attempt);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.comparisonError ?? 'Analysis failed'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
  
  void _showResultDialog(Attempt attempt) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.analytics, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Comparison Result'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (attempt.score != null) ...[
              Center(
                child: Text(
                  '${attempt.score!.toStringAsFixed(1)}%',
                  style: AppTextStyles.headerLarge.copyWith(
                    color: _getScoreColor(attempt.score!),
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(child: Text(_getScoreLabel(attempt.score!), style: AppTextStyles.bodyMedium)),
            ],
            if (attempt.feedback != null) ...[
              const SizedBox(height: 16),
              Text('Feedback:', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
              Text(attempt.feedback!, style: AppTextStyles.bodyMedium),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
        ],
      ),
    );
  }

  Color _getScoreColor(double score) => score >= 80 ? AppColors.success : (score >= 60 ? AppColors.warning : AppColors.error);
  String _getScoreLabel(double score) => score >= 80 ? 'Great Job!' : (score >= 60 ? 'Keep Practicing' : 'Needs Improvement');

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.greyCard,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Compare with reference',
                style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Text('Default', style: AppTextStyles.caption),
                    Icon(Icons.keyboard_arrow_down, size: 16),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Record & Compare Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _handleRecordPress,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isRecording ? AppColors.warning : AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Text(
                     _isRecording ? 'Stop Recording' : 'Record & Compare',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (_isRecording)
                    Text(
                      '${_recordingDuration.inSeconds}s',
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Live Compare Button
          Row(
            children: [
              Expanded(
                child: SizedBox(
                   height: 48,
                   child: ElevatedButton(
                    onPressed: null, // Disabled as per design
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFBC6C6C), // Faded Red from image
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Start Live Compare',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Record first to enable live compare',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
