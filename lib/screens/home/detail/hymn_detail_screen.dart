import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/widgets/app_loader.dart';
import 'package:mobile/widgets/app_error.dart';
import 'package:mobile/providers/practice_provider.dart';
import 'package:mobile/screens/home/detail/view_models/audio_sync_viewmodel.dart';
import 'package:mobile/screens/home/detail/view_models/hymn_detail_viewmodel.dart';
import 'package:mobile/screens/home/detail/widgets/audio_player_widget.dart';
import 'package:mobile/screens/home/detail/widgets/compare_widget.dart';
import 'package:mobile/screens/home/detail/widgets/lyrics_game_widget.dart';
import 'package:mobile/screens/home/detail/widgets/section_widget.dart';
import 'package:mobile/models/hymn_detail_model.dart';
import 'widgets/hymn_header_widget.dart';

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
  bool _isMainMelodyExpanded = true;
  
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
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: AppColors.background,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              title: Text(
                viewModel.currentHymn?.hymn.title ?? 'Hymn Detail',
                style: AppTextStyles.headerSmall,
              ),
              actions: [
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
          
          _buildMainMelody(viewModel, hymn),
          const SizedBox(height: 24),
          
          if (hymn.sections.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Sections',
                style: AppTextStyles.headerSmall.copyWith(fontSize: 22),
              ),
            ),
            ...hymn.sections.map((section) => SectionWidget(
              section: section,
              hymnId: widget.hymnId,
              depth: 0,
            )),
          ],
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildMainMelody(HymnDetailViewModel viewModel, HymnDetail hymnDetail) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() => _isMainMelodyExpanded = !_isMainMelodyExpanded);
              if (_isMainMelodyExpanded && hymnDetail.hymn.audioUrl != null) {
                _mainAudioPlayer.resume();
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isMainMelodyExpanded ? AppColors.primary.withValues(alpha: 0.05) : Colors.transparent,
                borderRadius: _isMainMelodyExpanded 
                    ? const BorderRadius.vertical(top: Radius.circular(12)) 
                    : BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.music_note, color: AppColors.primary),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('ዋና (Main Melody)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  Icon(_isMainMelodyExpanded ? Icons.expand_more : Icons.chevron_right, color: AppColors.primary),
                ],
              ),
            ),
          ),
          if (_isMainMelodyExpanded)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hymnDetail.hymn.audioUrl != null) ...[
                    AudioPlayerWidget(
                      audioUrl: hymnDetail.hymn.audioUrl!,
                      audioPlayer: _mainAudioPlayer,
                      initialPlays: hymnDetail.hymn.plays,
                      onPlay: viewModel.incrementHymnPlay,
                    ),
                    const SizedBox(height: 20),
                    CompareWidget(
                      hymnId: widget.hymnId,
                      playableType: 'hymn',
                      label: 'Compare with Reference',
                    ),
                  ],
                  const SizedBox(height: 24),
                  
                  // Lyrics Section Header with Game Toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Lyrics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      OutlinedButton.icon(
                        onPressed: viewModel.toggleLyricsGame,
                        icon: Icon(viewModel.showLyricsGame ? Icons.menu_book : Icons.videogame_asset),
                        label: Text(viewModel.showLyricsGame ? 'Show Lyrics' : 'Play Game'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primary),
                          foregroundColor: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  if (viewModel.showLyricsGame)
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildGameStat('Score', viewModel.gameScore.toString()),
                            _buildGameStat('Accuracy', '${viewModel.gameAccuracy}%'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        LyricsGameWidget(
                          lyrics: hymnDetail.hymn.content ?? '',
                          onAnswerSubmitted: viewModel.submitGameAnswer,
                          onReset: viewModel.resetGameState,
                        ),
                      ],
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        hymnDetail.hymn.content ?? 'No lyrics available',
                        style: AppTextStyles.bodyMedium.copyWith(height: 1.6),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGameStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}
