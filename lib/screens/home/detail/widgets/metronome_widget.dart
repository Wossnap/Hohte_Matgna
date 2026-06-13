import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';

class MetronomeWidget extends StatefulWidget {
  final int? bpm;
  final List<double>? beatTimestamps;
  final Duration currentPosition;
  final bool isPlaying;
  final bool initialActive;

  const MetronomeWidget({
    super.key,
    this.bpm,
    this.beatTimestamps,
    required this.currentPosition,
    required this.isPlaying,
    this.initialActive = false,
  });

  @override
  State<MetronomeWidget> createState() => _MetronomeWidgetState();
}

class _MetronomeWidgetState extends State<MetronomeWidget> with SingleTickerProviderStateMixin {
  bool _isActive = false;
  bool _soundEnabled = false;
  int _lastBeatIndex = -1;
  bool _isBeatHit = false;
  double? _currentBeatTime;
  
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _isActive = widget.initialActive || (widget.bpm != null || (widget.beatTimestamps?.isNotEmpty ?? false));
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(MetronomeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && _isActive) {
      _checkBeats();
    }
    if (!widget.isPlaying) {
      _lastBeatIndex = -1;
    }
  }

  void _checkBeats() {
    final currentMs = widget.currentPosition.inMilliseconds;
    final currentTimeSeconds = currentMs / 1000.0;
    
    int index = -1;
    double detectedTime = 0;

    if (widget.beatTimestamps != null && widget.beatTimestamps!.isNotEmpty) {
      for (int i = 0; i < widget.beatTimestamps!.length; i++) {
        if (widget.beatTimestamps![i] <= currentTimeSeconds) {
          index = i;
          detectedTime = widget.beatTimestamps![i];
        } else {
          break;
        }
      }
    } else if (widget.bpm != null && widget.bpm! > 0) {
      final spb = 60.0 / widget.bpm!;
      index = (currentTimeSeconds / spb).floor();
      detectedTime = index * spb;
    }

    if (index != -1 && index != _lastBeatIndex) {
      _triggerBeat(detectedTime);
      _lastBeatIndex = index;
    }
  }

  void _triggerBeat(double beatTime) {
    if (!mounted) return;
    
    setState(() {
      _isBeatHit = true;
      _currentBeatTime = beatTime;
    });

    _pulseController.forward(from: 0);
    
    // Haptic feedback for touch-based metronome
    if (_isActive) {
      HapticFeedback.lightImpact();
    }

    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) {
        setState(() {
          _isBeatHit = false;
        });
      }
    });
  }

  void _toggleMetronome() {
    setState(() {
      _isActive = !_isActive;
      if (!_isActive) {
        _lastBeatIndex = -1;
        _currentBeatTime = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.bpm == null && (widget.beatTimestamps == null || widget.beatTimestamps!.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _isActive ? AppColors.primaryAccent.withValues(alpha: 0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isActive ? AppColors.primaryAccent.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              InkWell(
                onTap: _toggleMetronome,
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isActive ? AppColors.primaryAccent.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _isActive ? AppColors.primaryAccent.withValues(alpha: 0.3) : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.music_note,
                        size: 16,
                        color: _isActive ? AppColors.primaryAccent : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.bpm != null ? '${widget.bpm} BPM' : 'Auto Tempo',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: _isActive ? AppColors.primaryAccent : Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Visual Indicator
              if (_isActive) ...[
                Text(
                  _currentBeatTime != null ? '${_currentBeatTime!.toStringAsFixed(2)}s' : '',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                ScaleTransition(
                  scale: Tween<double>(begin: 1.0, end: 1.3).animate(
                    CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
                  ),
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isBeatHit ? Colors.red : Colors.grey.withValues(alpha: 0.3),
                      boxShadow: _isBeatHit ? [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 2,
                        )
                      ] : null,
                    ),
                  ),
                ),
              ],
            ],
          ),
          
          if (_isActive)
            Row(
              children: [
                const Text('Sound', style: TextStyle(fontSize: 10, color: Colors.grey)),
                Transform.scale(
                  scale: 0.7,
                  child: Switch(
                    value: _soundEnabled,
                    onChanged: (val) {
                      setState(() => _soundEnabled = val);
                    },
                    activeThumbColor: AppColors.primaryAccent,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

