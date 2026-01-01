import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../widgets/app_loader.dart';
import '../../../widgets/app_error.dart';

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
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _hymnData;

  @override
  void initState() {
    super.initState();
    _loadHymnDetail();
  }

  Future<void> _loadHymnDetail() async {
    // This will be implemented in Phase 3
    // For now, we'll simulate loading
    await Future.delayed(const Duration(seconds: 2));
    
    setState(() {
      _isLoading = false;
      _hymnData = {
        'title': 'Sample Hymn Title',
        'description': 'This will be implemented in Phase 3',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _hymnData?['title'] ?? 'Hymn Detail',
          style: AppTextStyles.headerMedium,
        ),
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const AppLoader();
    }

    if (_error != null) {
      return AppError(
        message: _error!,
        onRetry: _loadHymnDetail,
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Phase 3 Implementation',
            style: AppTextStyles.headerLarge.copyWith(
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'This screen will be fully implemented in Phase 3 of the project plan.',
            style: AppTextStyles.bodyLarge,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Planned Features:',
                    style: AppTextStyles.headerSmall,
                  ),
                  const SizedBox(height: 8),
                  _buildFeatureItem('Hymn details with lyrics'),
                  _buildFeatureItem('Audio player for hymn and sections'),
                  _buildFeatureItem('Practice mode with feedback'),
                  _buildFeatureItem('Recording and comparison feature'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            size: 16,
            color: AppColors.success,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}