import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../providers/hymn_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/app_error.dart';
import '../../widgets/empty_state.dart';
import './widgets/hymn_card.dart';
import './widgets/filter_bar.dart';
import './widgets/search_field.dart';
import './widgets/daily_focus_widget.dart';
import './widgets/continue_practicing_widget.dart';
import './widgets/recently_added_widget.dart';
import './widgets/playlists_widget.dart';
import './widgets/hymn_list_item.dart';
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
  bool _isGridView = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _openHymn(BuildContext context, int hymnId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HymnDetailScreen(hymnId: hymnId),
      ),
    );
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
          // Logo artwork is dark navy; tint it white on dark so it stays visible.
          colorFilter: appIsDark
              ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
              : null,
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
              size: 26,
              color: AppColors.primaryAccent,
            ),
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
          IconButton(
            icon: Icon(Icons.refresh, size: 26, color: AppColors.primaryAccent),
            onPressed: _refresh,
          ),
        ],
      ),
      body: _buildContent(hymnProvider, locale),
    );
  }

  Widget _buildContent(HymnProvider hymnProvider, LocaleProvider locale) {
    // IMPORTANT: SearchField and FilterBar must stay mounted across loads.
    // Previously a full-screen AppLoader/AppError replaced the entire body
    // whenever `isLoading && hymns.isEmpty` — which happens right after an
    // empty-result search — destroying the SearchField's state (keyboard
    // closed, text cleared) mid-typing. Now only the area BELOW the filter
    // bar swaps between loader / error / empty / list.
    final bool noFilters = hymnProvider.searchQuery.isEmpty &&
        hymnProvider.selectedCategoryId == null &&
        hymnProvider.selectedScaleId == null &&
        hymnProvider.sortBy == null;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          const SearchField(),
          const SizedBox(height: 12),
          const FilterBar(),
          const SizedBox(height: 24),
          if (noFilters) ...[
            const ContinuePracticingWidget(),
            const RecentlyAddedWidget(),
            const PlaylistsWidget(),
          ],
          ..._buildResultArea(hymnProvider),
        ],
      ),
    );
  }

  List<Widget> _buildResultArea(HymnProvider hymnProvider) {
    // Loading the first page (no data yet) — show an inline loader.
    if (hymnProvider.isLoading && hymnProvider.hymns.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (hymnProvider.error != null && hymnProvider.hymns.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: AppError(
            message: hymnProvider.error!,
            onRetry: () => hymnProvider.refresh(),
          ),
        ),
      ];
    }

    if (hymnProvider.hymns.isEmpty) {
      return [
        EmptyState(
          title: 'No Hymns Found',
          message: hymnProvider.searchQuery.isNotEmpty
              ? 'No hymns match your search'
              : 'Try changing your filters',
          icon: Icons.music_off,
          onRetry: () => hymnProvider.refresh(),
        ),
      ];
    }

    return [
      const SizedBox(height: 16),
      if (_isGridView)
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
              onTap: () => _openHymn(context, hymn.id),
            );
          },
        )
      else
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: hymnProvider.hymns.length + (hymnProvider.hasMore ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (index == hymnProvider.hymns.length) return _buildLoadMoreButton();
            final hymn = hymnProvider.hymns[index];
            return HymnListItem(
              hymn: hymn,
              onTap: () => _openHymn(context, hymn.id),
            );
          },
        ),
    ];
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

