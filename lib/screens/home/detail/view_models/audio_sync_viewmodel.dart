// lib/screens/home/detail/view_models/audio_sync_viewmodel.dart
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:mobile/models/lyric_segment_model.dart';

class AudioSyncViewModel extends ChangeNotifier {
  final AudioPlayer _audioPlayer;
  
  // Audio state
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _playbackRate = 1.0;
  
  // Lyrics sync state
  int? _currentSegmentIndex;
  final Map<int, bool> _segmentCompleted = {};
  final List<LyricSegment> _segments = [];
  
  AudioSyncViewModel(this._audioPlayer) {
    _setupAudioListeners();
  }
  
  // Getters
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  double get playbackRate => _playbackRate;
  int? get currentSegmentIndex => _currentSegmentIndex;
  Map<int, bool> get segmentCompleted => Map.from(_segmentCompleted);
  List<LyricSegment> get segments => List.from(_segments);
  
  // Initialize with segments from API
  void initializeSegments(List<LyricSegment> segments) {
    _segments.clear();
    _segments.addAll(segments);
    _segmentCompleted.clear();
    
    for (int i = 0; i < _segments.length; i++) {
      _segmentCompleted[i] = false;
    }
    
    notifyListeners();
  }
  
  void _setupAudioListeners() {
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      _isPlaying = state == PlayerState.playing;
      notifyListeners();
    });
    
    _audioPlayer.onDurationChanged.listen((Duration d) {
      _duration = d;
      notifyListeners();
    });
    
    _audioPlayer.onPositionChanged.listen((Duration p) {
      _position = p;
      _syncLyricsWithAudio(p);
      notifyListeners();
    });
    
    _audioPlayer.onPlayerComplete.listen((_) {
      _isPlaying = false;
      _position = Duration.zero;
      _currentSegmentIndex = null;
      notifyListeners();
    });
  }
  
  void _syncLyricsWithAudio(Duration position) {
    if (_segments.isEmpty) return;
    
    final currentMs = position.inMilliseconds;
    
    // Find which segment we're in
    int? newSegmentIndex;
    for (int i = 0; i < _segments.length; i++) {
      final segment = _segments[i];
      if (currentMs >= segment.startMs && currentMs < segment.endMs) {
        newSegmentIndex = i;
        break;
      }
    }
    
    if (newSegmentIndex != _currentSegmentIndex) {
      // Mark previous segment as completed when moving to new one
      if (_currentSegmentIndex != null) {
        _segmentCompleted[_currentSegmentIndex!] = true;
      }
      
      _currentSegmentIndex = newSegmentIndex;
    }
  }
  
  // Audio control methods
  Future<void> playPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.resume();
    }
  }
  
  Future<void> playFromUrl(String url) async {
    await _audioPlayer.play(UrlSource(url));
  }
  
  Future<void> stop() async {
    await _audioPlayer.stop();
    _isPlaying = false;
    _position = Duration.zero;
    _currentSegmentIndex = null;
    notifyListeners();
  }
  
  Future<void> seekToSegment(int segmentIndex) async {
    if (segmentIndex >= 0 && segmentIndex < _segments.length) {
      final segment = _segments[segmentIndex];
      await _audioPlayer.seek(Duration(milliseconds: segment.startMs));
      
      if (!_isPlaying) {
        await _audioPlayer.resume();
      }
      
      _currentSegmentIndex = segmentIndex;
      notifyListeners();
    }
  }
  
  Future<void> seekToSectionSegment(int sectionIndex, int segmentIndex, List<LyricSegment> sectionSegments) async {
    if (segmentIndex >= 0 && segmentIndex < sectionSegments.length) {
      final segment = sectionSegments[segmentIndex];
      await _audioPlayer.seek(Duration(milliseconds: segment.startMs));
      
      if (!_isPlaying) {
        await _audioPlayer.resume();
      }
      
      // For section-based segments, we need to map to global index
      // This is handled in the parent viewmodel
      notifyListeners();
    }
  }
  
  Future<void> setPlaybackRate(double rate) async {
    _playbackRate = rate;
    await _audioPlayer.setPlaybackRate(rate);
    notifyListeners();
  }
  
  // Practice tracking
  void markSegmentCompleted(int segmentIndex) {
    if (segmentIndex >= 0 && segmentIndex < _segmentCompleted.length) {
      _segmentCompleted[segmentIndex] = true;
      notifyListeners();
    }
  }
  
  void markSegmentAsCurrent(int segmentIndex) {
    if (segmentIndex >= 0 && segmentIndex < _segments.length) {
      _currentSegmentIndex = segmentIndex;
      notifyListeners();
    }
  }
  
  double getPracticeProgress() {
    if (_segmentCompleted.isEmpty) return 0.0;
    final completedCount = _segmentCompleted.values.where((v) => v == true).length;
    return completedCount / _segmentCompleted.length;
  }
  
  int getCompletedSegmentsCount() {
    return _segmentCompleted.values.where((v) => v == true).length;
  }
  
}