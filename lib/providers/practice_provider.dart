/// Provider for managing practice sessions, audio recording submission, and feedback polling.
import 'package:flutter/material.dart';
import '../models/hymn_detail_model.dart';
import '../models/attempt_model.dart';
import '../services/practice_service.dart';

class PracticeProvider with ChangeNotifier {
  final PracticeService _practiceService = PracticeService();

  // Current hymn detail
  HymnDetail? _currentHymn;
  bool _isLoading = false;
  String? _error;

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
      // Optionally reload hymn to get updated counts
    } catch (e) {
      debugPrint('Error incrementing hymn play: $e');
    }
  }

  /// Increment practice count for hymn
  Future<void> incrementHymnPractice(int hymnId) async {
    try {
      await _practiceService.incrementHymnPractice(hymnId);
      // Optionally reload hymn to get updated counts
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

      // Poll for results
      final attempt = await _practiceService.pollForResults(
        playableType: playableType,
        playableId: playableId,
        afterTimestamp: DateTime.now().subtract(const Duration(seconds: 5)),
      );

      _latestAttempt = attempt;
      _comparisonError = attempt == null ? 'Timeout waiting for results' : null;

      return attempt;
    } catch (e) {
      _comparisonError = e.toString();
      debugPrint('Error in audio comparison: $e');
      return null;
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

  /// Refresh current hymn
  Future<void> refresh() async {
    if (_currentHymn != null) {
      await loadHymnDetail(_currentHymn!.hymn.id);
    }
  }
}
