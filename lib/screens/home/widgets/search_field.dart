import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../providers/hymn_provider.dart';
import '../../../providers/locale_provider.dart';

class SearchField extends StatefulWidget {
  const SearchField({super.key});

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();

  OverlayEntry? _overlayEntry;
  List<String> _suggestions = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    _focusNode.removeListener(_onFocusChange);
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      _removeOverlay();
      final provider = Provider.of<HymnProvider>(context, listen: false);
      provider.setSearchQuery(_controller.text.trim());
    }
  }

  void _onTextChanged() {
    // NOTE: deliberately no setState here. Rebuilding the TextField on every
    // keystroke while the keyboard holds a composing region (unrecognized
    // words like "tttttt") resets the field. The clear button updates via a
    // ValueListenableBuilder bound to the controller instead.
    final query = _controller.text.trim();

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      // trigger list search
      final provider = Provider.of<HymnProvider>(context, listen: false);
      provider.setSearchQuery(query);

      // fetch autocomplete suggestions
      if (query.length >= 2) {
        final results = await _fetchSuggestions(query);
        // only show if text hasn't changed since we fired
        if (_controller.text.trim() == query && _focusNode.hasFocus) {
          _showSuggestions(results);
        }
      } else {
        _removeOverlay();
      }
    });

    // hide stale suggestions immediately on new keystroke
    if (_suggestions.isNotEmpty) {
      _removeOverlay();
    }
  }

  Future<List<String>> _fetchSuggestions(String query) async {
    try {
      final response = await ApiClient.get(
        ApiEndpoints.hymnAutocomplete,
        queryParams: {'query': query},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        return data.cast<String>();
      }
    } catch (_) {}
    return [];
  }

  void _showSuggestions(List<String> suggestions) {
    _removeOverlay();
    if (suggestions.isEmpty) return;

    _suggestions = suggestions;
    _overlayEntry = _buildOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _suggestions = [];
  }

  void _selectSuggestion(String value) {
    _controller.text = value;
    _controller.selection = TextSelection.collapsed(offset: value.length);
    _removeOverlay();
    _focusNode.unfocus();
    final provider = Provider.of<HymnProvider>(context, listen: false);
    provider.setSearchQuery(value);
  }

  OverlayEntry _buildOverlayEntry() {
    return OverlayEntry(
      builder: (context) => Positioned(
        width: _getFieldWidth(),
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 56),
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: AppColors.textSecondary.withValues(alpha: 0.1),
                ),
                itemBuilder: (context, index) {
                  final option = _suggestions[index];
                  return InkWell(
                    onTap: () => _selectSuggestion(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.music_note_rounded,
                            size: 16,
                            color: AppColors.primary.withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              option,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _getFieldWidth() {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    return box?.size.width ?? 300;
  }

  void _clearSearch() {
    _controller.clear();
    _removeOverlay();
    _debounce?.cancel();
    final provider = Provider.of<HymnProvider>(context, listen: false);
    provider.setSearchQuery('');
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LocaleProvider>(context);

    return CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: locale.translate('search_hint'),
            hintStyle: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary.withValues(alpha: 0.5),
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: AppColors.primary.withValues(alpha: 0.7),
              size: 28,
            ),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) {
                if (value.text.isEmpty) return const SizedBox.shrink();
                return IconButton(
                  icon: const Icon(Icons.close_rounded, size: 24),
                  onPressed: _clearSearch,
                );
              },
            ),
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
          // Sensible defaults for a search box (no autocorrect getting in the
          // way). The real "field clears on backspace" bug was a widget
          // remount in HomeScreen, not the IME — fixed there.
          autocorrect: false,
          enableSuggestions: false,
          onSubmitted: (value) {
            _debounce?.cancel();
            _removeOverlay();
            final provider = Provider.of<HymnProvider>(context, listen: false);
            provider.setSearchQuery(value.trim());
          },
        ),
      ),
    );
  }
}
