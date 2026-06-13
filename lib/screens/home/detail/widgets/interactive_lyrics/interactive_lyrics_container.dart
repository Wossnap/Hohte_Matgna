// lib/screens/home/detail/widgets/interactive_lyrics/interactive_lyrics_container.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/screens/home/detail/view_models/audio_sync_viewmodel.dart';
import 'package:mobile/screens/home/detail/view_models/hymn_detail_viewmodel.dart';
import 'package:mobile/models/section_model.dart';
import 'package:mobile/screens/home/detail/widgets/interactive_lyrics/lyric_segment_widget.dart';
import 'package:mobile/screens/home/detail/widgets/interactive_lyrics/practice_controls.dart';

enum LyricsMode {
  listen,
  practice,
}

class InteractiveLyricsContainer extends StatefulWidget {
  final List<Section> sections;
  final Function(int sectionIndex, int segmentIndex)? onSegmentTap;
  final LyricsMode mode;
  final bool showPracticeControls;
  final Function(double, int, int)? onRecordingComplete;
  final int? selectedSectionIndex; // For practice mode

  const InteractiveLyricsContainer({
    super.key,
    required this.sections,
    this.onSegmentTap,
    this.mode = LyricsMode.listen,
    this.showPracticeControls = false,
    this.onRecordingComplete,
    this.selectedSectionIndex,
  });

  @override
  State<InteractiveLyricsContainer> createState() => _InteractiveLyricsContainerState();
}

class _InteractiveLyricsContainerState extends State<InteractiveLyricsContainer> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _segmentKeys = {};

  @override
  void initState() {
    super.initState();
    // No need for listeners here as we'll handle it in build/didUpdate
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToActiveSegment(int? activeIndex) {
    if (activeIndex == null) return;
    
    // Use postFrameCallback to ensure the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _segmentKeys[activeIndex];
      if (key != null && key.currentContext != null) {
        Scrollable.ensureVisible(
          key.currentContext!,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          alignment: 0.5, // Center the item
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<HymnDetailViewModel>(context, listen: false);
    final audioSync = Provider.of<AudioSyncViewModel>(context);
    
    // Scroll to active segment in listen mode
    if (widget.mode == LyricsMode.listen) {
      _scrollToActiveSegment(audioSync.currentSegmentIndex);
    } else if (widget.selectedSectionIndex != null) {
      // In practice mode, we might want to scroll to the manually selected segment
      final globalIndex = viewModel.getGlobalIndex(widget.selectedSectionIndex!, viewModel.selectedSegmentIndex);
      _scrollToActiveSegment(globalIndex);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Progress indicator for practice mode
        if (widget.mode == LyricsMode.practice)
          _buildPracticeProgress(viewModel, audioSync),
        
        // Lyrics segments
        Container(
          height: widget.mode == LyricsMode.listen ? 400 : 350,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
            color: AppColors.cardBackground,
          ),
          child: _buildSegmentsList(viewModel, audioSync),
        ),
      ],
    );
  }

  Widget _buildPracticeProgress(HymnDetailViewModel viewModel, AudioSyncViewModel audioSync) {
    final progress = audioSync.getPracticeProgress();
    final total = audioSync.segments.length;
    final completed = audioSync.getCompletedSegmentsCount();
    
    return Column(
      children: [
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation<Color>(
            progress >= 0.8 ? Colors.green :
            progress >= 0.5 ? Colors.orange :
            Colors.blue
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progress: $completed/$total segments',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              '${(progress * 100).round()}%',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSegmentsList(HymnDetailViewModel viewModel, AudioSyncViewModel audioSync) {
    if (widget.mode == LyricsMode.practice && widget.selectedSectionIndex != null) {
      // Practice mode: show only selected section
      return _buildSectionSegments(viewModel, widget.selectedSectionIndex!, audioSync);
    } else {
      // Listen mode: show all sections
      return _buildAllSegments(viewModel, audioSync);
    }
  }

  Widget _buildSectionSegments(HymnDetailViewModel viewModel, int sectionIndex, AudioSyncViewModel audioSync) {
    final sectionSegments = viewModel.getSegmentsForSection(sectionIndex);
    
    if (sectionSegments.isEmpty) {
      return const Center(
        child: Text('No segments available for this section'),
      );
    }

    return ListView.builder(
      controller: widget.mode == LyricsMode.practice ? _scrollController : null,
      padding: const EdgeInsets.all(8),
      itemCount: sectionSegments.length,
      itemBuilder: (context, segmentIndex) {
        final segment = sectionSegments[segmentIndex];
        final isCurrent = _isSegmentCurrent(viewModel, audioSync, sectionIndex, segmentIndex);
        final isCompleted = _isSegmentCompleted(viewModel, audioSync, sectionIndex, segmentIndex);
        final globalIndex = viewModel.getGlobalIndex(sectionIndex, segmentIndex) ?? -1;
        
        // Assign/Reuse key for scrolling
        final key = _segmentKeys.putIfAbsent(globalIndex, () => GlobalKey());

        return Column(
          key: key,
          children: [
            LyricSegmentWidget(
              text: segment.text,
              startTime: segment.startMs,
              endTime: segment.endMs,
              isPlaying: isCurrent,
              isCompleted: isCompleted,
              onTap: () {
                viewModel.playSegment(sectionIndex, segmentIndex);
                widget.onSegmentTap?.call(sectionIndex, segmentIndex);
              },
            ),
            
            // Practice controls for current segment in practice mode
            if (widget.showPracticeControls && 
                widget.mode == LyricsMode.practice && 
                isCurrent)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: PracticeControls(
                  playableType: 'section',
                  playableId: viewModel.selectedSection?.id ?? 0,
                  segmentText: segment.text,
                  onRecordingComplete: (score) {
                    viewModel.onRecordingComplete(score, sectionIndex, segmentIndex);
                    widget.onRecordingComplete?.call(score, sectionIndex, segmentIndex);
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildAllSegments(HymnDetailViewModel viewModel, AudioSyncViewModel audioSync) {
    // Flatten all segments into a single list
    final allSegs = viewModel.visualSegments;
    
    if (allSegs.isEmpty) {
      return const Center(
        child: Text('No lyrics segments available'),
      );
    }
    
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: allSegs.length,
      itemBuilder: (context, index) {
        final item = allSegs[index];
        
        // Use mapping logic for current segment highlight
        final currentAudioIndex = audioSync.currentSegmentIndex;
        final activeVisualIndex = currentAudioIndex != null 
            ? viewModel.getVisualIndexForAudio(currentAudioIndex) 
            : null;
            
        final isCurrent = index == activeVisualIndex;
        
        // Completion logic specific to visual segment
        final isCompleted = index < (activeVisualIndex ?? -1);

        // Assign/Reuse key for scrolling
        final key = _segmentKeys.putIfAbsent(index, () => GlobalKey());

        // Auto-scroll when active
        if (isCurrent) {
            _scrollToActiveSegment(index);
        }

        return Column(
          key: key,
          children: [
            LyricSegmentWidget(
              text: item.segment.text,
              startTime: item.segment.startMs,
              endTime: item.segment.endMs,
              isPlaying: isCurrent,
              isCompleted: isCompleted,
              onTap: () {
                viewModel.playSegment(item.sectionIndex, item.segmentIndex);
                widget.onSegmentTap?.call(item.sectionIndex, item.segmentIndex);
              },
            ),
            const SizedBox(height: 12), // Spacing between boxes
          ],
        );
      },
    );
  }

  bool _isSegmentCurrent(HymnDetailViewModel viewModel, AudioSyncViewModel audioSync, 
                        int sectionIndex, int segmentIndex) {
    if (widget.mode == LyricsMode.practice && widget.selectedSectionIndex == sectionIndex) {
      return segmentIndex == viewModel.selectedSegmentIndex;
    }
    
    // For listen mode, check against audio sync current index
    final globalIndex = viewModel.getGlobalIndex(sectionIndex, segmentIndex);
    return globalIndex != null && globalIndex == audioSync.currentSegmentIndex;
  }

  bool _isSegmentCompleted(HymnDetailViewModel viewModel, AudioSyncViewModel audioSync,
                          int sectionIndex, int segmentIndex) {
    final globalIndex = viewModel.getGlobalIndex(sectionIndex, segmentIndex);
    if (globalIndex == null) return false;
    
    return audioSync.segmentCompleted[globalIndex] ?? false;
  }
}
