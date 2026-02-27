import 'package:flutter/material.dart';
import '../../../core/l10n/app_strings.dart';

/// Infinite list view with pagination support
/// قائمة لا نهائية مع دعم الترقيم

class InfiniteListView<T> extends StatefulWidget {
  final Future<List<T>> Function(int page, int pageSize) loadData;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final int pageSize;
  final bool enablePullToRefresh;
  final String? emptyMessage;
  final Widget? loadingIndicator;
  final Widget? header;
  final Widget? footer;

  const InfiniteListView({
    super.key,
    required this.loadData,
    required this.itemBuilder,
    this.pageSize = 20,
    this.enablePullToRefresh = true,
    this.emptyMessage,
    this.loadingIndicator,
    this.header,
    this.footer,
  });

  @override
  State<InfiniteListView<T>> createState() => _InfiniteListViewState<T>();
}

class _InfiniteListViewState<T> extends State<InfiniteListView<T>> {
  late ScrollController _scrollController;
  List<T> _items = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_scrollListener);
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      _loadMore();
    }
  }

  Future<void> _loadData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final newItems = await widget.loadData(1, widget.pageSize);
      setState(() {
        _items = newItems;
        _currentPage = 1;
        _hasMore = newItems.length == widget.pageSize;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final newItems = await widget.loadData(nextPage, widget.pageSize);

      setState(() {
        _items.addAll(newItems);
        _currentPage = nextPage;
        _hasMore = newItems.length == widget.pageSize;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty && _isLoading) {
      return Center(
        child: widget.loadingIndicator ?? const CircularProgressIndicator(),
      );
    }

    if (_items.isEmpty && _errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: Text(AppStrings.of(context).retry),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Text(widget.emptyMessage ?? AppStrings.of(context).noData),
      );
    }

    return RefreshIndicator(
      onRefresh: widget.enablePullToRefresh ? _refresh : () async {},
      child: ListView.builder(
        controller: _scrollController,
        itemCount:
            _items.length +
            (_hasMore ? 1 : 0) +
            (widget.header != null ? 1 : 0) +
            (widget.footer != null ? 1 : 0),
        itemBuilder: (context, index) {
          // Handle header
          if (widget.header != null && index == 0) {
            return widget.header!;
          }

          final actualIndex = widget.header != null ? index - 1 : index;

          // Handle loading indicator for more items
          if (_hasMore && actualIndex == _items.length) {
            return Center(
              child:
                  widget.loadingIndicator ?? const CircularProgressIndicator(),
            );
          }

          // Handle footer
          if (widget.footer != null &&
              actualIndex == _items.length + (_hasMore ? 1 : 0)) {
            return widget.footer!;
          }

          // Handle actual items (ensure we don't go out of bounds)
          if (actualIndex < _items.length) {
            return widget.itemBuilder(context, _items[actualIndex]);
          }

          // Fallback (should not happen in normal operation)
          return const SizedBox.shrink();
        },
      ),
    );
  }
}


