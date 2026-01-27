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
import 'package:mobile/core/api/api_client.dart';
import 'package:audioplayers/audioplayers.dart';
import 'live_compare_widget.dart';
import '../../../../../models/attempt_model.dart';

class CompareWidget extends StatefulWidget {
  final int hymnId;
  final String playableType;
  final int? playableId; // Optional section ID
  final String label;

  const CompareWidget({
    super.key,
    required this.hymnId,
    required this.playableType,
    this.playableId,
    this.label = 'Compare with reference',
  });

  @override
  State<CompareWidget> createState() => _CompareWidgetState();
}

class _CompareWidgetState extends State<CompareWidget> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _playbackPlayer = AudioPlayer();
  final AudioPlayer _helperPlayer = AudioPlayer(); 
  
  // State
  bool _isRecording = false;
  bool _isPaused = false;
  bool _isSubmitting = false;
  int _countdown = 0;
  Timer? _countdownTimer;
  Duration _maxDuration = Duration.zero;
  Duration _elapsed = Duration.zero;
  Timer? _elapsedTimer;
  
  String? _recordedFilePath;
  bool _isPlayingPlayback = false;
  
  // Scoring State
  String? _errorMessage;
  String? _successMessage;
  Attempt? _latestAttempt;
  String _algorithm = 'default';
  
  // UI State
  bool _showKeys = false;
  bool _showNotes = false;
  
  List<double> _breakpoints = [];
  bool _isLiveActive = false;

  @override
  void initState() {
    super.initState();
    _playbackPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlayingPlayback = false);
    });
    _loadBreakpoints();
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
    _audioRecorder.dispose();
    _playbackPlayer.dispose();
    _helperPlayer.dispose();
    _countdownTimer?.cancel();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  Future<void> _startFlow() async {
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
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          timer.cancel();
          _countdownTimer = null;
          _beginRecording();
        }
      });
    });
  }

  Future<void> _beginRecording() async {
    final status = await Permission.microphone.request();
    if (!mounted || !status.isGranted) return;

    try {
      final provider = Provider.of<PracticeProvider>(context, listen: false);
      final refUrl = widget.playableType == 'hymn' 
          ? provider.currentHymn?.hymn.audioUrl 
          : provider.currentHymn?.sections.where((s) => s.id == widget.playableId).firstOrNull?.audioUrl;

      if (refUrl == null) {
        setState(() => _errorMessage = 'Reference audio not found');
        return;
      }

      // Load reference to get duration if not already known
      if (kIsWeb) {
        try {
          final response = await ApiClient.fetchAudioBytes(refUrl);
          await _helperPlayer.setSource(BytesSource(response.bodyBytes));
        } catch (e) {
          await _helperPlayer.setSource(UrlSource(refUrl));
        }
      } else {
        await _helperPlayer.setSource(UrlSource(refUrl));
      }
      
      _maxDuration = await _helperPlayer.getDuration() ?? const Duration(seconds: 30);

      String? path;
      if (!kIsWeb) {
        final tempDir = await getTemporaryDirectory();
        path = '${tempDir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
      }
      
      await _audioRecorder.start(
        RecordConfig(
          encoder: kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc,
          numChannels: 1,
          sampleRate: 48000,
          bitRate: 128000,
        ),
        path: path ?? '',
      );

      setState(() {
        _isRecording = true;
        _isPaused = false;
        _recordedFilePath = null;
        _elapsed = Duration.zero;
      });

      _startTimer();
    } catch (e) {
      setState(() => _errorMessage = 'Failed to start recording: $e');
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
          if (_elapsed >= _maxDuration) {
            _stopRecording();
          }
        });
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
    final path = await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _isPaused = false;
      _recordedFilePath = path;
    });
    if (path != null) {
      if (mounted) {
        _submit(path);
      }
    }
  }

  Future<void> _submit(String path) async {
    if (!mounted) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final provider = Provider.of<PracticeProvider>(context, listen: false);
    try {
      final attempt = await provider.submitAndPollComparison(
        audioFilePath: path,
        playableType: widget.playableType,
        playableId: widget.playableId ?? widget.hymnId,
        algorithm: _algorithm,
      );

      if (!mounted) return;
      setState(() {
        _latestAttempt = attempt;
        _successMessage = attempt != null ? 'Similarity Score: ${attempt.score?.toStringAsFixed(1)}%' : null;
        _isSubmitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Comparison failed: $e';
        _isSubmitting = false;
      });
    }
  }

  List<String> _extractKeys(dynamic source) {
    if (source == null) return [];
    if (source is Map) {
      final candidates = [
        source['keys'],
        source['reference_keys'],
        source['recorded_keys'],
      ];
      for (var c in candidates) {
        if (c is List) return c.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      }
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PracticeProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final refUrl = widget.playableType == 'hymn' 
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
          // Header & Algorithm Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _algorithm,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    items: const [
                      DropdownMenuItem(value: 'default', child: Text('Default')),
                      DropdownMenuItem(value: 'harmonic', child: Text('Harmonic')),
                    ],
                    onChanged: _isRecording || _isSubmitting ? null : (val) => setState(() => _algorithm = val!),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Action Buttons
          if (!_isRecording && _countdown == 0 && !_isSubmitting)
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
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_countdown',
                    style: AppTextStyles.headerLarge.copyWith(color: AppColors.primary, fontSize: 48),
                  ),
                ],
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
                      '${(_elapsed.inMilliseconds / 1000).toStringAsFixed(1)}s / ${(_maxDuration.inMilliseconds / 1000).toStringAsFixed(1)}s',
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
              decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12))),
                ],
              ),
            ),

          if (_successMessage != null)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: AppColors.success, size: 16),
                  const SizedBox(width: 8),
                  Text(_successMessage!, style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

          // Analysis Display (matching Vue logic)
          if (_latestAttempt != null && _latestAttempt!.analysis != null) ...[
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            
            _buildInfoRow('Reference Duration', _latestAttempt!.analysis!['reference_audio']?['duration_formatted'] ?? 'N/A'),
            _buildInfoRow('Recorded Duration', _latestAttempt!.analysis!['recorded_audio']?['duration_formatted'] ?? 'N/A'),

            // Keys Toggle
            _buildAnalysisToggle(
              title: _showKeys ? 'Hide keys' : 'Show keys',
              isActive: _showKeys,
              onTap: () => setState(() => _showKeys = !_showKeys),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSubInfo('Reference keys', _extractKeys(_latestAttempt!.analysis!['reference_audio'] ?? _latestAttempt!.analysis).join(', ')),
                  _buildSubInfo('Recorded keys', _extractKeys(_latestAttempt!.analysis!['recorded_audio'] ?? _latestAttempt!.analysis).join(', ')),
                ],
              ),
            ),

            // Notes Toggle
            _buildAnalysisToggle(
              title: _showNotes ? 'Hide note sequences' : 'Show note sequences',
              isActive: _showNotes,
              onTap: () => setState(() => _showNotes = !_showNotes),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSubInfo('Reference notes', (_latestAttempt!.analysis!['note_sequences']?['reference'] as List?)?.join(', ') ?? 'None'),
                  _buildSubInfo('Recorded notes', (_latestAttempt!.analysis!['note_sequences']?['recorded'] as List?)?.join(', ') ?? 'None'),
                ],
              ),
            ),
          ],

          // Playback & Live Compare
          if (_recordedFilePath != null && !_isLiveActive && !_isRecording) ...[
            const SizedBox(height: 24),
            Text('Playback Recording', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton.filled(
                  onPressed: () async {
                    if (_isPlayingPlayback) {
                      await _playbackPlayer.stop();
                      setState(() => _isPlayingPlayback = false);
                    } else {
                      if (kIsWeb) {
                        await _playbackPlayer.play(UrlSource(_recordedFilePath!));
                      } else {
                        await _playbackPlayer.play(DeviceFileSource(_recordedFilePath!));
                      }
                      setState(() => _isPlayingPlayback = true);
                    }
                  },
                  icon: Icon(_isPlayingPlayback ? Icons.stop : Icons.play_arrow),
                ),
                const SizedBox(width: 12),
                const Expanded(child: LinearProgressIndicator(value: 0)),
              ],
            ),
          ],

          if (_recordedFilePath != null && refUrl != null && _breakpoints.isNotEmpty && !_isRecording) ...[
            const SizedBox(height: 20),
            LiveCompareWidget(
              referenceUrl: refUrl,
              recordedFilePath: _recordedFilePath!,
              breakpoints: _breakpoints,
              onActiveChange: (active) => setState(() => _isLiveActive = active),
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
          child: Text(title, style: TextStyle(fontSize: 12, color: AppColors.primary, decoration: TextDecoration.underline)),
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
}

