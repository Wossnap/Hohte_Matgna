import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:mobile/core/theme/app_colors.dart';

class NoteComparisonGraph extends StatelessWidget {
  final List<String> referenceNotes;
  final List<String> recordedNotes;
  final double height;

  const NoteComparisonGraph({
    super.key,
    required this.referenceNotes,
    required this.recordedNotes,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    if (referenceNotes.isEmpty && recordedNotes.isEmpty) {
      return SizedBox(height: height, child: const Center(child: Text('No pitch data available')));
    }

    final chromaRef = referenceNotes.map(_noteToChroma).where((c) => c != -1).toList();
    final chromaRec = recordedNotes.map(_noteToChroma).where((c) => c != -1).toList();

    final maxNoteCount = math.max(referenceNotes.length, recordedNotes.length);
    final minWidth = 800.0;
    final pixelsPerNote = 40.0;
    final totalWidth = math.max(minWidth, maxNoteCount * pixelsPerNote);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Legend
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
          child: Row(
            children: [
              _buildLegendItem('Reference', Colors.blue),
              const SizedBox(width: 16),
              _buildLegendItem('Recorded', AppColors.accentGold),
            ],
          ),
        ),
        
        // Graph Area
        Container(
          height: height + 30, // Extra space for X-axis labels
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.05),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            children: [
              // Sticky Y-Axis
              Positioned(
                left: 0,
                top: 0,
                bottom: 30,
                width: 40,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    border: Border(right: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
                  ),
                  child: _buildYAxis(),
                ),
              ),
              
              // Scrollable Chart
              Positioned.fill(
                left: 40,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: totalWidth,
                    height: height + 30,
                    child: Stack(
                      children: [
                        CustomPaint(
                          size: Size(totalWidth, height),
                          painter: _PitchPainter(
                            chromaRef: chromaRef,
                            chromaRec: chromaRec,
                          ),
                        ),
                        // X-Axis Labels
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 30,
                          child: _buildXAxis(totalWidth, maxNoteCount),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildYAxis() {
    final noteNames = ['B', 'A#', 'A', 'G#', 'G', 'F#', 'F', 'E', 'D#', 'D', 'C#', 'C'];
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: noteNames.map((name) => Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Text(
          name,
          style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: Colors.grey),
          textAlign: TextAlign.right,
        ),
      )).toList(),
    );
  }

  Widget _buildXAxis(double width, int count) {
    final interval = math.max(1, (count / 20).floor());
    final labels = <Widget>[];
    const padding = 20.0;

    for (int i = 0; i < count; i++) {
      if (i % interval == 0 || i == count - 1) {
        final x = count == 1 
            ? width / 2 
            : padding + (i / (count - 1)) * (width - 2 * padding);
        
        labels.add(Positioned(
          left: x - 10,
          child: Text(
            '${i + 1}',
            style: const TextStyle(fontSize: 9, color: Colors.grey),
          ),
        ));
      }
    }

    return Stack(children: labels);
  }

  int _noteToChroma(String note) {
    final n = note.toUpperCase().trim();
    // Strip octave number if present
    final cleanNote = n.replaceAll(RegExp(r'\d'), '');
    const map = {
      'C': 0, 'C#': 1, 'DB': 1,
      'D': 2, 'D#': 3, 'EB': 3,
      'E': 4,
      'F': 5, 'F#': 6, 'GB': 6,
      'G': 7, 'G#': 8, 'AB': 8,
      'A': 9, 'A#': 10, 'BB': 10,
      'B': 11
    };
    return map[cleanNote] ?? -1;
  }
}

class _PitchPainter extends CustomPainter {
  final List<int> chromaRef;
  final List<int> chromaRec;
  final double padding = 20.0;
  static const double pitchRange = 11.0;

  _PitchPainter({required this.chromaRef, required this.chromaRec});

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);
    _drawPath(canvas, size, chromaRef, Colors.blue.withValues(alpha: 0.5), 3.0);
    _drawPath(canvas, size, chromaRec, AppColors.accentGold.withValues(alpha: 0.8), 3.0);
    _drawDots(canvas, size, chromaRef, Colors.blue);
    _drawDots(canvas, size, chromaRec, AppColors.accentGold);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.1)
      ..strokeWidth = 1.0;

    // Draw horizontal lines for notes
    for (int i = 0; i <= 11; i++) {
      final y = size.height - (i / pitchRange * size.height);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    
    // Draw vertical lines every 40px
    for (double x = 40; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  void _drawPath(Canvas canvas, Size size, List<int> vals, Color color, double strokeWidth) {
    if (vals.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    for (int i = 0; i < vals.length; i++) {
      final x = padding + (i / (vals.length - 1)) * (size.width - 2 * padding);
      final y = size.height - (vals[i] / pitchRange * size.height);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  void _drawDots(Canvas canvas, Size size, List<int> vals, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < vals.length; i++) {
      final x = vals.length == 1 
          ? size.width / 2 
          : padding + (i / (vals.length - 1)) * (size.width - 2 * padding);
      final y = size.height - (vals[i] / pitchRange * size.height);
      
      canvas.drawCircle(Offset(x, y), 3.0, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PitchPainter oldDelegate) {
    return oldDelegate.chromaRef != chromaRef || oldDelegate.chromaRec != chromaRec;
  }
}

