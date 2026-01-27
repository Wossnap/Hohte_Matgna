import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';

class LyricsGameWidget extends StatefulWidget {
  final String lyrics;
  final Function(bool isCorrect) onAnswerSubmitted;
  final VoidCallback onReset;

  const LyricsGameWidget({
    super.key,
    required this.lyrics,
    required this.onAnswerSubmitted,
    required this.onReset,
  });

  @override
  State<LyricsGameWidget> createState() => _LyricsGameWidgetState();
}

class _LyricsGameWidgetState extends State<LyricsGameWidget> {
  late List<String> _lines;
  int _currentLineIndex = 0;
  List<String> _currentWords = [];
  List<int> _blankIndices = [];
  final Map<int, TextEditingController> _controllers = {};
  String? _feedback;
  Color? _feedbackColor;

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  void _initGame() {
    _lines = widget.lyrics
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    _currentLineIndex = 0;
    _loadLine();
  }

  void _loadLine() {
    if (_currentLineIndex >= _lines.length) return;
    
    final line = _lines[_currentLineIndex];
    _currentWords = line.split(RegExp(r'\s+'));
    _blankIndices = [];
    _controllers.clear();
    
    // Logic from Vue: hide approx 35% of words
    final wordsToHide = (_currentWords.length * 0.35).ceil().clamp(1, _currentWords.length);
    final indices = List.generate(_currentWords.length, (i) => i)..shuffle();
    _blankIndices = indices.take(wordsToHide).toList()..sort();

    for (var idx in _blankIndices) {
      _controllers[idx] = TextEditingController();
    }
    
    _feedback = null;
    setState(() {});
  }

  void _checkAnswer() {
    bool allCorrect = true;
    for (var idx in _blankIndices) {
      final userText = _controllers[idx]!.text.trim().toLowerCase();
      final correctText = _currentWords[idx].toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
      if (userText != correctText) {
        allCorrect = false;
        break;
      }
    }

    setState(() {
      if (allCorrect) {
        _feedback = 'Correct! +10 points';
        _feedbackColor = AppColors.success;
      } else {
        _feedback = 'Incorrect. Moving to next line.';
        _feedbackColor = AppColors.error;
      }
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        widget.onAnswerSubmitted(allCorrect);
        if (_currentLineIndex < _lines.length - 1) {
          _currentLineIndex++;
          _loadLine();
        } else {
          setState(() {
            _feedback = 'Game Over!';
            _feedbackColor = AppColors.primary;
          });
        }
      }
    });
  }

  void _showHint() {
    for (var idx in _blankIndices) {
      if (_controllers[idx]!.text.isEmpty) {
        _controllers[idx]!.text = _currentWords[idx].substring(0, 1);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_lines.isEmpty) return const Text('No lyrics available for game');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Line ${_currentLineIndex + 1} of ${_lines.length}',
                style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              TextButton(onPressed: widget.onReset, child: const Text('Reset Game')),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: List.generate(_currentWords.length, (i) {
              if (_blankIndices.contains(i)) {
                return SizedBox(
                  width: 80,
                  height: 30,
                  child: TextField(
                    controller: _controllers[i],
                    style: AppTextStyles.bodySmall,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      border: UnderlineInputBorder(),
                    ),
                  ),
                );
              }
              return Text(_currentWords[i], style: AppTextStyles.bodyMedium);
            }),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              ElevatedButton(
                onPressed: _checkAnswer,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                child: const Text('Check'),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _showHint,
                child: const Text('Hint'),
              ),
            ],
          ),
          if (_feedback != null) ...[
            const SizedBox(height: 12),
            Text(_feedback!, style: TextStyle(color: _feedbackColor, fontWeight: FontWeight.bold)),
          ],
        ],
      ),
    );
  }
}
