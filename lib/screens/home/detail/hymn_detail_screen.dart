import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/widgets/app_loader.dart';
import 'package:mobile/widgets/app_error.dart';
import 'package:mobile/providers/practice_provider.dart';

import 'package:mobile/screens/home/detail/view_models/hymn_detail_viewmodel.dart';
import 'package:mobile/screens/home/detail/widgets/audio_player_widget.dart';
import 'package:mobile/screens/home/detail/widgets/compare_widget.dart';
import 'package:mobile/screens/home/detail/widgets/interactive_lyrics_widget.dart';
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
      // Use microtask to avoid setState() during build call
      Future.microtask(() => _viewModel.loadHymnDetail(widget.hymnId));
      _isViewModelInitialized = true;
    }
  }

  @override
  void dispose() {
    _mainAudioPlayer.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<HymnDetailViewModel>.value(
      value: _viewModel,
      child: Consumer<HymnDetailViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading) {
            return const Scaffold(body: AppLoader());
          }

          if (viewModel.error != null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Error')),
              body: AppError(
                message: viewModel.error!,
                onRetry: () => viewModel.loadHymnDetail(widget.hymnId),
              ),
            );
          }

          final hymnDetail = viewModel.currentHymn;
          if (hymnDetail == null) return const Scaffold(body: SizedBox.shrink());

          return Scaffold(
            backgroundColor: AppColors.background,
            body: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 340,
                  pinned: true,
                  stretch: true,
                  backgroundColor: AppColors.primary,
                  flexibleSpace: FlexibleSpaceBar(
                    stretchModes: const [
                      StretchMode.zoomBackground,
                      StretchMode.blurBackground,
                    ],
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary,
                            AppColors.primary,
                            AppColors.secondary,
                          ],
                          stops: const [0.0, 0.7, 1.0],
                        ),
                      ),
                      child: SafeArea(
                        child: Center(
                          child: HymnHeaderWidget(hymn: hymnDetail),
                        ),
                      ),
                    ),
                  ),
                  foregroundColor: AppColors.textLight,
                  // The global appBarTheme.iconTheme (textPrimary) would otherwise
                  // override foregroundColor and render the leading/action icons
                  // dark on the navy gradient — invisible in light mode. Force
                  // white here since this header sits on the brand gradient in
                  // both light and dark modes.
                  iconTheme: const IconThemeData(color: Colors.white),
                  actionsIconTheme: const IconThemeData(color: Colors.white),
                  elevation: 0,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.share_outlined),
                      onPressed: () {
                        // Share functionality
                      },
                    ),
                  ],
                ),

                // Hymn Statistics Row (Synced with Website)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Plays:  ${hymnDetail.userPlays?.toString() ?? '0'}',
                              style: AppTextStyles.headerMedium.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primaryAccent,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Practices:  ${hymnDetail.userPractices?.toString() ?? '0'}',
                              style: AppTextStyles.headerMedium.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppColors.accentGreen,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 8),
                      // Main Melody Card
                      _buildMainMelody(viewModel, hymnDetail),
                      
                      const SizedBox(height: 32),
                      
                      // Sections Header
                      if (hymnDetail.sections.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Hymn Sections',
                              style: AppTextStyles.headerSmall.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.unfold_more_rounded, size: 18),
                              label: const Text('Expand All'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primaryAccent,
                                textStyle: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Practice individual segments with targeted audio',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...hymnDetail.sections.map((section) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: SectionWidget(
                            section: section, 
                            hymnId: widget.hymnId,
                            bpm: hymnDetail.hymn.bpm,
                            beatTimestamps: hymnDetail.hymn.beatTimestamps,
                          ),
                        )),
                      ],
                      
                      const SizedBox(height: 60),
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainMelody(HymnDetailViewModel viewModel, HymnDetail hymnDetail) {
    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() => _isMainMelodyExpanded = !_isMainMelodyExpanded);
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
                  Icon(Icons.music_note, color: AppColors.primaryAccent),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('ዋና (Main Melody)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  Icon(_isMainMelodyExpanded ? Icons.expand_more : Icons.chevron_right, color: AppColors.primaryAccent),
                ],
              ),
            ),
          ),
          // Keep the expanded content mounted (just hidden) when collapsed, so
          // the AudioPlayerWidget / InteractiveLyricsWidget State survives a
          // collapse→expand and audio keeps playing — otherwise re-expanding
          // recreates them fresh and desyncs from the player (frozen bar /
          // garbled audio / no replay), the same bug as scrolling off-screen.
          Offstage(
            offstage: !_isMainMelodyExpanded,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                   AudioPlayerWidget(
                    audioUrl: hymnDetail.hymn.audioUrl!,
                    audioPlayer: _mainAudioPlayer,
                    playableId: hymnDetail.hymn.id,
                    playableType: 'hymn',
                    onPlay: () => viewModel.incrementHymnPlay(),
                    bpm: hymnDetail.hymn.bpm,
                    beatTimestamps: hymnDetail.hymn.beatTimestamps,
                  ),
                  const SizedBox(height: 24),
                  
                  CompareWidget(
                    hymnId: hymnDetail.hymn.id,
                    playableType: 'hymn',
                    playableId: hymnDetail.hymn.id,
                  ),
                  const SizedBox(height: 24),
                  
                  // Lyrics Section Header (karaoke — always shown, like the web)
                  Row(
                    children: [
                      Text('Lyrics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryAccent)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (hymnDetail.hymnLyricSegments.isNotEmpty)
                    InteractiveLyricsWidget(
                      audioPlayer: _mainAudioPlayer,
                      lyricSegments: hymnDetail.hymnLyricSegments,
                    )
                  else
                    const SizedBox.shrink(),

                  const SizedBox(height: 24),
                  const Divider(height: 1),
                  const SizedBox(height: 24),

                  // Full Lyrics Display Section with inline Lyrics | Game toggle
                  // (the toggle switches the full lyrics text <-> game, like the web)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.notes_rounded, color: AppColors.primaryAccent, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Full Lyrics',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryAccent,
                            ),
                          ),
                        ],
                      ),
                      _buildLyricsGameToggle(viewModel),
                    ],
                  ),
                  const SizedBox(height: 16),
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
                      padding: const EdgeInsets.all(20),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                      ),
                      child: SelectableText(
                        hymnDetail.fullLyrics,
                        style: AppTextStyles.bodyMedium.copyWith(
                          height: 1.8,
                          fontSize: 16,
                          color: AppColors.textPrimary.withValues(alpha: 0.9),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
  }

  // Removed unused _buildStatCard (UI helper) — not referenced anymore

  // Inline segmented toggle (Lyrics | Game) that switches the same card,
  // matching the web. Active segment is filled with the brand accent.
  Widget _buildLyricsGameToggle(HymnDetailViewModel viewModel) {
    Widget segment({
      required IconData icon,
      required String label,
      required bool active,
      required VoidCallback onTap,
    }) {
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppColors.primaryAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: active ? Colors.white : AppColors.primaryAccent),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: active ? Colors.white : AppColors.primaryAccent,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.primaryAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primaryAccent.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          segment(
            icon: Icons.menu_book,
            label: 'Lyrics',
            active: !viewModel.showLyricsGame,
            onTap: () => viewModel.setLyricsGame(false),
          ),
          segment(
            icon: Icons.videogame_asset,
            label: 'Game',
            active: viewModel.showLyricsGame,
            onTap: () => viewModel.setLyricsGame(true),
          ),
        ],
      ),
    );
  }

  Widget _buildGameStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryAccent)),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}

