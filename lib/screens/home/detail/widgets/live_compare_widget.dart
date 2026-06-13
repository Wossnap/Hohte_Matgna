import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/core/api/api_client.dart';

class LiveCompareWidget extends StatefulWidget {
  final String referenceUrl;
  final String recordedFilePath;
  final List<double> breakpoints;
  final Function(bool isActive) onActiveChange;

  const LiveCompareWidget({
    super.key,
    required this.referenceUrl,
    required this.recordedFilePath,
    required this.breakpoints,
    required this.onActiveChange,
  });

  @override
  State<LiveCompareWidget> createState() => _LiveCompareWidgetState();
}

class _LiveCompareWidgetState extends State<LiveCompareWidget> {
  final AudioPlayer _refPlayer = AudioPlayer();
  final AudioPlayer _recPlayer = AudioPlayer();
  
  bool _isActive = false;
  int _currentSegmentIndex = 0;
  String _phase = 'reference'; // 'reference' or 'recorded'
  Duration _endTime = Duration.zero;
  
  List<({Duration start, Duration end})> _ranges = [];

  @override
  void initState() {
    super.initState();
    _setupPlayers();
  }

  void _setupPlayers() {
    _refPlayer.onPositionChanged.listen((pos) {
      if (_isActive && _phase == 'reference') {
        if (pos >= _endTime - const Duration(milliseconds: 100)) {
          _refPlayer.pause();
          _startRecordedSegment(_currentSegmentIndex);
        }
      }
    });

    _recPlayer.onPositionChanged.listen((pos) {
      if (_isActive && _phase == 'recorded') {
        if (pos >= _endTime - const Duration(milliseconds: 100)) {
          _recPlayer.pause();
          if (_currentSegmentIndex < _ranges.length - 1) {
            _startReferenceSegment(_currentSegmentIndex + 1);
          } else {
            _stop();
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _refPlayer.dispose();
    _recPlayer.dispose();
    super.dispose();
  }

  void _computeRanges() async {
    final refDuration = await _refPlayer.getDuration() ?? Duration.zero;
    final sortedBreakpoints = [...widget.breakpoints]..sort();
    final boundaries = [0.0, ...sortedBreakpoints];
    
    _ranges = [];
    for (int i = 0; i < boundaries.length; i++) {
       final start = Duration(milliseconds: (boundaries[i] * 1000).toInt());
       final end = i < boundaries.length - 1 
          ? Duration(milliseconds: (boundaries[i+1] * 1000).toInt())
          : refDuration;
       if (end > start) {
         _ranges.add((start: start, end: end));
       }
    }
  }

  Future<void> _start() async {
    setState(() => _isActive = true);
    widget.onActiveChange(true);
    
    if (kIsWeb) {
      try {
        final response = await ApiClient.fetchAudioBytes(widget.referenceUrl);
        await _refPlayer.setSource(BytesSource(response.bodyBytes));
      } catch (e) {
        debugPrint('LiveCompare fallback to UrlSource: $e');
        await _refPlayer.setSource(UrlSource(widget.referenceUrl));
      }
      // On Web, recordedFilePath is a blob URL from the Record package
      await _recPlayer.setSource(UrlSource(widget.recordedFilePath));
    } else {
      await _refPlayer.setSource(UrlSource(widget.referenceUrl));
      await _recPlayer.setSource(DeviceFileSource(widget.recordedFilePath));
    }
    
    _computeRanges();
    if (_ranges.isEmpty) {
      _stop();
      return;
    }

    _startReferenceSegment(0);
  }

  void _stop() {
    _refPlayer.pause();
    _recPlayer.pause();
    setState(() {
      _isActive = false;
      _currentSegmentIndex = 0;
    });
    widget.onActiveChange(false);
  }

  void _startReferenceSegment(int index) {
    if (!mounted) return;
    final range = _ranges[index];
    setState(() {
      _currentSegmentIndex = index;
      _phase = 'reference';
      _endTime = range.end;
    });
    _refPlayer.seek(range.start);
    _refPlayer.resume();
  }

  void _startRecordedSegment(int index) {
    if (!mounted) return;
    final range = _ranges[index];
    setState(() {
      _phase = 'recorded';
      _endTime = range.end;
    });
    _recPlayer.seek(range.start);
    _recPlayer.resume();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isActive ? _stop : _start,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isActive ? Colors.red : AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(_isActive ? 'Stop Live Compare' : 'Start Live Compare'),
          ),
        ),
        if (_isActive) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.compare_arrows, size: 16, color: AppColors.primaryAccent),
                const SizedBox(width: 8),
                Text(
                  _phase == 'reference' ? 'Reference' : 'Recorded',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _phase == 'reference' ? Colors.blue : Colors.green,
                  ),
                ),
                const Spacer(),
                Text(
                  'Segment ${_currentSegmentIndex + 1}/${_ranges.length}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

