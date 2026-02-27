import 'package:flutter/material.dart';

/// Filter panel widget for advanced filtering
/// لوحة الفلاتر المتقدمة

class FilterPanel extends StatefulWidget {
  final List<FilterOption> filters;
  final ValueChanged<Map<String, dynamic>>? onApply;
  final VoidCallback? onReset;
  final Map<String, dynamic> initialValues;

  const FilterPanel({
    super.key,
    required this.filters,
    this.onApply,
    this.onReset,
    this.initialValues = const {},
  });

  @override
  State<FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<FilterPanel> {
  late Map<String, dynamic> _filterValues;

  @override
  void initState() {
    super.initState();
    _filterValues = Map<String, dynamic>.from(widget.initialValues);
  }

  void _updateFilterValue(String key, dynamic value) {
    setState(() {
      _filterValues[key] = value;
    });
  }

  void _resetFilters() {
    setState(() {
      _filterValues.clear();
    });
    if (widget.onReset != null) {
      widget.onReset!();
    }
  }

  void _applyFilters() {
    if (widget.onApply != null) {
      widget.onApply!(_filterValues);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final activeFilterCount = _filterValues.values.where((v) => v != null && v != '' && (v is! List || v.isNotEmpty)).length;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Modern Gradient Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.deepPurple.shade400,
                  Colors.deepPurple.shade600,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepPurple.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.filter_alt,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'خيارات الفلترة',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (activeFilterCount > 0)
                        Text(
                          '$activeFilterCount فلتر نشط',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          
          // Filters Content
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.filters.length,
              itemBuilder: (context, index) {
                final filter = widget.filters[index];
                return _buildFilterWidget(filter, isMobile);
              },
            ),
          ),
          
          // Action Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(
                top: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _resetFilters,
                    icon: const Icon(Icons.refresh),
                    label: const Text('إعادة تعيين'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _applyFilters,
                    icon: const Icon(Icons.check),
                    label: const Text('تطبيق'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterWidget(FilterOption filter, bool isMobile) {
    final currentValue = _filterValues[filter.key];

    switch (filter.type) {
      case FilterType.text:
        return _buildTextFilter(filter, currentValue);

      case FilterType.dropdown:
        return _buildDropdownFilter(filter, currentValue);

      case FilterType.dateRange:
        return _buildDateRangeFilter(filter, currentValue);

      case FilterType.checkbox:
        return _buildCheckboxFilter(filter, currentValue);

      case FilterType.slider:
        return _buildSliderFilter(filter, currentValue);

      default:
        return const SizedBox();
    }
  }

  Widget _buildTextFilter(FilterOption filter, dynamic currentValue) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        decoration: InputDecoration(
          labelText: filter.label,
          hintText: filter.hintText,
          border: const OutlineInputBorder(),
        ),
        controller: TextEditingController(text: currentValue as String?),
        onChanged: (value) => _updateFilterValue(filter.key, value),
      ),
    );
  }

  Widget _buildDropdownFilter(FilterOption filter, dynamic currentValue) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: filter.label,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            value: currentValue as String?,
            items: filter.options
                ?.map(
                  (option) => DropdownMenuItem(
                    value: option.value,
                    child: Text(option.label),
                  ),
                )
                .toList(),
            onChanged: (value) => _updateFilterValue(filter.key, value),
          ),
        ),
      ),
    );
  }

  Widget _buildDateRangeFilter(FilterOption filter, dynamic currentValue) {
    final range = currentValue as DateRange?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(filter.label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'من',
                    border: OutlineInputBorder(),
                  ),
                  readOnly: true,
                  controller: TextEditingController(
                    text: range?.start != null
                        ? '${range!.start!.year}/${range.start!.month}/${range.start!.day}'
                        : '',
                  ),
                  onTap: () => _selectDate(filter.key, true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'إلى',
                    border: OutlineInputBorder(),
                  ),
                  readOnly: true,
                  controller: TextEditingController(
                    text: range?.end != null
                        ? '${range!.end!.year}/${range.end!.month}/${range.end!.day}'
                        : '',
                  ),
                  onTap: () => _selectDate(filter.key, false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(String key, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      final currentRange = _filterValues[key] as DateRange?;
      DateRange newRange;

      if (isStart) {
        newRange = DateRange(start: picked, end: currentRange?.end);
      } else {
        newRange = DateRange(start: currentRange?.start, end: picked);
      }

      _updateFilterValue(key, newRange);
    }
  }

  Widget _buildCheckboxFilter(FilterOption filter, dynamic currentValue) {
    final selectedValues = List<String>.from(
      currentValue as List<String>? ?? [],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(filter.label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: filter.options!.map((option) {
              final isSelected = selectedValues.contains(option.value);

              return FilterChip(
                label: Text(option.label),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      selectedValues.add(option.value);
                    } else {
                      selectedValues.remove(option.value);
                    }
                    _updateFilterValue(filter.key, selectedValues);
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderFilter(FilterOption filter, dynamic currentValue) {
    final value = (currentValue as double?) ?? filter.minValue ?? 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${filter.label}: ${value.round()}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Slider(
            value: value,
            min: filter.minValue ?? 0.0,
            max: filter.maxValue ?? 100.0,
            divisions: filter.divisions,
            onChanged: (newValue) => _updateFilterValue(filter.key, newValue),
          ),
        ],
      ),
    );
  }
}

class FilterOption {
  final String key;
  final String label;
  final String? hintText;
  final FilterType type;
  final List<FilterOptionItem>? options;
  final double? minValue;
  final double? maxValue;
  final int? divisions;

  FilterOption({
    required this.key,
    required this.label,
    this.hintText,
    required this.type,
    this.options,
    this.minValue,
    this.maxValue,
    this.divisions,
  });
}

enum FilterType { text, dropdown, dateRange, checkbox, slider }

class FilterOptionItem {
  final String value;
  final String label;

  FilterOptionItem({required this.value, required this.label});
}

class DateRange {
  final DateTime? start;
  final DateTime? end;

  DateRange({this.start, this.end});
}


