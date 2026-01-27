import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/hymn_provider.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/app_error.dart';
import '../../widgets/empty_state.dart';
import './widgets/hymn_card.dart';
import './widgets/filter_bar.dart';
import './widgets/search_field.dart';
import './widgets/daily_focus_widget.dart';
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
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _loadMore() {
    final hymnProvider = Provider.of<HymnProvider>(context, listen: false);
    if (hymnProvider.hasMore && !hymnProvider.loadingMore) {
      hymnProvider.loadHymns(loadMore: true);
    }
  }

  Future<void> _refresh() async {
    final hymnProvider = Provider.of<HymnProvider>(context, listen: false);
    hymnProvider.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final hymnProvider = Provider.of<HymnProvider>(context);
    final locale = Provider.of<LocaleProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(locale.translate('home_title'), style: AppTextStyles.headerMedium),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
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
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: [
          const SearchField(),
          const SizedBox(height: 12),
          const FilterBar(),
          const SizedBox(height: 24),
          const DailyFocusWidget(),
          
          if (hymnProvider.hymns.isEmpty)
            EmptyState(
              title: 'No Hymns Found',
              message: hymnProvider.searchQuery.isNotEmpty
                  ? 'No hymns match your search'
                  : 'Try changing your filters',
              icon: Icons.music_off,
              onRetry: () => hymnProvider.refresh(),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
                childAspectRatio: 0.65,
              ),
              itemCount: hymnProvider.hymns.length + (hymnProvider.loadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == hymnProvider.hymns.length) return _buildLoadingMore();

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
      ),
    );
  }

  Widget _buildLoadingMore() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
      ),
    );
  }
}
