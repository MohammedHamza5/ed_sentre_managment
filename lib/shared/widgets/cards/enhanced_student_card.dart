/// Enhanced Student Card Widget - EdSentre
/// بطاقة طالب محسّنة مع UI مودرن
library;

import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../shared/models/models.dart';

class EnhancedStudentCard extends StatelessWidget {
  final Student student;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const EnhancedStudentCard({
    super.key,
    required this.student,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  // Avatar
                  Hero(
                    tag: 'student_${student.id}',
                    child: CircleAvatar(
                      radius: 30,
                      backgroundImage: student.imageUrl != null
                          ? NetworkImage(student.imageUrl!)
                          : null,
                      backgroundColor: _getStatusColor(student.status).withValues(alpha: 0.1),
                      child: student.imageUrl == null
                          ? Text(
                              _getInitials(student.name),
                              style: GoogleFonts.cairo(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _getStatusColor(student.status),
                              ),
                            )
                          : null,
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Student Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name (without ID)
                        Text(
                          student.name,
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 4),

                        // Grade/Stage
                        if (student.gradeLevel != null && student.gradeLevel!.isNotEmpty)
                          Row(
                            children: [
                              Icon(
                                Icons.school_rounded,
                                size: 14,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                student.gradeLevel!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),

                        const SizedBox(height: 4),

                        // Birth Date (correctly displayed)
                        Row(
                          children: [
                            Icon(
                              Icons.cake_rounded,
                              size: 14,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatBirthDate(student.birthDate),
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(student.status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getStatusColor(student.status).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      _getStatusText(student.status),
                      style: TextStyle(
                        color: _getStatusColor(student.status),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Contact Info Row
              Row(
                children: [
                  // Phone with Copy Button
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.grey.shade800.withValues(alpha: 0.3)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.phone_rounded,
                            size: 16,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 8),
                          // Phone in LTR direction
                          Expanded(
                            child: Directionality(
                              textDirection: ui.TextDirection.ltr,
                              child: Text(
                                _formatPhoneNumber(student.phone),
                                style: GoogleFonts.roboto(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          // Copy Button
                          InkWell(
                            onTap: () => _copyToClipboard(
                              context,
                              student.phone,
                              'تم نسخ رقم الهاتف',
                            ),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.copy_rounded,
                                size: 16,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Subjects Count
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.purple.shade900.withValues(alpha: 0.2)
                          : Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.book_rounded,
                          size: 16,
                          color: Colors.purple.shade700,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${student.subjectIds.length} مواد',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.purple.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Action Buttons
                  if (onEdit != null || onDelete != null) ...[
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      itemBuilder: (context) => [
                        if (onEdit != null)
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_rounded, size: 20),
                                SizedBox(width: 12),
                                Text('تعديل'),
                              ],
                            ),
                          ),
                        if (onDelete != null)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_rounded,
                                  size: 20,
                                  color: Colors.red,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'حذف',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                      ],
                      onSelected: (value) {
                        if (value == 'edit' && onEdit != null) onEdit!();
                        if (value == 'delete' && onDelete != null) onDelete!();
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '؟';
    if (parts.length == 1) return parts[0][0];
    return '${parts[0][0]}${parts[parts.length - 1][0]}';
  }

  String _formatBirthDate(DateTime birthDate) {
    final age = DateTime.now().difference(birthDate).inDays ~/ 365;
    final formatted = DateFormat('yyyy/MM/dd').format(birthDate);
    return '$formatted ($age سنة)';
  }

  String _formatPhoneNumber(String phone) {
    // Remove any non-digit characters
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    
    // Format Egyptian phone numbers: 0XXX XXX XXXX
    if (digits.length == 11 && digits.startsWith('0')) {
      return '${digits.substring(0, 4)} ${digits.substring(4, 7)} ${digits.substring(7)}';
    }
    
    return phone;
  }

  Color _getStatusColor(StudentStatus status) {
    switch (status) {
      case StudentStatus.active:
        return Colors.green;
      case StudentStatus.inactive:
        return Colors.grey;
      case StudentStatus.suspended:
        return Colors.red;
      case StudentStatus.overdue:
        return Colors.orange;
    }
  }

  String _getStatusText(StudentStatus status) {
    switch (status) {
      case StudentStatus.active:
        return 'نشط';
      case StudentStatus.inactive:
        return 'غير نشط';
      case StudentStatus.suspended:
        return 'موقوف';
      case StudentStatus.overdue:
        return 'متأخر';
    }
  }

  void _copyToClipboard(BuildContext context, String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}


