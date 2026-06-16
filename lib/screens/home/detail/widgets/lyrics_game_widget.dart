import 'dart:math';
import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';

/// Fill-in-the-blank lyrics game — a faithful port of the Laravel web app's
/// `LyricsGame.vue`. Self-contained: manages its own score/correct/total and
/// navigates one question per lyric line.
///
/// Source priority mirrors the web: `gameContent` (a curated subset) first,
/// then `lyricsContent` (full lyrics) as a fallback — this is why the web shows
/// fewer lines than the full lyrics when `game_content` is set.
class LyricsGameWidget extends StatefulWidget {
  final String? gameContent;
  final String? lyricsContent;

  const LyricsGameWidget({
    super.key,
    this.gameContent,
    this.lyricsContent,
  });

  @override
  State<LyricsGameWidget> createState() => _LyricsGameWidgetState();
}

class _GameQuestion {
  final List<String> words;
  final Set<int> blankIndices;
  _GameQuestion(this.words, this.blankIndices);
}

class _LyricsGameWidgetState extends State<LyricsGameWidget> {
  final _rand = Random();

  List<_GameQuestion> _questions = [];
  int _currentIndex = 0;
  final Map<int, TextEditingController> _controllers = {};

  int _score = 0;
  int _correct = 0;
  int _total = 0;

  String? _feedback;
  bool _feedbackCorrect = false;
  bool _isWaiting = false;
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
  }

  String get _source =>
      (widget.gameContent != null && widget.gameContent!.trim().isNotEmpty)
          ? widget.gameContent!
          : (widget.lyricsContent ?? '');

  void _initGame() {
    _score = 0;
    _correct = 0;
    _total = 0;
    _currentIndex = 0;
    _isComplete = false;
    _isWaiting = false;
    _feedback = null;

    final lines = _source
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    _questions = lines.map((line) {
      final words = line.split(RegExp(r'\s+'));
      // Hide ~50% of words (at least 1), matching the web's difficulty.
      final wordsToHide = max(1, (words.length * 0.5).floor());
      final indices = List.generate(words.length, (i) => i)..shuffle(_rand);
      final blanks = indices.take(wordsToHide).toSet();
      return _GameQuestion(words, blanks);
    }).toList();

    _loadQuestion();
    setState(() {});
  }

  void _loadQuestion() {
    _disposeControllers();
    _feedback = null;
    if (_currentIndex >= _questions.length) return;
    for (final idx in _questions[_currentIndex].blankIndices) {
      _controllers[idx] = TextEditingController();
    }
  }

  _GameQuestion? get _question =>
      _currentIndex < _questions.length ? _questions[_currentIndex] : null;

  bool get _canCheck {
    if (_isWaiting || _isComplete) return false;
    return _controllers.values.any((c) => c.text.trim().isNotEmpty);
  }

  int get _accuracy => _total > 0 ? ((_correct / _total) * 100).round() : 0;

  String _normalize(String s) => s.trim().toLowerCase();

  void _checkAnswer() {
    final q = _question;
    if (q == null || !_canCheck) return;

    bool allCorrect = true;
    for (final idx in q.blankIndices) {
      final user = _normalize(_controllers[idx]!.text);
      final answer = _normalize(q.words[idx]);
      if (user.isEmpty || user != answer) {
        allCorrect = false;
        break;
      }
    }

    setState(() {
      _total++;
      _isWaiting = true;
      if (allCorrect) {
        _correct++;
        _score += 10;
        _feedback = _encouragement();
        _feedbackCorrect = true;
      } else {
        _feedback = 'Some answers need correction. Keep trying!';
        _feedbackCorrect = false;
      }
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() => _isWaiting = false);
      if (allCorrect) {
        _next();
      } else {
        setState(() => _feedback = null);
      }
    });
  }

  void _next() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _loadQuestion();
      });
    } else {
      setState(() {
        _isComplete = true;
        _feedback = null;
      });
    }
  }

  void _skip() {
    final q = _question;
    if (q == null || _isWaiting || _isComplete) return;
    // Reveal the answers, then move on (counts as an attempt, like the web).
    setState(() {
      for (final idx in q.blankIndices) {
        _controllers[idx]!.text = q.words[idx];
      }
      _total++;
      _isWaiting = true;
      _feedback = 'Skipped. Revealing the answer…';
      _feedbackCorrect = false;
    });
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() => _isWaiting = false);
      _next();
    });
  }

  void _showHint() {
    final q = _question;
    if (q == null || _isWaiting || _isComplete) return;
    setState(() {
      for (final idx in q.blankIndices) {
        final c = _controllers[idx]!;
        if (c.text.trim().isEmpty) {
          c.text = q.words[idx].characters.first;
          break;
        }
      }
    });
  }

  String _encouragement() {
    const messages = [
      'Excellent! +10 points ⭐',
      'Perfect! You\'re doing great! 🎉',
      'Correct! Keep it up! 🌟',
      'Amazing! +10 points ✨',
      'You got it! Well done! 🎵',
      'Brilliant! +10 points 💫',
    ];
    return messages[_rand.nextInt(messages.length)];
  }

  String _finalMessage() {
    final a = _accuracy;
    if (a == 100) return '🏆 Perfect Score! You\'ve mastered this hymn!';
    if (a >= 80) return '🌟 Excellent work! You know this hymn well!';
    if (a >= 60) return '👍 Good job! Keep practicing to improve!';
    return '📖 Nice try! Practice makes perfect!';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.06),
            AppColors.secondary.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 1.5),
      ),
      child: _questions.isEmpty ? _buildEmpty() : _buildGame(),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          const Text('📖', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text('No lyrics available for the game.',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildGame() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        _buildStats(),
        const SizedBox(height: 16),
        if (_isComplete) _buildComplete() else _buildQuestion(),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.music_note, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fill in the Blank',
                style: AppTextStyles.headerSmall
                    .copyWith(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            Text('Test your memory!',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ],
    );
  }

  Widget _buildStats() {
    Widget stat(String label, String value, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Column(
            children: [
              Text(value,
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.w900, color: color, fontSize: 16)),
              Text(label,
                  style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w700, fontSize: 9, letterSpacing: 0.5, color: color.withValues(alpha: 0.8))),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        stat('SCORE', '$_score', AppColors.primary),
        const SizedBox(width: 8),
        stat('CORRECT', '$_correct', AppColors.accentGreen),
        const SizedBox(width: 8),
        stat('ACCURACY', '$_accuracy%', AppColors.accentGold),
      ],
    );
  }

  Widget _buildQuestion() {
    final q = _question!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('LINE ${_currentIndex + 1} OF ${_questions.length}',
                  style: AppTextStyles.caption.copyWith(
                      color: AppColors.primaryAccent, fontWeight: FontWeight.w800, letterSpacing: 0.8, fontSize: 11)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: List.generate(q.words.length, (i) {
                  if (q.blankIndices.contains(i)) {
                    return SizedBox(
                      width: 96,
                      child: TextField(
                        controller: _controllers[i],
                        enabled: !_isWaiting,
                        textAlign: TextAlign.center,
                        onChanged: (_) => setState(() {}),
                        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: '____',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          filled: true,
                          fillColor: AppColors.primary.withValues(alpha: 0.04),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppColors.secondary, width: 2),
                          ),
                        ),
                      ),
                    );
                  }
                  return Text(q.words[i],
                      style: AppTextStyles.bodyMedium.copyWith(fontSize: 16, color: AppColors.textPrimary));
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildControls(),
        if (_feedback != null) ...[
          const SizedBox(height: 14),
          _buildFeedback(),
        ],
      ],
    );
  }

  Widget _buildControls() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        ElevatedButton.icon(
          onPressed: _canCheck ? _checkAnswer : null,
          icon: const Icon(Icons.check_rounded, size: 18),
          label: const Text('Check Answer'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.3),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        OutlinedButton.icon(
          onPressed: _isWaiting ? null : _showHint,
          icon: const Icon(Icons.lightbulb_outline_rounded, size: 18),
          label: const Text('Hint'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accentGold,
            side: BorderSide(color: AppColors.accentGold.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        OutlinedButton.icon(
          onPressed: _isWaiting ? null : _skip,
          icon: const Icon(Icons.skip_next_rounded, size: 18),
          label: const Text('Skip'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            side: BorderSide(color: AppColors.textSecondary.withValues(alpha: 0.4)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        OutlinedButton.icon(
          onPressed: _isWaiting ? null : _initGame,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Reset'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accentGreen,
            side: BorderSide(color: AppColors.accentGreen.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _buildFeedback() {
    final color = _feedbackCorrect ? AppColors.accentGreen : AppColors.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(_feedbackCorrect ? Icons.check_circle_rounded : Icons.info_outline_rounded,
              color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_feedback!,
                style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _buildComplete() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppColors.primary.withValues(alpha: 0.12),
          AppColors.secondary.withValues(alpha: 0.12),
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 8),
          Text('Game Complete!',
              style: AppTextStyles.headerSmall.copyWith(
                  fontWeight: FontWeight.w900, color: AppColors.textPrimary, fontSize: 22)),
          const SizedBox(height: 8),
          Text(_finalMessage(),
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          Text('Final Score: $_score   ·   Accuracy: $_accuracy%',
              style: AppTextStyles.bodyMedium
                  .copyWith(fontWeight: FontWeight.bold, color: AppColors.primaryAccent)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _initGame,
            icon: const Icon(Icons.replay_rounded, size: 18),
            label: const Text('Play Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
