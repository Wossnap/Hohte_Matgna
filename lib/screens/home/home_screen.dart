import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import '../../providers/hymn_provider.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/app_error.dart';
import '../../widgets/empty_state.dart';
import './widgets/hymn_card.dart';
import './widgets/filter_bar.dart';
import './widgets/search_field.dart';
import './detail/hymn_detail_screen.dart';

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
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
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
    final authProvider = Provider.of<AuthProvider>(context);
    final hymnProvider = Provider.of<HymnProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Hymn Library',
          style: AppTextStyles.headerMedium,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                authProvider.logout();
              } else if (value == 'clear_filters') {
                hymnProvider.clearFilters();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'clear_filters',
                child: Row(
                  children: [
                    const Icon(Icons.filter_alt_off, size: 20),
                    const SizedBox(width: 8),
                    Text('Clear Filters', style: AppTextStyles.bodyMedium),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    const Icon(Icons.logout, size: 20),
                    const SizedBox(width: 8),
                    Text('Logout', style: AppTextStyles.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const SearchField(), // FIXED: Remove parameters
                const SizedBox(height: 12),
                const FilterBar(),
              ],
            ),
          ),
          Expanded(
            child: _buildContent(hymnProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(HymnProvider hymnProvider) {
    if (hymnProvider.isLoading && hymnProvider.hymns.isEmpty) {
      return const AppLoader();
    }

    if (hymnProvider.error != null && hymnProvider.hymns.isEmpty) {
      return AppError(
        message: hymnProvider.error!,
        onRetry: () => hymnProvider.refresh(),
      );
    }

    if (hymnProvider.hymns.isEmpty) {
      return EmptyState(
        title: 'No Hymns Found',
        message: hymnProvider.searchQuery.isNotEmpty
            ? 'No hymns match your search'
            : 'Try changing your filters',
        icon: Icons.music_off,
        onRetry: () => hymnProvider.refresh(),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: hymnProvider.hymns.length + (hymnProvider.loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == hymnProvider.hymns.length) {
            return _buildLoadingMore();
          }
          
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
    );
  }

  Widget _buildLoadingMore() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}