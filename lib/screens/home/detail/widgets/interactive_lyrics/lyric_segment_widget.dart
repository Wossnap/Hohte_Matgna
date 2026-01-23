// lib/screens/home/detail/widgets/interactive_lyrics/lyric_segment_widget.dart
import 'package:flutter/material.dart';

class LyricSegmentWidget extends StatefulWidget {
  final String text;
  final int startTime;
  final int endTime;
  final bool isPlaying;
  final bool isCompleted;
  final VoidCallback onTap;
  final bool showPracticeControls;

  const LyricSegmentWidget({
    super.key,
    required this.text,
    required this.startTime,
    required this.endTime,
    required this.isPlaying,
    required this.isCompleted,
    required this.onTap,
    this.showPracticeControls = false,
  });

  @override
  State<LyricSegmentWidget> createState() => _LyricSegmentWidgetState();
}

class _LyricSegmentWidgetState extends State<LyricSegmentWidget> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    
    if (widget.isPlaying) {
      _animationController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(LyricSegmentWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !oldWidget.isPlaying) {
      _animationController.repeat(reverse: true);
    } else if (!widget.isPlaying && oldWidget.isPlaying) {
      _animationController.stop();
      _animationController.value = 0;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _formatTime(int milliseconds) {
    final seconds = (milliseconds / 1000).floor();
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _getBackgroundColor(),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getBorderColor(),
                    width: widget.isPlaying ? 2 : 1,
                  ),
                  boxShadow: _getBoxShadow(),
                ),
                child: Row(
                  children: [
                    // Status indicator
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _getStatusColor(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Time indicator
                    Text(
                      _formatTime(widget.startTime),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Lyric text
                    Expanded(
                      child: Text(
                        widget.text,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: widget.isPlaying ? FontWeight.bold : FontWeight.normal,
                          color: _getTextColor(),
                        ),
                      ),
                    ),
                    
                    // Play icon or completed check
                    if (widget.isCompleted)
                      const Icon(Icons.check_circle, color: Colors.green, size: 24)
                    else
                      Icon(
                        widget.isPlaying ? Icons.equalizer : Icons.play_circle_outline,
                        color: widget.isPlaying ? Colors.blue : Colors.grey,
                        size: 24,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    if (widget.isPlaying) return Colors.blue.withValues(alpha: 0.1);
    if (widget.isCompleted) return Colors.green.withValues(alpha: 0.1);
    if (_isHovered) return Colors.grey.withValues(alpha: 0.05);
    return Colors.transparent;
  }

  Color _getBorderColor() {
    if (widget.isPlaying) return Colors.blue;
    if (widget.isCompleted) return Colors.green;
    return Colors.grey.shade300;
  }

  Color _getTextColor() {
    if (widget.isPlaying) return Colors.blue.shade900;
    if (widget.isCompleted) return Colors.green.shade800;
    return Colors.black87;
  }

  Color _getStatusColor() {
    if (widget.isPlaying) return Colors.blue;
    if (widget.isCompleted) return Colors.green;
    return Colors.grey;
  }

  List<BoxShadow> _getBoxShadow() {
    if (widget.isPlaying) {
      return [
        BoxShadow(
          color: Colors.blue.withValues(alpha: 0.3),
          blurRadius: 10,
          spreadRadius: 2,
          offset: const Offset(0, 3),
        ),
      ];
    } else if (_isHovered) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 5,
          offset: const Offset(0, 2),
        ),
      ];
    }
    return [];
  }
}