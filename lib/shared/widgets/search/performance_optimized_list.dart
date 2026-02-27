import 'package:flutter/material.dart';

/// Performance optimized list for large datasets
/// قائمة محسنة للأداء لمجموعات البيانات الكبيرة

class PerformanceOptimizedList<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final int Function(T item) itemId;
  final bool enableCaching;
  final int cacheSize;
  final Axis scrollDirection;
  final bool reverse;
  final ScrollController? controller;
  final String? emptyMessage;

  const PerformanceOptimizedList({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.itemId,
    this.enableCaching = true,
    this.cacheSize = 50,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.controller,
    this.emptyMessage,
  });

  @override
  State<PerformanceOptimizedList<T>> createState() =>
      _PerformanceOptimizedListState<T>();
}

class _PerformanceOptimizedListState<T>
    extends State<PerformanceOptimizedList<T>> {
  late Map<int, Widget> _widgetCache;
  late Set<int> _visibleItems;

  @override
  void initState() {
    super.initState();
    _widgetCache = <int, Widget>{};
    _visibleItems = <int>{};
  }

  @override
  void didUpdateWidget(covariant PerformanceOptimizedList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Clear cache when items change significantly
    if (oldWidget.items.length != widget.items.length ||
        (oldWidget.items.isNotEmpty &&
            widget.items.isNotEmpty &&
            oldWidget.itemId(oldWidget.items.first) !=
                widget.itemId(widget.items.first))) {
      _widgetCache.clear();
    }
  }

  Widget _buildItem(BuildContext context, int index) {
    if (index >= widget.items.length) return const SizedBox();

    final item = widget.items[index];
    final id = widget.itemId(item);

    // Check cache first
    if (widget.enableCaching && _widgetCache.containsKey(id)) {
      return _widgetCache[id]!;
    }

    // Build new widget
    final widgetItem = widget.itemBuilder(context, item, index);

    // Cache if enabled
    if (widget.enableCaching) {
      _widgetCache[id] = widgetItem;

      // Limit cache size
      if (_widgetCache.length > widget.cacheSize) {
        _widgetCache.remove(_widgetCache.keys.first);
      }
    }

    return widgetItem;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return Center(child: Text(widget.emptyMessage ?? 'لا توجد بيانات'));
    }

    return ListView.builder(
      scrollDirection: widget.scrollDirection,
      reverse: widget.reverse,
      controller: widget.controller,
      itemCount: widget.items.length,
      itemBuilder: (context, index) => _buildItem(context, index),
    );
  }
}


