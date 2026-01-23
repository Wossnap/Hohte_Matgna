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

class _FilterBarState extends State<FilterBar> {
  final List<Map<String, dynamic>> _sortOptions = [
    {'value': null, 'label': 'Default'},
    {'value': 'plays', 'label': 'Most Popular'},
  ];

  @override
  Widget build(BuildContext context) {
    final metadataProvider = Provider.of<MetadataProvider>(context);
    final hymnProvider = Provider.of<HymnProvider>(context);
    final locale = Provider.of<LocaleProvider>(context);

    if (metadataProvider.isLoading) {
      return _buildLoadingState();
    }

    if (metadataProvider.error != null) {
      return _buildErrorState(metadataProvider.error!);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.greyCard,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              // Category Filter
              Expanded(
                child: _buildCategoryFilter(metadataProvider, hymnProvider, locale),
              ),
              const SizedBox(width: 12),
              
              // Scale Filter
              Expanded(
                child: _buildScaleFilter(metadataProvider, hymnProvider, locale),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Sort Filter
          _buildSortFilter(hymnProvider, locale),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter(MetadataProvider metadataProvider, HymnProvider hymnProvider, LocaleProvider locale) {
    // Create dropdown items
    final List<Map<String, dynamic>> categoryItems = [
      {'id': null, 'name': 'All Categories'}
    ];
    
    categoryItems.addAll(
      metadataProvider.categories.map((category) => {
        'id': category.id,
        'name': category.name.toString()
      }).toList()
    );

    return _buildFilterDropdown<int?>(
      label: locale.translate('filter_category'),
      value: hymnProvider.selectedCategoryId,
      items: categoryItems,
      onChanged: (value) {
        hymnProvider.setCategoryId(value);
      },
    );
  }

  Widget _buildScaleFilter(MetadataProvider metadataProvider, HymnProvider hymnProvider, LocaleProvider locale) {
    // Create dropdown items
    final List<Map<String, dynamic>> scaleItems = [
      {'id': null, 'name': 'All Scales'}
    ];
    
    scaleItems.addAll(
      metadataProvider.scales.map((scale) => {
        'id': scale.id,
        'name': scale.name.toString()
      }).toList()
    );

    return _buildFilterDropdown<int?>(
      label: locale.translate('filter_scale'),
      value: hymnProvider.selectedScaleId,
      items: scaleItems,
      onChanged: (value) {
        hymnProvider.setScaleId(value);
      },
    );
  }

  Widget _buildSortFilter(HymnProvider hymnProvider, LocaleProvider locale) {
    return _buildFilterDropdown<String?>(
      label: locale.translate('filter_sort'),
      value: hymnProvider.sortBy,
      items: _sortOptions,
      displayField: 'label',
      valueField: 'value',
      onChanged: (value) {
        hymnProvider.setSort(value);
      },
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
              icon: Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.primary.withValues(alpha: 0.7)),
              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
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
                      fontWeight: value == itemValue ? FontWeight.bold : FontWeight.normal,
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
          Text(
            'Loading filters...',
            style: AppTextStyles.caption,
          ),
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
        border: Border.all(color: AppColors.error.withAlpha((0.3 * 255).round())),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 16,
            color: AppColors.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Filter error',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.error,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}