import 'package:flutter/material.dart';
import '../../../../../models/hymn_detail_model.dart';
import '../../view_models/hymn_detail_viewmodel.dart';
import '../interactive_lyrics/interactive_lyrics_container.dart';

class PracticeSectionWidget extends StatelessWidget {
  final HymnDetailViewModel viewModel;
  final HymnDetail hymn;
  final VoidCallback onTogglePracticeMode;

  const PracticeSectionWidget({
    super.key,
    required this.viewModel,
    required this.hymn,
    required this.onTogglePracticeMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.school, color: Colors.orange, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    viewModel.isPracticeMode ? 'Practice Mode' : 'Practice',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: onTogglePracticeMode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: viewModel.isPracticeMode ? Colors.orange : Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: Text(viewModel.isPracticeMode ? 'Exit' : 'Start'),
              ),
            ],
          ),
          
          if (!viewModel.isPracticeMode) ...[
            const SizedBox(height: 16),
            const Text('Practice each section individually with feedback'),
          ],
          
          if (viewModel.isPracticeMode) ...[
            const SizedBox(height: 20),
            _buildPracticeProgress(viewModel),
            const SizedBox(height: 20),
            if (hymn.sections.length > 1) _buildSectionTabs(viewModel),
            const SizedBox(height: 20),
            _buildPracticeContent(viewModel),
          ],
        ],
      ),
    );
  }

  Widget _buildPracticeProgress(HymnDetailViewModel viewModel) {
    final progress = viewModel.getPracticeProgressPercentage();
    return Column(
      children: [
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation<Color>(
            progress >= 0.8 ? Colors.green : progress >= 0.5 ? Colors.orange : Colors.blue,
          ),
          minHeight: 8,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(viewModel.getPracticeProgressText(), style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text('${(progress * 100).round()}%', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionTabs(HymnDetailViewModel viewModel) {
    final hymn = viewModel.currentHymn!;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: hymn.sections.asMap().entries.map((entry) {
          final index = entry.key;
          final section = entry.value;
          final isSelected = index == viewModel.selectedSectionIndex;
          final segments = viewModel.getSegmentsForSection(index);
          
          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('${section.name} (${segments.length})'),
              selected: isSelected,
              onSelected: (_) => viewModel.selectSection(index),
              selectedColor: Colors.orange,
              labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPracticeContent(HymnDetailViewModel viewModel) {
    final selectedSection = viewModel.selectedSection;
    if (selectedSection == null) return _buildEmptyState('Select a section to practice');
    
    final segments = viewModel.getSegmentsForSection(viewModel.selectedSectionIndex);
    if (segments.isEmpty) return _buildEmptyState('No segments in this section');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Practicing: ${selectedSection.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        
        InteractiveLyricsContainer(
          sections: [selectedSection],
          onSegmentTap: viewModel.playSegment,
          mode: LyricsMode.practice,
          showPracticeControls: true,
          selectedSectionIndex: viewModel.selectedSectionIndex,
          onRecordingComplete: (score, sectionIndex, segmentIndex) {
            viewModel.onRecordingComplete(score, sectionIndex, segmentIndex);
          },
        ),
        
        const SizedBox(height: 20),
        _buildPracticeTips(),
      ],
    );
  }

  Widget _buildPracticeTips() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, size: 16, color: Colors.green),
              SizedBox(width: 8),
              Text('Tips:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            ],
          ),
          SizedBox(height: 8),
          Text('• Aim for 80%+ similarity score\n• Record in quiet environment\n• Practice difficult lines multiple times',
              style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Icon(Icons.music_off, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
