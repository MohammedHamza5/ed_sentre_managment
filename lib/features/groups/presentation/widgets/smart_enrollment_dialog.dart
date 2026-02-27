/// Smart Enrollment Dialog - EdSentre
/// نافذة تسجيل ذكية للطلاب في المجموعات - تصميم مبسط ✨
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../../shared/models/models.dart';
import '../../models/smart_enrollment_models.dart';
import '../../data/repositories/groups_repository.dart';

class SmartEnrollmentDialog extends StatefulWidget {
  final Group group;
  final VoidCallback? onEnrollmentComplete;

  const SmartEnrollmentDialog({
    super.key,
    required this.group,
    this.onEnrollmentComplete,
  });

  @override
  State<SmartEnrollmentDialog> createState() => _SmartEnrollmentDialogState();
}

class _SmartEnrollmentDialogState extends State<SmartEnrollmentDialog> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedStudentIds = {};

  List<SmartStudentOption> _allStudents = [];
  List<SmartStudentOption> _filteredStudents = [];
  bool _isLoading = true;
  bool _isEnrolling = false;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);

    try {
      final repository = context.read<GroupsRepository>();
      // 📌 دائماً نستخدم sameCourse للتأكد من إظهار طلاب المادة فقط
      final students = await repository.getAvailableStudentsForGroup(
        groupId: widget.group.id,
        filterType: StudentFilterType.sameCourse,
        searchQuery: _searchController.text,
      );

      if (mounted) {
        setState(() {
          _allStudents = students;
          _filteredStudents = students;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تحميل الطلاب: $e')),
        );
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredStudents = _allStudents;
      } else {
        _filteredStudents = _allStudents.where((s) {
          return s.name.toLowerCase().contains(query.toLowerCase()) ||
              (s.phone?.contains(query) ?? false);
        }).toList();
      }
    });
  }

  void _toggleSelection(String studentId) {
    setState(() {
      if (_selectedStudentIds.contains(studentId)) {
        _selectedStudentIds.remove(studentId);
      } else {
        _selectedStudentIds.add(studentId);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedStudentIds.addAll(
        _filteredStudents.where((s) => !s.hasConflict).map((s) => s.id),
      );
    });
  }

  void _clearSelection() {
    setState(() => _selectedStudentIds.clear());
  }

  Future<void> _enrollSelected() async {
    if (_selectedStudentIds.isEmpty) return;

    setState(() => _isEnrolling = true);

    try {
      final repository = context.read<GroupsRepository>();
      final result = await repository.bulkEnrollStudents(
        groupId: widget.group.id,
        studentIds: _selectedStudentIds.toList(),
      );

      if (!mounted) return;

      // Show result
      _showResultSnackbar(result);

      if (result.successCount > 0) {
        widget.onEnrollmentComplete?.call();
        if (result.isFullSuccess) {
          Navigator.pop(context);
        } else {
          _selectedStudentIds.clear();
          _loadStudents();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isEnrolling = false);
    }
  }

  void _showResultSnackbar(SmartEnrollmentResult result) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              result.isFullSuccess ? Icons.check_circle : Icons.info,
              color: Colors.white,
            ),
            SizedBox(width: 8.w),
            Text(
              result.isFullSuccess
                  ? 'تم تسجيل ${result.successCount} طالب بنجاح! ✅'
                  : 'تم تسجيل ${result.successCount} من ${result.totalAttempted}',
              style: GoogleFonts.cairo(),
            ),
          ],
        ),
        backgroundColor: result.isFullSuccess ? Colors.green : Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final availableSlots = widget.group.maxStudents - widget.group.currentStudents;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 40.h),
      child: Container(
        width: 500.w,
        constraints: BoxConstraints(maxHeight: 600.h),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1F2E) : Colors.white,
          borderRadius: BorderRadius.circular(24.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ═══════════════════════════════════════════════════════════
            // HEADER
            // ═══════════════════════════════════════════════════════════
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF667EEA), const Color(0xFF764BA2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Close Button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                          tooltip: 'إغلاق',
                        ),
                      ),
                      SizedBox(width: 12.w),
                      
                      // Title
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'إضافة طلاب 📚',
                              style: GoogleFonts.cairo(
                                fontSize: 20.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              widget.group.groupName,
                              style: GoogleFonts.cairo(
                                fontSize: 14.sp,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Available Slots Badge
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          color: availableSlots > 0 
                              ? Colors.green.withValues(alpha: 0.3)
                              : Colors.red.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(color: Colors.white30),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.event_seat, size: 18.sp, color: Colors.white),
                            SizedBox(width: 6.w),
                            Text(
                              '$availableSlots متاح',
                              style: GoogleFonts.cairo(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  // Info Chips Row
                  SizedBox(height: 16.h),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        if (widget.group.courseName != null)
                          _buildHeaderChip(Icons.book, widget.group.courseName!),
                        if (widget.group.gradeLevel != null) ...[
                          SizedBox(width: 8.w),
                          _buildHeaderChip(Icons.school, _shortenGrade(widget.group.gradeLevel!)),
                        ],
                        if (widget.group.scheduleText.isNotEmpty) ...[
                          SizedBox(width: 8.w),
                          _buildHeaderChip(Icons.schedule, widget.group.scheduleText),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ═══════════════════════════════════════════════════════════
            // SEARCH BAR
            // ═══════════════════════════════════════════════════════════
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: '🔍 بحث بالاسم أو رقم الهاتف...',
                    hintStyle: GoogleFonts.cairo(
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                  ),
                ),
              ),
            ),

            // ═══════════════════════════════════════════════════════════
            // STUDENTS LIST
            // ═══════════════════════════════════════════════════════════
            Expanded(
              child: _buildStudentsList(isDark),
            ),

            // ═══════════════════════════════════════════════════════════
            // BOTTOM ACTIONS
            // ═══════════════════════════════════════════════════════════
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161B22) : Colors.grey.shade50,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24.r)),
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Selected Count
                  if (_selectedStudentIds.isNotEmpty)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFF667EEA).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Text(
                        '${_selectedStudentIds.length} محدد',
                        style: GoogleFonts.cairo(
                          color: const Color(0xFF667EEA),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  
                  const Spacer(),
                  
                  // Cancel Button
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'إلغاء',
                      style: GoogleFonts.cairo(
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  
                  // Enroll Button
                  FilledButton.icon(
                    onPressed: _selectedStudentIds.isEmpty || _isEnrolling
                        ? null
                        : _enrollSelected,
                    icon: _isEnrolling
                        ? SizedBox(
                            width: 18.w,
                            height: 18.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.person_add_rounded),
                    label: Text(
                      _isEnrolling ? 'جاري التسجيل...' : 'تسجيل الطلاب',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF667EEA),
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderChip(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: Colors.white70),
          SizedBox(width: 6.w),
          Text(
            label,
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontSize: 12.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsList(bool isDark) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: const Color(0xFF667EEA),
            ),
            SizedBox(height: 16.h),
            Text(
              'جاري تحميل طلاب المادة...',
              style: GoogleFonts.cairo(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    if (_filteredStudents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search_rounded,
              size: 60.sp,
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
            SizedBox(height: 16.h),
            Text(
              _searchController.text.isNotEmpty
                  ? 'لا يوجد طلاب بهذا البحث'
                  : 'لا يوجد طلاب مسجلين في هذه المادة',
              style: GoogleFonts.cairo(
                fontSize: 16.sp,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),
            Text(
              'تأكد من تسجيل الطلاب في المادة أولاً',
              style: GoogleFonts.cairo(
                fontSize: 13.sp,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Selection Bar
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Row(
            children: [
              Text(
                '${_filteredStudents.length} طالب مسجل بالمادة',
                style: GoogleFonts.cairo(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontSize: 13.sp,
                ),
              ),
              const Spacer(),
              if (_selectedStudentIds.length < _filteredStudents.where((s) => !s.hasConflict).length)
                TextButton.icon(
                  onPressed: _selectAll,
                  icon: Icon(Icons.select_all, size: 18.sp),
                  label: Text('تحديد الكل', style: GoogleFonts.cairo(fontSize: 12.sp)),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                  ),
                ),
              if (_selectedStudentIds.isNotEmpty)
                TextButton.icon(
                  onPressed: _clearSelection,
                  icon: Icon(Icons.deselect, size: 18.sp),
                  label: Text('إلغاء', style: GoogleFonts.cairo(fontSize: 12.sp)),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                  ),
                ),
            ],
          ),
        ),
        
        SizedBox(height: 8.h),
        
        // Students List
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            itemCount: _filteredStudents.length,
            itemBuilder: (context, index) {
              final student = _filteredStudents[index];
              return _buildStudentCard(student, isDark);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStudentCard(SmartStudentOption student, bool isDark) {
    final isSelected = _selectedStudentIds.contains(student.id);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF667EEA).withValues(alpha: isDark ? 0.2 : 0.1)
            : (isDark ? const Color(0xFF1E2330) : Colors.white),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF667EEA)
              : student.hasConflict
                  ? Colors.orange.shade300
                  : (isDark ? Colors.grey.shade700 : Colors.grey.shade200),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: const Color(0xFF667EEA).withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: InkWell(
        onTap: student.hasConflict ? null : () => _toggleSelection(student.id),
        borderRadius: BorderRadius.circular(16.r),
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: Row(
            children: [
              // Checkbox or Conflict Icon
              if (student.hasConflict)
                Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.warning_rounded, color: Colors.orange, size: 22.sp),
                )
              else
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => _toggleSelection(student.id),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  activeColor: const Color(0xFF667EEA),
                ),

              SizedBox(width: 12.w),

              // Avatar
              CircleAvatar(
                radius: 22.r,
                backgroundColor: student.avatarColor.withValues(alpha: 0.15),
                child: Text(
                  student.initials,
                  style: TextStyle(
                    color: student.avatarColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp,
                  ),
                ),
              ),

              SizedBox(width: 12.w),

              // Student Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      style: GoogleFonts.cairo(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (student.phone != null && student.phone!.isNotEmpty)
                      Text(
                        student.phone!,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),

              // Groups Count Badge
              if (student.currentGroupsCount > 0)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.groups_rounded,
                        size: 14.sp,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        '${student.currentGroupsCount}',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _shortenGrade(String grade) {
    if (grade.contains('الأول')) return '1 ثانوي';
    if (grade.contains('الثاني')) return '2 ثانوي';
    if (grade.contains('الثالث')) return '3 ثانوي';
    return grade;
  }
}
