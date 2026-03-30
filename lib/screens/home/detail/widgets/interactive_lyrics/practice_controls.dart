// lib/screens/home/detail/widgets/interactive_lyrics/practice_controls.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile/providers/practice_provider.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/models/attempt_model.dart';

class PracticeControls extends StatefulWidget {
  final String playableType;
  final int playableId;
  final String segmentText;
  final Function(double)? onRecordingComplete;

  const PracticeControls({
    super.key,
    required this.playableType,
    required this.playableId,
    required this.segmentText,
    this.onRecordingComplete,
  });

  @override
  State<PracticeControls> createState() => _PracticeControlsState();
}

class _PracticeControlsState extends State<PracticeControls> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordedFilePath;
  Duration _recordingDuration = Duration.zero;
  bool _isUploading = false;
  final bool _isPolling = false;

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<bool> _checkMicrophonePermission() async {
    if (kIsWeb) {
      return await _audioRecorder.hasPermission();
    }
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;
    
    final result = await Permission.microphone.request();
    return result.isGranted;
  }

  Future<void> _startRecording() async {
    final hasPermission = await _checkMicrophonePermission();
    if (!hasPermission) {
      _showError('Microphone permission is required');
      return;
    }

    try {
      String? filePath;
      if (!kIsWeb) {
        final tempDir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        filePath = '${tempDir.path}/practice_${widget.playableId}_$timestamp.wav';
      }

      await _audioRecorder.start(
        RecordConfig(
          encoder: kIsWeb ? AudioEncoder.opus : AudioEncoder.pcm16bits,
          sampleRate: 44100,
          bitRate: 128000,
          numChannels: 1, // Mono is better for analysis
        ),
        path: filePath ?? '',
      );

      setState(() {
        _isRecording = true;
        _recordedFilePath = null;
        _recordingDuration = Duration.zero;
      });

      // Update duration every second
      _updateRecordingDuration();
    } catch (e) {
      _showError('Failed to start recording: $e');
    }
  }

  void _updateRecordingDuration() {
    if (!_isRecording) return;

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || !_isRecording) return;

      setState(() {
        _recordingDuration += const Duration(seconds: 1);
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
      });

      if (path != null) {
        _submitForComparison();
      }
    } catch (e) {
      _showError('Error stopping recording: $e');
      setState(() => _isRecording = false);
    }
  }

  Future<void> _submitForComparison() async {
    if (_recordedFilePath == null) return;

    final provider = Provider.of<PracticeProvider>(context, listen: false);
    
    setState(() => _isUploading = true);
    
    try {
      final attempt = await provider.submitAndPollComparison(
        audioFilePath: _recordedFilePath!,
        playableType: widget.playableType,
        playableId: widget.playableId,
      );
      
      setState(() => _isUploading = false);
      
      if (attempt != null) {
        _showResult(attempt);
      } else {
        _showError('Failed to get comparison results');
      }
    } catch (e) {
      setState(() => _isUploading = false);
      String errorMessage = 'Comparison failed: $e';
      if (e.toString().contains('Reference audio is missing')) {
        errorMessage = 'This section cannot be practiced yet because the reference audio is missing on the server.';
      }
      _showError(errorMessage);
    }
  }

  void _showResult(Attempt attempt) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Practice Result'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '"${widget.segmentText}"',
              style: const TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Score: ${attempt.score?.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: _getScoreColor((attempt.score ?? 0).toDouble()),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _getScoreMessage((attempt.score ?? 0).toDouble()),
              style: const TextStyle(fontSize: 16),
            ),
            if (attempt.feedback != null && attempt.feedback!.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Feedback:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(attempt.feedback!),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onRecordingComplete?.call((attempt.score ?? 0).toDouble());
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  String _getScoreMessage(double score) {
    if (score >= 90) return 'Excellent! Perfect match!';
    if (score >= 80) return 'Great job! Very close match.';
    if (score >= 70) return 'Good effort. Keep practicing.';
    if (score >= 60) return 'Getting there. Try again.';
    return 'Needs more practice. Listen carefully and try again.';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Practice this line:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          
          if (_isUploading || _isPolling)
            _buildProcessingIndicator()
          else if (_recordedFilePath != null)
            _buildResultReady()
          else
            _buildRecordingControls(),
        ],
      ),
    );
  }

  Widget _buildProcessingIndicator() {
    return Column(
      children: [
        const LinearProgressIndicator(),
        const SizedBox(height: 16),
        Text(
          _isUploading ? 'Uploading recording...' : 'Analyzing performance...',
          style: const TextStyle(color: Colors.blue),
        ),
      ],
    );
  }

  Widget _buildResultReady() {
    return Column(
      children: [
        const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Recording ready for analysis'),
          ],
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _submitForComparison,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
          ),
          child: const Text('Analyze Recording'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () {
            setState(() {
              _recordedFilePath = null;
            });
          },
          child: const Text('Re-record'),
        ),
      ],
    );
  }

  Widget _buildRecordingControls() {
    return Column(
      children: [
        if (_isRecording)
          Column(
            children: [
              const Icon(Icons.mic, size: 48, color: Colors.red),
              const SizedBox(height: 8),
              Text(
                _formatDuration(_recordingDuration),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        
        ElevatedButton.icon(
          onPressed: _isRecording ? _stopRecording : _startRecording,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isRecording ? Colors.red : Colors.blue,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
          ),
          icon: Icon(_isRecording ? Icons.stop : Icons.mic),
          label: Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
        ),
        
        if (!_isRecording) ...[
          const SizedBox(height: 12),
          const Text(
            'Tip: Record in a quiet environment for best results',
            style: TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}