import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../providers/metadata_provider.dart';
import '../../../providers/hymn_provider.dart';
import '../../../providers/locale_provider.dart';

class FilterBar extends StatefulWidget {
  const FilterBar({super.key});

  @override
  State<FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<FilterBar>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _controller;
  late final Animation<double> _expandAnim;

  final List<Map<String, dynamic>> _sortOptions = [
    {'value': null, 'label': 'Default'},
    {'value': 'plays', 'label': 'Most Popular'},
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _expandAnim = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _controller.forward() : _controller.reverse();
  }

  int _activeCount(HymnProvider p) =>
      (p.selectedCategoryId != null ? 1 : 0) +
      (p.selectedScaleId != null ? 1 : 0) +
      (p.sortBy != null ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    final metadataProvider = Provider.of<MetadataProvider>(context);
    final hymnProvider = Provider.of<HymnProvider>(context);
    final locale = Provider.of<LocaleProvider>(context);

    final activeCount = _activeCount(hymnProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter toggle button row
        Row(
          children: [
            GestureDetector(
              onTap: _toggle,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: _expanded
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 18,
                      color: _expanded ? Colors.white : AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Filter',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: _expanded ? Colors.white : AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    if (activeCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: _expanded
                              ? Colors.white
                              : AppColors.secondary,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$activeCount',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _expanded
                                  ? AppColors.primary
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: _expanded ? Colors.white : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (activeCount > 0) ...[
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  hymnProvider.setCategoryId(null);
                  hymnProvider.setScaleId(null);
                  hymnProvider.setSort(null);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Clear',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),

        // Collapsible filter panel
        SizeTransition(
          sizeFactor: _expandAnim,
          axisAlignment: -1,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: metadataProvider.isLoading
                ? _buildLoadingState()
                : metadataProvider.error != null
                    ? _buildErrorState(metadataProvider.error!)
                    : Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildCategoryFilter(
                                    metadataProvider, hymnProvider, locale),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildScaleFilter(
                                    metadataProvider, hymnProvider, locale),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildSortFilter(hymnProvider, locale),
                        ],
                      ),
          ),
        ),

        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildCategoryFilter(MetadataProvider metadataProvider,
      HymnProvider hymnProvider, LocaleProvider locale) {
    final List<Map<String, dynamic>> categoryItems = [
      {'id': null, 'name': 'All Categories'}
    ];
    categoryItems.addAll(metadataProvider.categories
        .map((c) => {'id': c.id, 'name': c.name.toString()})
        .toList());

    return _buildFilterDropdown<int?>(
      label: locale.translate('filter_category'),
      value: hymnProvider.selectedCategoryId,
      items: categoryItems,
      onChanged: (value) => hymnProvider.setCategoryId(value),
    );
  }

  Widget _buildScaleFilter(MetadataProvider metadataProvider,
      HymnProvider hymnProvider, LocaleProvider locale) {
    final List<Map<String, dynamic>> scaleItems = [
      {'id': null, 'name': 'All Scales'}
    ];
    scaleItems.addAll(metadataProvider.scales
        .map((s) => {'id': s.id, 'name': s.name.toString()})
        .toList());

    return _buildFilterDropdown<int?>(
      label: locale.translate('filter_scale'),
      value: hymnProvider.selectedScaleId,
      items: scaleItems,
      onChanged: (value) => hymnProvider.setScaleId(value),
    );
  }

  Widget _buildSortFilter(HymnProvider hymnProvider, LocaleProvider locale) {
    return _buildFilterDropdown<String?>(
      label: locale.translate('filter_sort'),
      value: hymnProvider.sortBy,
      items: _sortOptions,
      displayField: 'label',
      valueField: 'value',
      onChanged: (value) => hymnProvider.setSort(value),
    );
  }

  Widget _buildFilterDropdown<T>({
    required String label,
    required T? value,
    required List<Map<String, dynamic>> items,
    required Function(T?) onChanged,
    String displayField = 'name',
    String valueField = 'id',
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w800,
            fontSize: 10,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down_rounded,
                  size: 28,
                  color: AppColors.primary.withValues(alpha: 0.7)),
              style: AppTextStyles.bodyMedium
                  .copyWith(fontWeight: FontWeight.w600),
              onChanged: onChanged,
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(12),
              items: items.map<DropdownMenuItem<T>>((item) {
                final dynamic itemValue = item[valueField];
                final String displayText = item[displayField].toString();
                return DropdownMenuItem<T>(
                  value: itemValue as T?,
                  child: Text(
                    displayText,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: value == itemValue
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text('Loading filters...', style: AppTextStyles.caption),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.error.withAlpha((0.3 * 255).round())),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Filter error',
              style:
                  AppTextStyles.caption.copyWith(color: AppColors.error),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
