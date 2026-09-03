// lib/screens/home/detail/view_models/hymn_detail_viewmodel.dart
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:mobile/models/hymn_detail_model.dart';
import 'package:mobile/models/section_model.dart';
import 'package:mobile/models/lyric_segment_model.dart';
import 'package:mobile/providers/practice_provider.dart';
import 'package:mobile/screens/home/detail/view_models/audio_sync_viewmodel.dart';
import 'package:mobile/core/api/api_client.dart';

class HymnDetailViewModel extends ChangeNotifier {
  final PracticeProvider _practiceProvider;
  final AudioPlayer _mainAudioPlayer;
  
  late AudioSyncViewModel _audioSyncViewModel;
  
  // Screen state
  HymnDetail? _currentHymn;
  bool _isLoading = false;
  String? _error;
  
  // Practice mode state
  int _selectedSectionIndex = 0;
  int _selectedSegmentIndex = 0;
  bool _isPracticeMode = false;

  // Playback & Loop State
  double _playbackRate = 1.0;
  int _loopCount = 0;
  int _maxLoops = 15;
  bool _isLiveCompareActive = false;

  // Lyrics Game State
  bool _showLyricsGame = false;
  int _gameScore = 0;
  int _gameCorrect = 0;
  int _gameTotal = 0;
  int _currentGameQuestionIndex = 0;
  
  // Recording → karaoke sync. The hymn-level CompareWidget drives these while
  // recording so the karaoke can follow the recording's elapsed time (the audio
  // isn't playing during recording), matching the web's KaraokeLyrics props.
  // ValueNotifiers (not notifyListeners) so per-100ms updates don't rebuild the
  // whole screen — only the karaoke listens.
  final ValueNotifier<bool> isRecording = ValueNotifier(false);
  final ValueNotifier<int> recordingElapsedMs = ValueNotifier(0);

  // Alternating-playback (live compare) state. When active, the screen collapses
  // to a focused view (only the karaoke + the alternating-playback control), and
  // the karaoke follows the reference audio's position via alternateElapsedMs.
  // The active flag goes through notifyListeners() so the screen re-lays-out;
  // the per-tick elapsed stays a pure ValueNotifier so only the karaoke rebuilds.
  final ValueNotifier<bool> isAlternatePlaybackActive = ValueNotifier(false);
  final ValueNotifier<int> alternateElapsedMs = ValueNotifier(0);

  void setAlternatePlaybackActive(bool active) {
    isAlternatePlaybackActive.value = active;
    notifyListeners();
  }

  // Segment mapping (section index → segment index → global index)
  final Map<int, Map<int, int>> _segmentMapping = {};
  final Map<int, List<LyricSegment>> _sectionSegmentsCache = {};
  
  // Getters
  HymnDetail? get currentHymn => _currentHymn;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get selectedSectionIndex => _selectedSectionIndex;
  int get selectedSegmentIndex => _selectedSegmentIndex;
  bool get isPracticeMode => _isPracticeMode;
  AudioSyncViewModel get audioSyncViewModel => _audioSyncViewModel;

  // Playback & Loop Getters
  double get playbackRate => _playbackRate;
  int get loopCount => _loopCount;
  int get maxLoops => _maxLoops;
  bool get isLiveCompareActive => _isLiveCompareActive;

  // Game Getters
  bool get showLyricsGame => _showLyricsGame;
  int get gameScore => _gameScore;
  int get gameCorrect => _gameCorrect;
  int get gameTotal => _gameTotal;
  int get currentGameQuestionIndex => _currentGameQuestionIndex;
  int get gameAccuracy => _gameTotal > 0 ? ((_gameCorrect / _gameTotal) * 100).round() : 0;
  
  // Current selected section for practice
  Section? get selectedSection {
    if (_currentHymn == null || _selectedSectionIndex >= _currentHymn!.sections.length) {
      return null;
    }
    return _currentHymn!.sections[_selectedSectionIndex];
  }
  
  // Get all segments for a specific section
  List<LyricSegment> getSegmentsForSection(int sectionIndex) {
    if (_sectionSegmentsCache.containsKey(sectionIndex)) {
      return _sectionSegmentsCache[sectionIndex]!;
    }
    
    if (_currentHymn == null || sectionIndex >= _currentHymn!.sections.length) {
      return [];
    }
    
    final section = _currentHymn!.sections[sectionIndex];
    final segments = _extractSegmentsFromSection(section);
    _sectionSegmentsCache[sectionIndex] = segments;
    
    return segments;
  }
  
  // Get current section segments
  List<LyricSegment> get currentSectionSegments {
    return getSegmentsForSection(_selectedSectionIndex);
  }
  
  // Convert section+segment index to global index
  int? getGlobalIndex(int sectionIndex, int segmentIndex) {
    return _segmentMapping[sectionIndex]?[segmentIndex];
  }
  
  // Get all segments across all sections (flattened for practice)
  List<({int sectionIndex, int segmentIndex, String text, LyricSegment segment})> get allSegments {
    final result = <({int sectionIndex, int segmentIndex, String text, LyricSegment segment})>[];
    
    if (_currentHymn == null) return result;
    
    for (int sectionIdx = 0; sectionIdx < _currentHymn!.sections.length; sectionIdx++) {
      final segments = getSegmentsForSection(sectionIdx);
      for (int segmentIdx = 0; segmentIdx < segments.length; segmentIdx++) {
        final segment = segments[segmentIdx];
        result.add((
          sectionIndex: sectionIdx,
          segmentIndex: segmentIdx,
          text: segment.text,
          segment: segment
        ));
      }
    }
    
    return result;
  }
  
  HymnDetailViewModel(this._practiceProvider, this._mainAudioPlayer) {
    _audioSyncViewModel = AudioSyncViewModel(_mainAudioPlayer);
  }
  
  // Load hymn data
  Future<void> loadHymnDetail(int hymnId) async {
    _isLoading = true;
    _error = null;
    _segmentMapping.clear();
    _sectionSegmentsCache.clear();
    notifyListeners();
    
    try {
      await _practiceProvider.loadHymnDetail(hymnId);
      _currentHymn = _practiceProvider.currentHymn;
      
      if (_currentHymn != null) {
        // Build segment mapping and cache
        _buildSegmentMapping();
        
        // Initialize audio sync with ALL segments for Listen Mode
        final allSegs = allSegments.map((e) => e.segment).toList();
        if (allSegs.isNotEmpty) {
          _audioSyncViewModel.initializeSegments(allSegs);
        }
        
        // Load breakpoints for the hymn
        await _loadBreakpoints(hymnId);
      }
    } catch (e) {
      _error = 'Failed to load hymn: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Playback Controls
  void setPlaybackRate(double rate) {
    _playbackRate = rate;
    _mainAudioPlayer.setPlaybackRate(rate);
    notifyListeners();
  }

  void incrementLoop() {
    _loopCount++;
    if (_loopCount >= _maxLoops) {
      _mainAudioPlayer.pause();
    }
    notifyListeners();
  }

  void resetLoops() {
    _loopCount = 0;
    notifyListeners();
  }

  void setMaxLoops(int count) {
    _maxLoops = count;
    notifyListeners();
  }

  void setLiveCompareActive(bool active) {
    _isLiveCompareActive = active;
    notifyListeners();
  }

  // Game Methods
  void toggleLyricsGame() {
    setLyricsGame(!_showLyricsGame);
  }

  /// Explicitly select Lyrics (false) or Game (true) — used by the inline
  /// Lyrics | Game segmented toggle. No-op if already in that mode.
  void setLyricsGame(bool showGame) {
    if (_showLyricsGame == showGame) return;
    _showLyricsGame = showGame;
    if (_showLyricsGame) {
      resetGameState();
    }
    notifyListeners();
  }

  void resetGameState() {
    _gameScore = 0;
    _gameCorrect = 0;
    _gameTotal = 0;
    _currentGameQuestionIndex = 0;
    notifyListeners();
  }

  void submitGameAnswer(bool isCorrect) {
    _gameTotal++;
    if (isCorrect) {
      _gameCorrect++;
      _gameScore += 10;
    }
    _currentGameQuestionIndex++;
    notifyListeners();
  }
  
  // Visual State
  final List<({int sectionIndex, int segmentIndex, String text, LyricSegment segment})> _visualSegments = [];
  final Map<int, int> _audioToVisualMap = {}; // GlobalAudioIndex -> VisualListIndex

  List<({int sectionIndex, int segmentIndex, String text, LyricSegment segment})> get visualSegments => _visualSegments;


  
  // Get Visual Index for a given Global Audio Index
  int? getVisualIndexForAudio(int globalAudioIndex) {
    if (globalAudioIndex < 0) return null;
    return _audioToVisualMap[globalAudioIndex];
  }

  void _buildSegmentMapping() {
    if (_currentHymn == null) return;
    
    int globalIndex = 0;
    for (int sectionIdx = 0; sectionIdx < _currentHymn!.sections.length; sectionIdx++) {
      final segments = getSegmentsForSection(sectionIdx);
      final segmentMap = <int, int>{};
      
      for (int segmentIdx = 0; segmentIdx < segments.length; segmentIdx++) {
        segmentMap[segmentIdx] = globalIndex;
        globalIndex++;
      }
      
      _segmentMapping[sectionIdx] = segmentMap;
    }
    
    _buildVisualSegments();
  }
  
  void _buildVisualSegments() {
    _visualSegments.clear();
    _audioToVisualMap.clear();
    
    if (_currentHymn == null) return;
    
    final allAudioSegments = allSegments;
    
    // 1. Determine "Short" vs "Long"
    // Heuristic: If > 1 section AND total segments > 10, treat as Long.
    // Or if explicitly requested "First poem lyrics" -> Section 0.
    final bool isLong = _currentHymn!.sections.length > 1 && allAudioSegments.length > 10;
    
    // 2. Build Visual List
    if (isLong) {
      // Add only first section segments
      // Or "Header + First Poem". We assume Section 0 is the "First Poem" / Main Stanza.
      // We iterate through ALL segments, but only ADD unique text from the start.
      // Actually, user said: "list... header and first poem lyrics, the rest use the first melody".
      // This supports: Show Section 0.
      
      final firstSectionSegments = getSegmentsForSection(0);
      for (int i = 0; i < firstSectionSegments.length; i++) {
        _visualSegments.add((
          sectionIndex: 0,
          segmentIndex: i,
          text: firstSectionSegments[i].text,
          segment: firstSectionSegments[i]
        ));
      }
    } else {
      // Short: List all
      _visualSegments.addAll(allAudioSegments);
    }
    
    // 3. Build Mapping (Audio -> Visual)
    // For every audio segment, find the matching visual segment.
    for (int i = 0; i < allAudioSegments.length; i++) {
      final audioSeg = allAudioSegments[i];
      
      // Strategy: Find visual segment with same text
      // Priority: 
      // 1. Exact visual timestamp match (it's the same segment)
      // 2. Text match (it's a repeat)
      
      int matchIndex = -1;
      
      // Check for identity first
      for (int v = 0; v < _visualSegments.length; v++) {
        if (_visualSegments[v].sectionIndex == audioSeg.sectionIndex && 
            _visualSegments[v].segmentIndex == audioSeg.segmentIndex) {
          matchIndex = v;
          break;
        }
      }
      
      // If not identical (e.g. truncated), look for text match
      if (matchIndex == -1) {
         for (int v = 0; v < _visualSegments.length; v++) {
           // Normalize text for comparison (trim, ignore case/punctuation if needed)
           if (_visualSegments[v].text.trim() == audioSeg.text.trim()) {
             matchIndex = v;
             break; // Map to the FIRST occurrence
           }
         }
      }
      
      if (matchIndex != -1) {
        _audioToVisualMap[i] = matchIndex;
      }
    }
  }
  
  List<LyricSegment> _extractSegmentsFromSection(Section section) {
    final segments = <LyricSegment>[];
    
    // Add segments from this section
    segments.addAll(section.lyricSegments);
    
    // Recursively add segments from children
    for (final child in section.children) {
      segments.addAll(_extractSegmentsFromSection(child));
    }
    
    // Sort by start time
    segments.sort((a, b) => a.startMs.compareTo(b.startMs));
    
    // If segments are word-level (short or many), group them into phrases
    return _groupSegmentsIntoPhrases(segments);
  }

  List<LyricSegment> _groupSegmentsIntoPhrases(List<LyricSegment> segments) {
    if (segments.isEmpty) return [];
    
    // Heuristic: If average duration is < 1s or there are many segments, 
    // we might want to group them. For now, let's group by typical phrase length (4-6 words)
    // or if they are on the same line (if text contains newlines).
    
    final grouped = <LyricSegment>[];
    if (segments.isEmpty) return grouped;

    LyricSegment? currentGroup;
    int wordsInCurrentGroup = 0;

    for (var segment in segments) {
      if (currentGroup == null) {
        currentGroup = segment;
        wordsInCurrentGroup = segment.text.split(' ').length;
      } else {
        // Condition to group: 
        // 1. Gap is small (< 500ms)
        // 2. Current group isn't too long (< 5 words)
        final gap = segment.startMs - currentGroup.endMs;
        
        if (gap < 500 && wordsInCurrentGroup < 5) {
          // Merge into current group
          currentGroup = LyricSegment(
            id: currentGroup.id, // Keep first ID
            hymnId: currentGroup.hymnId,
            sectionId: currentGroup.sectionId,
            startMs: currentGroup.startMs,
            endMs: segment.endMs,
            text: '${currentGroup.text} ${segment.text}'.trim(),
            startSeconds: currentGroup.startSeconds,
            endSeconds: segment.endSeconds,
          );
          wordsInCurrentGroup += segment.text.split(' ').length;
        } else {
          // Finish current group and start new one
          grouped.add(currentGroup);
          currentGroup = segment;
          wordsInCurrentGroup = segment.text.split(' ').length;
        }
      }
    }

    if (currentGroup != null) {
      grouped.add(currentGroup);
    }

    return grouped;
  }
  
  Future<void> _loadBreakpoints(int hymnId) async {
    try {
      final breakpoints = await _practiceProvider.getBreakpoints(
        playableType: 'hymn',
        playableId: hymnId,
      );
      
      if (breakpoints.isNotEmpty) {
        // If segments are empty but we have breakpoints, create segments
        final firstSectionSegments = getSegmentsForSection(0);
        if (firstSectionSegments.isEmpty && _currentHymn != null) {
          // Create segments from breakpoints and lyrics
          final createdSegments = _createSegmentsFromBreakpoints(breakpoints);
          _audioSyncViewModel.initializeSegments(createdSegments);
        }
      }
    } catch (e) {
      // Error handling
    }
  }
  
  List<LyricSegment> _createSegmentsFromBreakpoints(List<double> breakpoints) {
    final segments = <LyricSegment>[];
    
    if (_currentHymn == null) return segments;
    
    // Use hymn content or first section content
    String lyrics = _currentHymn!.hymn.content ?? _currentHymn!.hymn.description ?? '';
    if (lyrics.isEmpty && _currentHymn!.sections.isNotEmpty) {
      lyrics = _currentHymn!.sections[0].content ?? '';
    }
    
    final lines = lyrics.split('\n').where((line) => line.trim().isNotEmpty).toList();
    
    for (int i = 0; i < breakpoints.length; i++) {
      if (i < lines.length) {
        final startMs = (breakpoints[i] * 1000).toInt();
        final endMs = i < breakpoints.length - 1 
            ? (breakpoints[i + 1] * 1000).toInt()
            : startMs + 3000; // Default 3 seconds for last segment
        
        segments.add(LyricSegment(
          id: i,
          hymnId: _currentHymn!.hymn.id,
          sectionId: null,
          startMs: startMs,
          endMs: endMs,
          text: lines[i].trim(),
          startSeconds: breakpoints[i],
          endSeconds: i < breakpoints.length - 1 ? breakpoints[i + 1] : breakpoints[i] + 3.0,
        ));
      }
    }
    
    return segments;
  }
  
  // Practice mode methods
  void enterPracticeMode() {
    _isPracticeMode = true;
    notifyListeners();
  }
  
  void exitPracticeMode() {
    _isPracticeMode = false;
    notifyListeners();
  }
  
  void selectSection(int index) {
    if (_currentHymn != null && index >= 0 && index < _currentHymn!.sections.length) {
      _selectedSectionIndex = index;
      _selectedSegmentIndex = 0;
      
      // Update audio sync with new section's segments
      final sectionSegments = getSegmentsForSection(index);
      if (sectionSegments.isNotEmpty) {
        _audioSyncViewModel.initializeSegments(sectionSegments);
      }
      
      notifyListeners();
    }
  }
  
  void selectSegment(int sectionIndex, int segmentIndex) {
    if (_currentHymn != null && sectionIndex < _currentHymn!.sections.length) {
      final segments = getSegmentsForSection(sectionIndex);
      if (segmentIndex < segments.length) {
        _selectedSectionIndex = sectionIndex;
        _selectedSegmentIndex = segmentIndex;
        
        // Seek to this segment
        final segment = segments[segmentIndex];
        _mainAudioPlayer.seek(Duration(milliseconds: segment.startMs));
        
        // Mark as current in audio sync
        final globalIndex = getGlobalIndex(sectionIndex, segmentIndex);
        if (globalIndex != null) {
          _audioSyncViewModel.markSegmentAsCurrent(globalIndex);
        }
        
        notifyListeners();
      }
    }
  }
  
  // Play segment directly
  Future<void> playSegment(int sectionIndex, int segmentIndex) async {
    final segments = getSegmentsForSection(sectionIndex);
    if (segmentIndex >= 0 && segmentIndex < segments.length) {
      final segment = segments[segmentIndex];
      
      // Stop current playback
      await _mainAudioPlayer.stop();
      
      // Update state first so selectedSection getter works correctly
      _selectedSectionIndex = sectionIndex;
      _selectedSegmentIndex = segmentIndex;
      
      // Determine audio URL (Section specific -> Hymn fallback)
      final audioUrl = selectedSection?.audioUrl ?? _currentHymn?.hymn.audioUrl;
      
      if (audioUrl != null) {
        try {
          if (kIsWeb) {
            try {
              final response = await ApiClient.fetchAudioBytes(audioUrl);
              await _mainAudioPlayer.play(BytesSource(response.bodyBytes));
            } catch (e) {
              debugPrint('HymnDetailViewModel playSegment fallback to UrlSource: $e');
              await _mainAudioPlayer.play(UrlSource(audioUrl));
            }
          } else {
            await _mainAudioPlayer.play(UrlSource(audioUrl));
          }
          await _mainAudioPlayer.seek(Duration(milliseconds: segment.startMs));
          
          final globalIndex = getGlobalIndex(sectionIndex, segmentIndex);
          if (globalIndex != null) {
            _audioSyncViewModel.markSegmentAsCurrent(globalIndex);
          }
          
          notifyListeners();
        } catch (e) {
          debugPrint('Error playing segment: $e');
        }
      } else {
        debugPrint('No audio URL available for segment playback');
      }
    }
  }
  
  // Recording completion callback
  void onRecordingComplete(double score, int sectionIndex, int segmentIndex) {
    final globalIndex = getGlobalIndex(sectionIndex, segmentIndex);
    if (globalIndex != null) {
      _audioSyncViewModel.markSegmentCompleted(globalIndex);
    }
    
    // Move to next segment if score is good and we're in practice mode
    if (_isPracticeMode && score >= 70.0) {
      final segments = getSegmentsForSection(sectionIndex);
      if (segmentIndex < segments.length - 1) {
        // Next segment in same section
        _selectedSegmentIndex = segmentIndex + 1;
      } else if (sectionIndex < (_currentHymn?.sections.length ?? 0) - 1) {
        // Move to next section
        _selectedSectionIndex = sectionIndex + 1;
        _selectedSegmentIndex = 0;
        selectSection(_selectedSectionIndex);
      }
    }
    
    notifyListeners();
  }
  
  // Get practice progress
  String getPracticeProgressText() {
    final total = _audioSyncViewModel.segments.length;
    final completed = _audioSyncViewModel.getCompletedSegmentsCount();
    return '$completed/$total segments';
  }
  
  double getPracticeProgressPercentage() {
    return _audioSyncViewModel.getPracticeProgress();
  }
  
  // Increment play counts
  Future<void> incrementHymnPlay() async {
    if (_currentHymn != null) {
      await _practiceProvider.incrementHymnPlay(_currentHymn!.hymn.id);
    }
  }
  
  Future<void> incrementSectionPlay(int sectionId) async {
    await _practiceProvider.incrementSectionPlay(sectionId);
  }
  
  Future<void> incrementSectionPractice(int sectionId) async {
    await _practiceProvider.incrementSectionPractice(sectionId);
  }
  
  Future<void> incrementHymnPractice() async {
    if (_currentHymn != null) {
      await _practiceProvider.incrementHymnPractice(_currentHymn!.hymn.id);
    }
  }
  
  @override
  void dispose() {
    _audioSyncViewModel.dispose();
    isRecording.dispose();
    recordingElapsedMs.dispose();
    isAlternatePlaybackActive.dispose();
    alternateElapsedMs.dispose();
    super.dispose();
  }
}