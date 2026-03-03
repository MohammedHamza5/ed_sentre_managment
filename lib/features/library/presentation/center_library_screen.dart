import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/center_provider.dart';
import 'center_library_provider.dart';
import '../data/center_library_repository.dart';
import 'upload_center_book_screen.dart';

/// شاشة مكتبة مذكرات السنتر
/// Center Library Screen — shows center-specific uploaded books
class CenterLibraryScreen extends StatelessWidget {
  const CenterLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final centerId = context.read<CenterProvider>().centerId;
    if (centerId == null) {
      return const Scaffold(body: Center(child: Text('لا يوجد سنتر مربوط')));
    }

    return ChangeNotifierProvider(
      create: (_) => CenterLibraryProvider(
        repository: CenterLibraryRepository(),
        centerId: centerId,
      )..fetchBooks(),
      child: const _CenterLibraryBody(),
    );
  }
}

class _CenterLibraryBody extends StatelessWidget {
  const _CenterLibraryBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('مكتبة مذكرات السنتر'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload_rounded),
            tooltip: 'رفع مذكرة جديدة',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider.value(
                    value: context.read<CenterLibraryProvider>(),
                    child: const UploadCenterBookScreen(),
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => context.read<CenterLibraryProvider>().fetchBooks(),
          ),
        ],
      ),
      body: Consumer<CenterLibraryProvider>(
        builder: (context, library, _) {
          if (library.isLoading) {
            return Center(
              child: CircularProgressIndicator(color: colorScheme.primary),
            );
          }

          if (library.errorMessage != null) {
            return Center(
              child: Text(
                'خطأ: ${library.errorMessage}',
                style: TextStyle(color: colorScheme.error),
              ),
            );
          }

          if (library.books.isEmpty) {
            return _buildEmptyState(context, colorScheme);
          }

          return RefreshIndicator(
            onRefresh: library.fetchBooks,
            color: colorScheme.primary,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: library.books.length,
              itemBuilder: (context, index) {
                return _BookCard(book: library.books[index]);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_books_rounded,
            size: 80,
            color: colorScheme.onSurface.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 20),
          Text(
            'لا توجد مذكرات بعد',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ارفع مذكراتك لتغذية الذكاء الاصطناعي لدى طلابك',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.3),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider.value(
                    value: context.read<CenterLibraryProvider>(),
                    child: const UploadCenterBookScreen(),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('رفع أول مذكرة'),
          ),
        ],
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  final CenterLibraryBook book;
  const _BookCard({required this.book});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFormat = DateFormat('dd MMM yyyy', 'ar');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Book icon with gradient
            Container(
              width: 48,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _Chip(label: book.subject, color: AppColors.primary),
                      if (book.academicYear != null)
                        _Chip(
                          label: book.academicYear!,
                          color: AppColors.secondary,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 14,
                        color: colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dateFormat.format(book.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                      const Spacer(),
                      book.isProcessed
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.success,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'جاهز',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.warning,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'معالجة...',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.warning,
                                  ),
                                ),
                              ],
                            ),
                    ],
                  ),
                ],
              ),
            ),
            // Delete menu
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                color: colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              onSelected: (value) {
                if (value == 'delete') {
                  _confirmDelete(context, book);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: AppColors.error),
                      SizedBox(width: 8),
                      Text('حذف'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, CenterLibraryBook book) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text(
          'هل تريد حذف "${book.title}"؟ سيتم حذف جميع فهارس الذكاء الاصطناعي المرتبطة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              context.read<CenterLibraryProvider>().deleteBook(book.id);
              Navigator.pop(ctx);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
