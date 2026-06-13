import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../providers/hymn_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/app_error.dart';
import '../../widgets/empty_state.dart';
import './widgets/hymn_card.dart';
import './widgets/filter_bar.dart';
import './widgets/search_field.dart';
import './widgets/daily_focus_widget.dart';
import './widgets/continue_practicing_widget.dart';
import './widgets/recently_added_widget.dart';
import './widgets/playlists_widget.dart';
import './detail/hymn_detail_screen.dart';

/// The home dashboard displaying the list of hymns.
///
/// Includes search, filtering, and the daily focus widget.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _loadMore() {
    final hymnProvider = Provider.of<HymnProvider>(context, listen: false);
    if (hymnProvider.hasMore && !hymnProvider.loadingMore) {
      hymnProvider.loadHymns(loadMore: true);
    }
  }

  Future<void> _refresh() async {
    final hymnProvider = Provider.of<HymnProvider>(context, listen: false);
    final dashboardProvider = Provider.of<DashboardProvider>(context, listen: false);
    await Future.wait([hymnProvider.refresh(), dashboardProvider.refresh()]);
  }

  @override
  Widget build(BuildContext context) {
    final hymnProvider = Provider.of<HymnProvider>(context);
    final locale = Provider.of<LocaleProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: SvgPicture.asset(
          'assets/images/Hohte_logo.svg',
          height: 36,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 28, color: AppColors.primary),
            onPressed: _refresh,
          ),
        ],
      ),
      body: _buildContent(hymnProvider, locale),
    );
  }

  Widget _buildContent(HymnProvider hymnProvider, LocaleProvider locale) {
    if (hymnProvider.isLoading && hymnProvider.hymns.isEmpty) {
      return const AppLoader();
    }

    if (hymnProvider.error != null && hymnProvider.hymns.isEmpty) {
      return AppError(
        message: hymnProvider.error!,
        onRetry: () => hymnProvider.refresh(),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          const SearchField(),
          const SizedBox(height: 12),
          const FilterBar(),
          const SizedBox(height: 24),
          const ContinuePracticingWidget(),
          const RecentlyAddedWidget(),
          const PlaylistsWidget(),
          // const DailyFocusWidget(),
          
          if (hymnProvider.hymns.isEmpty)
            EmptyState(
              title: 'No Hymns Found',
              message: hymnProvider.searchQuery.isNotEmpty
                  ? 'No hymns match your search'
                  : 'Try changing your filters',
              icon: Icons.music_off,
              onRetry: () => hymnProvider.refresh(),
            )
          else ...[
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.72,
              ),
              itemCount: hymnProvider.hymns.length + (hymnProvider.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == hymnProvider.hymns.length) return _buildLoadMoreButton();

                final hymn = hymnProvider.hymns[index];
                return HymnCard(
                  hymn: hymn,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HymnDetailScreen(hymnId: hymn.id),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: ElevatedButton(
          onPressed: _loadMore,
          child: const Text('Load More'),
        ),
      ),
    );
  }
}

