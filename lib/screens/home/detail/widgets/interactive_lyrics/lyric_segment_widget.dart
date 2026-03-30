// lib/screens/home/detail/widgets/interactive_lyrics/lyric_segment_widget.dart
import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';

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
      duration: const Duration(milliseconds: 1500), // Slower, smoother pulse
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
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
      _animationController.animateTo(0, duration: const Duration(milliseconds: 300));
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _formatTime(int milliseconds) {
    // Show MM:SS or M:SS
    final seconds = (milliseconds / 1000).floor();
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
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
            final isHighlight = widget.isPlaying || _isHovered;
            
            return Transform.scale(
              scale: isHighlight && widget.isPlaying ? _scaleAnimation.value : (isHighlight ? 1.01 : 1.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  color: isHighlight ? AppColors.secondary.withValues(alpha: 0.08) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isHighlight ? AppColors.secondary : Colors.grey.withValues(alpha: 0.2),
                    width: isHighlight ? 1.5 : 1,
                  ),
                  boxShadow: isHighlight ? [
                    BoxShadow(
                      color: AppColors.secondary.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ] : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    // Play indicator
                    _buildPlayIndicator(isHighlight),
                    const SizedBox(width: 16),
                    
                    // Lyric text and Time
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.text,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontSize: 16,
                              fontWeight: isHighlight ? FontWeight.w600 : FontWeight.normal,
                              color: isHighlight ? AppColors.textPrimary : AppColors.textSecondary,
                            ),
                          ),
                          if (isHighlight) ...[
                            const SizedBox(height: 4),
                            Text(
                              _formatTime(widget.startTime),
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.secondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ]
                        ],
                      ),
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

  Widget _buildPlayIndicator(bool isHighlight) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 4,
      height: 40,
      decoration: BoxDecoration(
        color: isHighlight ? AppColors.secondary : Colors.transparent,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
