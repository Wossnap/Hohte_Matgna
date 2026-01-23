// lib/screens/home/detail/hymn_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/widgets/app_loader.dart';
import 'package:mobile/widgets/app_error.dart';
import 'package:mobile/providers/practice_provider.dart';
import 'package:mobile/screens/home/detail/view_models/audio_sync_viewmodel.dart';

import 'package:mobile/screens/home/detail/view_models/hymn_detail_viewmodel.dart';
import 'package:mobile/screens/home/detail/widgets/main_audio_player.dart';
import 'package:mobile/screens/home/detail/widgets/interactive_lyrics/interactive_lyrics_container.dart';
import 'package:mobile/screens/home/detail/widgets/compare_widget.dart';
import 'package:mobile/screens/home/detail/widgets/full_lyrics_widget.dart';
import 'package:mobile/screens/home/detail/widgets/practice_history_widget.dart';
import 'package:mobile/models/hymn_detail_model.dart';

import 'widgets/hymn_header_widget.dart';
import 'widgets/practice/practice_section_widget.dart';

class HymnDetailScreen extends StatefulWidget {
  final int hymnId;
  
  const HymnDetailScreen({
    super.key,
    required this.hymnId,
  });

  @override
  State<HymnDetailScreen> createState() => _HymnDetailScreenState();
}

class _HymnDetailScreenState extends State<HymnDetailScreen> {
  late AudioPlayer _mainAudioPlayer;
  late HymnDetailViewModel _viewModel;
  bool _isViewModelInitialized = false;
  
  @override
  void initState() {
    super.initState();
    _mainAudioPlayer = AudioPlayer();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isViewModelInitialized) {
      final practiceProvider = Provider.of<PracticeProvider>(context, listen: false);
      _viewModel = HymnDetailViewModel(practiceProvider, _mainAudioPlayer);
      
      // Use addPostFrameCallback to avoid setState() during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _viewModel.loadHymnDetail(widget.hymnId);
      });
      
      _isViewModelInitialized = true;
    }
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _mainAudioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<HymnDetailViewModel>.value(value: _viewModel),
        ChangeNotifierProvider<AudioSyncViewModel>.value(value: _viewModel.audioSyncViewModel),
      ],
      child: Consumer<HymnDetailViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            appBar: AppBar(
              title: Text(
                viewModel.currentHymn?.hymn.title ?? 'Hymn Detail',
                style: AppTextStyles.headerMedium,
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                if (viewModel.currentHymn != null && viewModel.currentHymn!.sections.isNotEmpty)
                  IconButton(
                    icon: Icon(
                      viewModel.isPracticeMode ? Icons.school : Icons.school_outlined,
                      color: viewModel.isPracticeMode ? Colors.orange : null,
                    ),
                    onPressed: () => _togglePracticeMode(viewModel),
                    tooltip: viewModel.isPracticeMode ? 'Exit Practice' : 'Start Practice',
                  ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => viewModel.loadHymnDetail(widget.hymnId),
                ),
              ],
            ),
            body: _buildContent(viewModel),
          );
        },
      ),
    );
  }

  void _togglePracticeMode(HymnDetailViewModel viewModel) {
    if (viewModel.isPracticeMode) {
      viewModel.exitPracticeMode();
    } else {
      viewModel.enterPracticeMode();
      if (viewModel.currentHymn?.sections.isNotEmpty ?? false) {
        viewModel.selectSection(0);
      }
    }
  }

  Widget _buildContent(HymnDetailViewModel viewModel) {
    if (viewModel.isLoading) return const AppLoader(message: 'Loading hymn...');
    if (viewModel.error != null) return AppError(message: viewModel.error!, onRetry: () => viewModel.loadHymnDetail(widget.hymnId));
    
    final hymn = viewModel.currentHymn;
    if (hymn == null) return const Center(child: Text('No hymn data'));

    return RefreshIndicator(
      onRefresh: () => viewModel.loadHymnDetail(widget.hymnId),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          HymnHeaderWidget(hymn: hymn),
          const SizedBox(height: 32),
          
          if (hymn.hymn.audioUrl != null) ...[
            MainAudioPlayer(
              audioPlayer: _mainAudioPlayer,
              audioUrl: hymn.hymn.audioUrl!,
              title: 'Master Audio',
              onPlay: viewModel.incrementHymnPlay,
            ),
            const SizedBox(height: 24),
          ],
          
          _buildInteractiveLyrics(viewModel, hymn),
          const SizedBox(height: 24),
          
          CompareWidget(hymnId: widget.hymnId, playableType: 'hymn'),
          const SizedBox(height: 24),
          
          FullLyricsWidget(lyrics: hymn.hymn.content ?? hymn.hymn.description ?? ''),
          const SizedBox(height: 24),
          
          PracticeSectionWidget(
            viewModel: viewModel,
            hymn: hymn,
            onTogglePracticeMode: () => _togglePracticeMode(viewModel),
          ),
          const SizedBox(height: 24),
          
          PracticeHistoryWidget(practices: hymn.hymn.practices),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildInteractiveLyrics(HymnDetailViewModel viewModel, HymnDetail hymn) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Interactive Lyrics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
        const SizedBox(height: 8),
        const Text('Tap any line to play from that point', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 16),
        
        hymn.sections.isNotEmpty 
            ? InteractiveLyricsContainer(
                sections: hymn.sections,
                onSegmentTap: viewModel.playSegment,
                mode: LyricsMode.listen,
              )
            : _buildEmptyState('No sections available'),
      ],
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