import 'package:flutter/material.dart';

/// Unified search bar widget with responsive design
/// مكون شريط البحث الموحد مع تصميم متجاوب

class AppSearchBar extends StatefulWidget {
  final String? hintText;
  final ValueChanged<String>? onSearch;
  final VoidCallback? onClear;
  final double? width;
  final double? height;
  final bool showFilterButton;
  final VoidCallback? onFilterPressed;

  const AppSearchBar({
    super.key,
    this.hintText,
    this.onSearch,
    this.onClear,
    this.width,
    this.height,
    this.showFilterButton = false,
    this.onFilterPressed,
  });

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      _hasText = _controller.text.isNotEmpty;
    });

    // Trigger search with debounce
    if (widget.onSearch != null) {
      widget.onSearch!(_controller.text);
    }
  }

  void _clearText() {
    _controller.clear();
    if (widget.onClear != null) {
      widget.onClear!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      width: widget.width,
      height: widget.height ?? 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: widget.hintText ?? 'بحث...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: widget.onSearch,
            ),
          ),
          if (_hasText)
            IconButton(
              icon: const Icon(Icons.clear, size: 20),
              onPressed: _clearText,
            ),
          if (widget.showFilterButton)
            IconButton(
              icon: const Icon(Icons.filter_list, size: 20),
              onPressed: widget.onFilterPressed,
            ),
          if (!isMobile && widget.showFilterButton)
            const VerticalDivider(indent: 8, endIndent: 8),
          if (!isMobile && widget.showFilterButton)
            TextButton.icon(
              onPressed: widget.onFilterPressed,
              icon: const Icon(Icons.filter_list, size: 16),
              label: const Text('فلترة'),
            ),
        ],
      ),
    );
  }
}


