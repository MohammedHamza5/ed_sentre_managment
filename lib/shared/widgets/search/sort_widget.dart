import 'package:flutter/material.dart';

/// Sort widget for ordering results
/// مكون ترتيب النتائج

class SortWidget extends StatefulWidget {
  final List<SortOption> sortOptions;
  final ValueChanged<SortOption>? onSortChanged;
  final SortOption? initialSort;

  const SortWidget({
    super.key,
    required this.sortOptions,
    this.onSortChanged,
    this.initialSort,
  });

  @override
  State<SortWidget> createState() => _SortWidgetState();
}

class _SortWidgetState extends State<SortWidget> {
  late SortOption? _selectedSort;

  @override
  void initState() {
    super.initState();
    _selectedSort = widget.initialSort;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (isMobile) {
      return PopupMenuButton<SortOption>(
        icon: const Icon(Icons.sort),
        onSelected: (option) {
          setState(() {
            _selectedSort = option;
          });
          if (widget.onSortChanged != null) {
            widget.onSortChanged!(option);
          }
        },
        itemBuilder: (context) {
          return widget.sortOptions.map((option) {
            return PopupMenuItem<SortOption>(
              value: option,
              child: Row(
                children: [
                  if (_selectedSort?.key == option.key)
                    const Icon(Icons.check, size: 18)
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  Text(option.label),
                ],
              ),
            );
          }).toList();
        },
      );
    } else {
      return DropdownButton<SortOption>(
        value: _selectedSort,
        hint: const Text('ترتيب حسب'),
        items: widget.sortOptions.map((option) {
          return DropdownMenuItem<SortOption>(
            value: option,
            child: Text(option.label),
          );
        }).toList(),
        onChanged: (option) {
          if (option != null) {
            setState(() {
              _selectedSort = option;
            });
            if (widget.onSortChanged != null) {
              widget.onSortChanged!(option);
            }
          }
        },
      );
    }
  }
}

class SortOption {
  final String key;
  final String label;
  final bool ascending;

  SortOption({required this.key, required this.label, this.ascending = true});
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SortOption &&
          runtimeType == other.runtimeType &&
          key == other.key &&
          ascending == other.ascending;

  @override
  int get hashCode => key.hashCode ^ ascending.hashCode;
}


