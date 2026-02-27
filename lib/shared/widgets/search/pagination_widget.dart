import 'package:flutter/material.dart';

/// Pagination widget for handling large datasets
/// مكون ترقيم الصفحات للتعامل مع مجموعات البيانات الكبيرة

class PaginationWidget extends StatefulWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;
  final int itemsPerPage;
  final int totalItems;
  final bool showPageSizeSelector;
  final List<int> pageSizes;

  const PaginationWidget({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
    this.itemsPerPage = 10,
    required this.totalItems,
    this.showPageSizeSelector = true,
    this.pageSizes = const [10, 20, 50, 100],
  });

  @override
  State<PaginationWidget> createState() => _PaginationWidgetState();
}

class _PaginationWidgetState extends State<PaginationWidget> {
  late int _itemsPerPage;

  @override
  void initState() {
    super.initState();
    _itemsPerPage = widget.itemsPerPage;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (widget.showPageSizeSelector && !isMobile)
            _buildPageSizeSelector(),
          const SizedBox(height: 8),
          _buildPaginationControls(isMobile),
          const SizedBox(height: 8),
          _buildPageInfo(),
        ],
      ),
    );
  }

  Widget _buildPageSizeSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const Text('عرض:'),
        const SizedBox(width: 8),
        DropdownButton<int>(
          value: _itemsPerPage,
          items: widget.pageSizes.map((size) {
            return DropdownMenuItem(value: size, child: Text('$size'));
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _itemsPerPage = value;
              });
              // Reset to first page when changing page size
              widget.onPageChanged(1);
            }
          },
        ),
        const Text(' عنصر في الصفحة'),
      ],
    );
  }

  Widget _buildPaginationControls(bool isMobile) {
    if (isMobile) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: widget.currentPage > 1
                ? () => widget.onPageChanged(widget.currentPage - 1)
                : null,
          ),
          Text('${widget.currentPage} من ${widget.totalPages}'),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: widget.currentPage < widget.totalPages
                ? () => widget.onPageChanged(widget.currentPage + 1)
                : null,
          ),
        ],
      );
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.first_page),
            onPressed: widget.currentPage > 1
                ? () => widget.onPageChanged(1)
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: widget.currentPage > 1
                ? () => widget.onPageChanged(widget.currentPage - 1)
                : null,
          ),
          ..._buildPageNumbers(),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: widget.currentPage < widget.totalPages
                ? () => widget.onPageChanged(widget.currentPage + 1)
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.last_page),
            onPressed: widget.currentPage < widget.totalPages
                ? () => widget.onPageChanged(widget.totalPages)
                : null,
          ),
        ],
      );
    }
  }

  List<Widget> _buildPageNumbers() {
    List<Widget> pages = [];
    int startPage, endPage;

    if (widget.totalPages <= 7) {
      // Show all pages
      startPage = 1;
      endPage = widget.totalPages;
    } else {
      // Show sliding window of 7 pages
      if (widget.currentPage <= 4) {
        startPage = 1;
        endPage = 7;
      } else if (widget.currentPage >= widget.totalPages - 3) {
        startPage = widget.totalPages - 6;
        endPage = widget.totalPages;
      } else {
        startPage = widget.currentPage - 3;
        endPage = widget.currentPage + 3;
      }
    }

    // Add first page and ellipsis if needed
    if (startPage > 1) {
      pages.add(_buildPageNumber(1));
      if (startPage > 2) {
        pages.add(const Text('...'));
      }
    }

    // Add page numbers in range
    for (int i = startPage; i <= endPage; i++) {
      pages.add(_buildPageNumber(i));
    }

    // Add last page and ellipsis if needed
    if (endPage < widget.totalPages) {
      if (endPage < widget.totalPages - 1) {
        pages.add(const Text('...'));
      }
      pages.add(_buildPageNumber(widget.totalPages));
    }

    return pages;
  }

  Widget _buildPageNumber(int pageNumber) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: widget.currentPage == pageNumber
                ? Theme.of(context).primaryColor
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '$pageNumber',
            style: TextStyle(
              color: widget.currentPage == pageNumber
                  ? Colors.white
                  : Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ),
        onPressed: () => widget.onPageChanged(pageNumber),
      ),
    );
  }

  Widget _buildPageInfo() {
    final startItem = (widget.currentPage - 1) * _itemsPerPage + 1;
    final endItem = (widget.currentPage * _itemsPerPage).clamp(
      0,
      widget.totalItems,
    );

    return Text(
      'عرض $startItem إلى $endItem من أصل ${widget.totalItems} عنصر',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}


