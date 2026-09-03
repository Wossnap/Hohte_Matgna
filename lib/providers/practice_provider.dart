// Provider for managing practice sessions, audio recording submission, and feedback polling.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/hymn_detail_model.dart';
import '../models/section_model.dart';
import '../models/attempt_model.dart';
import '../services/practice_service.dart';

class PracticeProvider with ChangeNotifier {
  final PracticeService _practiceService = PracticeService();
  final Set<int> _completedSections = {};
  bool _hymnCompleted = false;

  // Current hymn detail
  HymnDetail? _currentHymn;
  bool _isLoading = false;
  String? _error;

  PracticeProvider() {
    _loadSectionCompletions();
  }

  // Getters
  bool isSectionCompleted(int sectionId) => _completedSections.contains(sectionId);
  /// Whether the currently loaded hymn is complete (all root sections done).
  bool get isHymnCompleted => _hymnCompleted;

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
      _initCompletionFromServer();
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

  /// Toggle section completion, mirroring the web's `toggleSectionComplete`
  /// (`Practice/Show.vue`):
  ///   1. the toggled section and all its descendants take the new state,
  ///   2. every ancestor becomes complete iff all of its children are,
  ///   3. the whole batch is persisted server-side,
  ///   4. the hymn counts as complete iff all root sections are.
  Future<void> toggleSectionCompletion(int sectionId) async {
    final willComplete = !_completedSections.contains(sectionId);

    // 1. Cascade DOWN — the toggled section plus every descendant.
    final changed = <int, bool>{};
    final ids = <int>{sectionId};
    final section = _findSectionById(sectionId);
    if (section != null) _collectDescendantIds(section, ids);
    for (final id in ids) {
      changed[id] = willComplete;
    }
    _applyCompletion(changed);

    // 2. Cascade UP — nearest ancestor first, so each level sees the state its
    // children were just given.
    for (final ancestor in _ancestorsOf(sectionId)) {
      final complete = ancestor.children.isNotEmpty &&
          ancestor.children.every((c) => _completedSections.contains(c.id));
      if (complete != _completedSections.contains(ancestor.id)) {
        changed[ancestor.id] = complete;
        _applyCompletion({ancestor.id: complete});
      }
    }

    // 3. Hymn completion is derived from the root sections.
    final roots = _currentHymn?.sections ?? const <Section>[];
    final hymnComplete =
        roots.isNotEmpty && roots.every((r) => _completedSections.contains(r.id));
    final hymnChanged = hymnComplete != _hymnCompleted;
    _hymnCompleted = hymnComplete;

    notifyListeners();
    await _cacheSectionCompletions();

    // 4. Persist. Local state is already applied optimistically; a failure
    // leaves the SharedPreferences cache as the offline fallback.
    try {
      await _practiceService.setSectionsCompletion(changed);
      if (hymnChanged && _currentHymn != null) {
        await _practiceService.setHymnCompletion(_currentHymn!.hymn.id, hymnComplete);
      }
    } catch (e) {
      debugPrint('Error persisting completion: $e');
    }
  }

  /// Applies completion state locally without notifying.
  void _applyCompletion(Map<int, bool> updates) {
    updates.forEach((id, complete) {
      if (complete) {
        _completedSections.add(id);
      } else {
        _completedSections.remove(id);
      }
    });
  }

  /// Returns the ancestors of [id] in the current hymn, nearest parent first.
  List<Section> _ancestorsOf(int id) {
    final path = <Section>[];
    bool walk(Section node) {
      if (node.id == id) return true;
      for (final child in node.children) {
        if (walk(child)) {
          path.add(node);
          return true;
        }
      }
      return false;
    }

    for (final root in _currentHymn?.sections ?? const <Section>[]) {
      if (walk(root)) break;
    }
    return path;
  }

  /// Seeds completion state for the freshly loaded hymn from the server's
  /// `progress` payload. Only this hymn's sections are touched, so cached
  /// state for other hymns survives.
  void _initCompletionFromServer() {
    final hymn = _currentHymn;
    if (hymn == null) return;

    final serverState = <int, bool>{};
    void visit(Section s) {
      serverState[s.id] = s.isCompleted;
      for (final child in s.children) {
        visit(child);
      }
    }

    for (final root in hymn.sections) {
      visit(root);
    }

    _applyCompletion(serverState);
    _hymnCompleted = hymn.isCompleted;
    _cacheSectionCompletions();
  }

  Future<void> _cacheSectionCompletions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'completed_sections',
        _completedSections.map((id) => id.toString()).toList(),
      );
    } catch (e) {
      debugPrint('Error caching section completions: $e');
    }
  }

  /// Finds a section anywhere in the current hymn's section tree by id.
  Section? _findSectionById(int id) {
    for (final root in _currentHymn?.sections ?? const <Section>[]) {
      final found = _searchSection(root, id);
      if (found != null) return found;
    }
    return null;
  }

  Section? _searchSection(Section section, int id) {
    if (section.id == id) return section;
    for (final child in section.children) {
      final found = _searchSection(child, id);
      if (found != null) return found;
    }
    return null;
  }

  /// Adds the ids of every descendant of [section] into [ids].
  void _collectDescendantIds(Section section, Set<int> ids) {
    for (final child in section.children) {
      ids.add(child.id);
      _collectDescendantIds(child, ids);
    }
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
