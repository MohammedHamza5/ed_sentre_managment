import 'package:flutter/material.dart';
import 'search_bar.dart';
import 'filter_panel.dart';
import 'sort_widget.dart';

/// Complete search and filter bar with all controls
/// شريط البحث والفلترة الكامل مع جميع عناصر التحكم

class SearchFilterBar extends StatefulWidget {
  final String? searchHintText;
  final ValueChanged<String>? onSearch;
  final VoidCallback? onClear;
  final List<FilterOption> filters;
  final ValueChanged<Map<String, dynamic>>? onApplyFilters;
  final VoidCallback? onResetFilters;
  final List<SortOption> sortOptions;
  final ValueChanged<SortOption>? onSortChanged;
  final Map<String, dynamic> filterValues;
  final SortOption? currentSort;
  final bool showFilterButton;
  final double? width;

  const SearchFilterBar({
    super.key,
    this.searchHintText,
    this.onSearch,
    this.onClear,
    this.filters = const [],
    this.onApplyFilters,
    this.onResetFilters,
    this.sortOptions = const [],
    this.onSortChanged,
    this.filterValues = const {},
    this.currentSort,
    this.showFilterButton = true,
    this.width,
  });

  @override
  State<SearchFilterBar> createState() => _SearchFilterBarState();
}

class _SearchFilterBarState extends State<SearchFilterBar> {
  final GlobalKey _filterButtonKey = GlobalKey();

  void _showFilterPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          child: FilterPanel(
            filters: widget.filters,
            initialValues: widget.filterValues,
            onApply: (filterValues) {
              Navigator.of(context).pop();
              if (widget.onApplyFilters != null) {
                widget.onApplyFilters!(filterValues);
              }
            },
            onReset: widget.onResetFilters,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      width: widget.width,
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          AppSearchBar(
            hintText: widget.searchHintText,
            onSearch: widget.onSearch,
            onClear: widget.onClear,
            showFilterButton: widget.showFilterButton,
            onFilterPressed: widget.showFilterButton ? _showFilterPanel : null,
            width: double.infinity,
          ),
          const SizedBox(height: 8),
          if (!isMobile && widget.filters.isNotEmpty) _buildDesktopFilterBar(),
        ],
      ),
    );
  }

  Widget _buildDesktopFilterBar() {
    return Row(
      children: [
        if (widget.filters.isNotEmpty) ...[
          TextButton.icon(
            onPressed: _showFilterPanel,
            icon: const Icon(Icons.filter_list),
            label: const Text('فلترة'),
          ),
          const SizedBox(width: 8),
        ],
        if (widget.sortOptions.isNotEmpty) ...[
          const Text('ترتيب حسب:'),
          const SizedBox(width: 8),
          Flexible(
            child: SortWidget(
              sortOptions: widget.sortOptions,
              onSortChanged: widget.onSortChanged,
              initialSort: widget.currentSort,
            ),
          ),
        ],
        const Spacer(),
        if (widget.filterValues.isNotEmpty)
          TextButton.icon(
            onPressed: widget.onResetFilters,
            icon: const Icon(Icons.clear_all),
            label: const Text('إزالة الفلاتر'),
          ),
      ],
    );
  }
}


