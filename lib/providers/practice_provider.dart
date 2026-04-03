// Provider for managing practice sessions, audio recording submission, and feedback polling.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/hymn_detail_model.dart';
import '../models/attempt_model.dart';
import '../services/practice_service.dart';

class PracticeProvider with ChangeNotifier {
  final PracticeService _practiceService = PracticeService();
  final Set<int> _completedSections = {};

  // Current hymn detail
  HymnDetail? _currentHymn;
  bool _isLoading = false;
  String? _error;

  PracticeProvider() {
    _loadSectionCompletions();
  }

  // Getters
  bool isSectionCompleted(int sectionId) => _completedSections.contains(sectionId);

  // Audio comparison state
  bool _isRecording = false;
  bool _isUploading = false;
  bool _isPolling = false;
  Attempt? _latestAttempt;
  String? _comparisonError;

  // Getters
  HymnDetail? get currentHymn => _currentHymn;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isRecording => _isRecording;
  bool get isUploading => _isUploading;
  bool get isPolling => _isPolling;
  Attempt? get latestAttempt => _latestAttempt;
  String? get comparisonError => _comparisonError;

  /// Load hymn details for practice
  Future<void> loadHymnDetail(int hymnId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _currentHymn = await _practiceService.getHymnDetail(hymnId);
      _error = null;
    } catch (e) {
      _error = e.toString();
      _currentHymn = null;
      debugPrint('Error loading hymn detail: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Increment play count for hymn
  Future<void> incrementHymnPlay(int hymnId) async {
    try {
      await _practiceService.incrementHymnPlay(hymnId);
    } catch (e) {
      debugPrint('Error incrementing hymn play: $e');
    }
  }

  /// Increment practice count for hymn
  Future<void> incrementHymnPractice(int hymnId) async {
    try {
      await _practiceService.incrementHymnPractice(hymnId);
    } catch (e) {
      debugPrint('Error incrementing hymn practice: $e');
    }
  }

  /// Increment play count for section
  Future<void> incrementSectionPlay(int sectionId) async {
    try {
      await _practiceService.incrementSectionPlay(sectionId);
    } catch (e) {
      debugPrint('Error incrementing section play: $e');
    }
  }

  /// Increment practice count for section
  Future<void> incrementSectionPractice(int sectionId) async {
    try {
      await _practiceService.incrementSectionPractice(sectionId);
    } catch (e) {
      debugPrint('Error incrementing section practice: $e');
    }
  }

  /// Get breakpoints for audio comparison
  Future<List<double>> getBreakpoints({
    required String playableType,
    required int playableId,
  }) async {
    try {
      return await _practiceService.getBreakpoints(
        playableType: playableType,
        playableId: playableId,
      );
    } catch (e) {
      debugPrint('Error getting breakpoints: $e');
      return [];
    }
  }

  /// Set recording state
  void setRecording(bool recording) {
    _isRecording = recording;
    notifyListeners();
  }

  /// Submit audio for comparison and poll for results
  Future<Attempt?> submitAndPollComparison({
    required String audioFilePath,
    required String playableType,
    required int playableId,
    String algorithm = 'default',
  }) async {
    try {
      _isUploading = true;
      _comparisonError = null;
      notifyListeners();

      // Get baseline attempt ID before submission
      final baseline = await _practiceService.getLatestAttempt(
        playableType: playableType,
        playableId: playableId,
      );
      final int? baselineId = baseline?.id;

      // Submit audio
      final queued = await _practiceService.submitAudioComparison(
        audioFilePath: audioFilePath,
        playableType: playableType,
        playableId: playableId,
        algorithm: algorithm,
      );

      if (!queued) {
        throw Exception('Audio comparison was not queued');
      }

      _isUploading = false;
      _isPolling = true;
      notifyListeners();

      // Poll for results using baseline ID
      final attempt = await _practiceService.pollForResults(
        playableType: playableType,
        playableId: playableId,
        baselineAttemptId: baselineId,
      );

      _latestAttempt = attempt;
      _comparisonError = attempt == null ? 'Timeout waiting for results' : null;

      if (attempt != null && _currentHymn != null) {
        // Refresh detail to get updated practice counts (backend increments them)
        await refresh();
      }

      return attempt;
    } catch (e) {
      _comparisonError = e.toString();
      debugPrint('Error in audio comparison: $e');
      // Rethrow so callers (UI) can present the underlying error message
      rethrow;
    } finally {
      _isUploading = false;
      _isPolling = false;
      notifyListeners();
    }
  }

  /// Get latest attempt without polling
  Future<Attempt?> getLatestAttempt({
    required String playableType,
    required int playableId,
  }) async {
    try {
      final attempt = await _practiceService.getLatestAttempt(
        playableType: playableType,
        playableId: playableId,
      );
      _latestAttempt = attempt;
      notifyListeners();
      return attempt;
    } catch (e) {
      debugPrint('Error getting latest attempt: $e');
      return null;
    }
  }

  /// Clear comparison state
  void clearComparisonState() {
    _latestAttempt = null;
    _comparisonError = null;
    _isRecording = false;
    _isUploading = false;
    _isPolling = false;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Toggle section completion status
  Future<void> toggleSectionCompletion(int sectionId) async {
    final prefs = await SharedPreferences.getInstance();
    if (_completedSections.contains(sectionId)) {
      _completedSections.remove(sectionId);
    } else {
      _completedSections.add(sectionId);
    }
    
    final List<String> list = _completedSections.map((id) => id.toString()).toList();
    await prefs.setStringList('completed_sections', list);
    notifyListeners();
  }

  /// Load section completions from SharedPreferences
  Future<void> _loadSectionCompletions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? list = prefs.getStringList('completed_sections');
      if (list != null) {
        _completedSections.clear();
        for (final idStr in list) {
          final id = int.tryParse(idStr);
          if (id != null) {
            _completedSections.add(id);
          }
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading section completions: $e');
    }
  }

  /// Refresh current hymn
  Future<void> refresh() async {
    if (_currentHymn != null) {
      await loadHymnDetail(_currentHymn!.hymn.id);
    }
  }
}
