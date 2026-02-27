/// Groups Management Screen - EdSentre
/// شاشة إدارة المجموعات - تصميم مبهر ✨
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/center_provider.dart';
import '../../../shared/models/models.dart';
import '../data/repositories/groups_repository.dart';
import '../../subjects/data/repositories/subjects_repository.dart';
import 'add_edit_group_dialog.dart';
import 'group_details_screen.dart';
import '../../attendance/presentation/screens/qr_attendance_screen.dart';
import '../../attendance/presentation/screens/universal_qr_screen.dart';

class GroupsManagementScreen extends StatefulWidget {
  const GroupsManagementScreen({super.key});

  @override
  State<GroupsManagementScreen> createState() => _GroupsManagementScreenState();
}

class _GroupsManagementScreenState extends State<GroupsManagementScreen>
    with SingleTickerProviderStateMixin {
  List<Group> _groups = [];
  bool _isLoading = false;

  // Filters
  String? _selectedCourse;
  GroupStatus? _selectedStatus;
  String? _selectedGrade;
  String _searchQuery = '';

  // Animation
  AnimationController? _animationController;

  bool get _isAnimationReady => _animationController != null;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadCourses();
    _loadGroups();
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  Future<void> _loadGroups({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final repository = context.read<GroupsRepository>();
      final groups = await repository.getGroups(
        forceRefresh: forceRefresh,
        courseId: _selectedCourse,
        status: _selectedStatus,
        gradeLevel: _selectedGrade,
      );

      if (mounted) {
        setState(() {
          _groups = groups;
          _isLoading = false;
        });
        _animationController?.forward(from: 0);
      }
    } catch (e) {
      debugPrint('Error loading groups: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Load courses for filter
  List<Map<String, dynamic>> _courses = [];
  Future<void> _loadCourses() async {
    if (!mounted) return;
    try {
      final repository = context.read<SubjectsRepository>();
      final subjects = await repository.getSubjects();
      if (mounted) {
        setState(
          () => _courses = subjects
              .map((s) => {'id': s.id, 'name': s.name})
              .toList(),
        );
      }
    } catch (_) {}
  }

  void _showAddGroupDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const AddEditGroupDialog(),
    );

    if (result == true) {
      _loadGroups(forceRefresh: true);
      if (mounted) context.read<CenterProvider>().refreshCounts();
    }
  }

  List<Group> get _filteredGroups {
    if (_searchQuery.isEmpty) return _groups;
    return _groups.where((g) {
      final query = _searchQuery.toLowerCase();
      return g.groupName.toLowerCase().contains(query) ||
          (g.teacherName?.toLowerCase().contains(query) ?? false) ||
          (g.courseName?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final filteredGroups = _filteredGroups;

    // Stats
    final total = _groups.length;
    final active = _groups.where((g) => g.status == GroupStatus.active).length;
    final full = _groups.where((g) => g.status == GroupStatus.full).length;
    final totalStudents = _groups.fold<int>(
      0,
      (sum, g) => sum + g.currentStudents,
    );

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0D1117)
          : const Color(0xFFF5F7FA),
      body: RefreshIndicator(
        onRefresh: () => _loadGroups(forceRefresh: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ═══════════════════════════════════════════════════════════
            // STUNNING HEADER
            // ═══════════════════════════════════════════════════════════
            SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [const Color(0xFF1E3A5F), const Color(0xFF0D1117)]
                        : [const Color(0xFF667EEA), const Color(0xFF764BA2)],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsets.all(20.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title Row
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(12.w),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                              child: Icon(
                                Icons.groups_rounded,
                                color: Colors.white,
                                size: 28.sp,
                              ),
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'إدارة المجموعات',
                                    style: GoogleFonts.cairo(
                                      fontSize: 24.sp,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    'تنظيم وإدارة مجموعاتك بسهولة',
                                    style: GoogleFonts.cairo(
                                      fontSize: 14.sp,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Universal QR Button
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const UniversalQrScreen(),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(16.r),
                                  child: Padding(
                                    padding: EdgeInsets.all(12.w),
                                    child: Icon(
                                      Icons.qr_code_scanner_rounded,
                                      color: Colors.white,
                                      size: 24.sp,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 12.w),

                            // Add Button
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _showAddGroupDialog,
                                  borderRadius: BorderRadius.circular(16.r),
                                  child: Padding(
                                    padding: EdgeInsets.all(12.w),
                                    child: Icon(
                                      Icons.add_rounded,
                                      color: isDark
                                          ? const Color(0xFF667EEA)
                                          : const Color(0xFF764BA2),
                                      size: 24.sp,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 24.h),

                        // Stats Cards
                        Row(
                          children: [
                            _buildMiniStatCard(
                              value: '$total',
                              label: 'إجمالي',
                              icon: Icons.folder_rounded,
                            ),
                            SizedBox(width: 12.w),
                            _buildMiniStatCard(
                              value: '$active',
                              label: 'نشطة',
                              icon: Icons.check_circle_rounded,
                              color: Colors.greenAccent,
                            ),
                            SizedBox(width: 12.w),
                            _buildMiniStatCard(
                              value: '$full',
                              label: 'ممتلئة',
                              icon: Icons.warning_rounded,
                              color: Colors.orangeAccent,
                            ),
                            SizedBox(width: 12.w),
                            _buildMiniStatCard(
                              value: '$totalStudents',
                              label: 'طالب',
                              icon: Icons.school_rounded,
                              color: Colors.cyanAccent,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ═══════════════════════════════════════════════════════════
            // 🧠 SMART AI INSIGHTS
            // ═══════════════════════════════════════════════════════════
            if (_groups.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: _buildSmartInsights(),
                ),
              ),

            // ═══════════════════════════════════════════════════════════
            // SEARCH & FILTERS
            // ═══════════════════════════════════════════════════════════
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  children: [
                    // Search Bar
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF161B22) : Colors.white,
                        borderRadius: BorderRadius.circular(16.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: '🔍 ابحث عن مجموعة، معلم، أو مادة...',
                          hintStyle: TextStyle(
                            color: isDark
                                ? Colors.grey.shade600
                                : Colors.grey.shade400,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: isDark
                                ? Colors.grey.shade500
                                : Colors.grey.shade400,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded),
                                  onPressed: () {
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 16.h,
                          ),
                        ),
                        onChanged: (value) =>
                            setState(() => _searchQuery = value),
                      ),
                    ),

                    SizedBox(height: 16.h),

                    // Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // All
                          _buildFilterChip(
                            label: 'الكل',
                            isSelected:
                                _selectedStatus == null &&
                                _selectedGrade == null &&
                                _selectedCourse == null,
                            onTap: () {
                              setState(() {
                                _selectedStatus = null;
                                _selectedGrade = null;
                                _selectedCourse = null;
                              });
                              _loadGroups();
                            },
                          ),
                          SizedBox(width: 8.w),

                          // Active
                          _buildFilterChip(
                            label: '✅ نشطة',
                            isSelected: _selectedStatus == GroupStatus.active,
                            color: Colors.green,
                            onTap: () {
                              setState(
                                () => _selectedStatus =
                                    _selectedStatus == GroupStatus.active
                                    ? null
                                    : GroupStatus.active,
                              );
                              _loadGroups();
                            },
                          ),
                          SizedBox(width: 8.w),

                          // Full
                          _buildFilterChip(
                            label: '🔴 ممتلئة',
                            isSelected: _selectedStatus == GroupStatus.full,
                            color: Colors.orange,
                            onTap: () {
                              setState(
                                () => _selectedStatus =
                                    _selectedStatus == GroupStatus.full
                                    ? null
                                    : GroupStatus.full,
                              );
                              _loadGroups();
                            },
                          ),
                          SizedBox(width: 8.w),

                          // Grades
                          _buildFilterChip(
                            label: '1️⃣ أولى ثانوي',
                            isSelected: _selectedGrade == 'الصف الأول الثانوي',
                            color: Colors.blue,
                            onTap: () {
                              setState(
                                () => _selectedGrade =
                                    _selectedGrade == 'الصف الأول الثانوي'
                                    ? null
                                    : 'الصف الأول الثانوي',
                              );
                              _loadGroups();
                            },
                          ),
                          SizedBox(width: 8.w),
                          _buildFilterChip(
                            label: '2️⃣ ثانية ثانوي',
                            isSelected: _selectedGrade == 'الصف الثاني الثانوي',
                            color: Colors.purple,
                            onTap: () {
                              setState(
                                () => _selectedGrade =
                                    _selectedGrade == 'الصف الثاني الثانوي'
                                    ? null
                                    : 'الصف الثاني الثانوي',
                              );
                              _loadGroups();
                            },
                          ),
                          SizedBox(width: 8.w),
                          _buildFilterChip(
                            label: '3️⃣ ثالثة ثانوي',
                            isSelected: _selectedGrade == 'الصف الثالث الثانوي',
                            color: Colors.teal,
                            onTap: () {
                              setState(
                                () => _selectedGrade =
                                    _selectedGrade == 'الصف الثالث الثانوي'
                                    ? null
                                    : 'الصف الثالث الثانوي',
                              );
                              _loadGroups();
                            },
                          ),
                        ],
                      ),
                    ),

                    // Course Filter (if courses exist)
                    if (_courses.isNotEmpty) ...[
                      SizedBox(height: 12.h),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _courses
                              .map(
                                (c) => Padding(
                                  padding: EdgeInsets.only(left: 8.w),
                                  child: _buildFilterChip(
                                    label: '📚 ${c['name']}',
                                    isSelected: _selectedCourse == c['id'],
                                    color: Colors.indigo,
                                    onTap: () {
                                      setState(
                                        () => _selectedCourse =
                                            _selectedCourse == c['id']
                                            ? null
                                            : c['id'],
                                      );
                                      _loadGroups();
                                    },
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ═══════════════════════════════════════════════════════════
            // GROUPS LIST
            // ═══════════════════════════════════════════════════════════
            if (_isLoading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(60.w),
                  child: Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF667EEA),
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          'جاري التحميل...',
                          style: GoogleFonts.cairo(
                            color: isDark
                                ? Colors.white54
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (filteredGroups.isEmpty)
              SliverToBoxAdapter(child: _buildEmptyState())
            else
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final group = filteredGroups[index];
                    final controller = _animationController;
                    if (controller == null) {
                      return _buildGroupCard(group);
                    }
                    return AnimatedBuilder(
                      animation: controller,
                      builder: (context, child) {
                        final delay = index * 0.1;
                        final animation = CurvedAnimation(
                          parent: controller,
                          curve: Interval(
                            delay.clamp(0.0, 1.0),
                            (delay + 0.3).clamp(0.0, 1.0),
                            curve: Curves.easeOutBack,
                          ),
                        );
                        return Transform.translate(
                          offset: Offset(0, 30 * (1 - animation.value)),
                          child: Opacity(
                            opacity: animation.value.clamp(0.0, 1.0),
                            child: child,
                          ),
                        );
                      },
                      child: _buildGroupCard(group),
                    );
                  }, childCount: filteredGroups.length),
                ),
              ),

            // Bottom Padding
            SliverToBoxAdapter(child: SizedBox(height: 100.h)),
          ],
        ),
      ),

      // ═══════════════════════════════════════════════════════════
      // FLOATING ACTION BUTTON
      // ═══════════════════════════════════════════════════════════
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddGroupDialog,
        backgroundColor: isDark
            ? const Color(0xFF667EEA)
            : const Color(0xFF764BA2),
        elevation: 8,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'مجموعة جديدة',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WIDGETS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMiniStatCard({
    required String value,
    required String label,
    required IconData icon,
    Color? color,
  }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color ?? Colors.white, size: 20.sp),
            SizedBox(height: 4.h),
            Text(
              value,
              style: GoogleFonts.cairo(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.cairo(fontSize: 11.sp, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final chipColor =
        color ?? (isDark ? Colors.white : const Color(0xFF667EEA));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: isSelected
                ? chipColor.withValues(alpha: 0.2)
                : (isDark ? const Color(0xFF161B22) : Colors.white),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: isSelected
                  ? chipColor
                  : Colors.grey.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: chipColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 13.sp,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? chipColor
                  : (isDark ? Colors.white70 : Colors.grey.shade700),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupCard(Group group) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Status colors
    Color statusColor;
    String statusText;
    IconData statusIcon;
    switch (group.status) {
      case GroupStatus.active:
        statusColor = Colors.green;
        statusText = 'نشطة';
        statusIcon = Icons.check_circle_rounded;
        break;
      case GroupStatus.full:
        statusColor = Colors.orange;
        statusText = 'ممتلئة';
        statusIcon = Icons.warning_rounded;
        break;
      case GroupStatus.suspended:
        statusColor = Colors.red;
        statusText = 'موقوفة';
        statusIcon = Icons.pause_circle_rounded;
        break;
      case GroupStatus.archived:
        statusColor = Colors.grey;
        statusText = 'مؤرشفة';
        statusIcon = Icons.archive_rounded;
        break;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showGroupDetails(group),
          borderRadius: BorderRadius.circular(20.r),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              children: [
                // Header Row
                Row(
                  children: [
                    // Group Avatar
                    Container(
                      width: 56.w,
                      height: 56.w,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            statusColor.withValues(alpha: 0.8),
                            statusColor,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16.r),
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.groups_rounded,
                        color: Colors.white,
                        size: 28.sp,
                      ),
                    ),

                    SizedBox(width: 16.w),

                    // Group Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.groupName,
                            style: GoogleFonts.cairo(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4.h),
                          Row(
                            children: [
                              if (group.courseName != null) ...[
                                Icon(
                                  Icons.book_rounded,
                                  size: 14.sp,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                ),
                                SizedBox(width: 4.w),
                                Flexible(
                                  child: Text(
                                    group.courseName!,
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      color: isDark
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Status Badge
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 14.sp, color: statusColor),
                          SizedBox(width: 4.w),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // More Menu
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'attendance',
                          child: Row(
                            children: [
                              Icon(
                                Icons.qr_code_2_rounded,
                                size: 20,
                                color: Colors.green,
                              ),
                              SizedBox(width: 12),
                              Text('تسجيل الحضور'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit_rounded,
                                size: 20,
                                color: Colors.blue,
                              ),
                              SizedBox(width: 12),
                              Text('تعديل'),
                            ],
                          ),
                        ),
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
                              Text('حذف', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'attendance') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => QRAttendanceScreen(
                                groupId: group.id,
                                groupName: group.groupName,
                              ),
                            ),
                          );
                        } else if (value == 'edit') {
                          _showEditGroupDialog(group);
                        } else if (value == 'delete') {
                          _confirmDeleteGroup(group);
                        }
                      },
                    ),
                  ],
                ),

                SizedBox(height: 16.h),

                // Info Chips Row
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: [
                    // Grade
                    if (group.gradeLevel != null)
                      _buildInfoChip(
                        icon: Icons.school_rounded,
                        label: _shortenGrade(group.gradeLevel!),
                        color: Colors.teal,
                        isDark: isDark,
                      ),

                    // Students Count
                    _buildInfoChip(
                      icon: Icons.people_rounded,
                      label: '${group.currentStudents}/${group.maxStudents}',
                      color: Colors.blue,
                      isDark: isDark,
                    ),

                    // Teacher
                    if (group.teacherName != null)
                      _buildInfoChip(
                        icon: Icons.person_rounded,
                        label: group.teacherName!,
                        color: Colors.purple,
                        isDark: isDark,
                      ),

                    // Schedule
                    if (group.scheduleText.isNotEmpty &&
                        group.scheduleText != 'غير محدد')
                      _buildInfoChip(
                        icon: Icons.schedule_rounded,
                        label: group.scheduleText,
                        color: Colors.green,
                        isDark: isDark,
                      ),

                    // Fee
                    if (group.monthlyFee != null && group.monthlyFee! > 0)
                      _buildInfoChip(
                        icon: Icons.payments_rounded,
                        label: '${group.monthlyFee!.toInt()} ج',
                        color: Colors.orange,
                        isDark: isDark,
                      ),
                  ],
                ),

                // Occupancy Progress
                if (group.maxStudents > 0) ...[
                  SizedBox(height: 16.h),
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'نسبة الإشغال',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: isDark
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            '${group.occupancyRate.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: group.isFull ? Colors.red : Colors.green,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4.r),
                        child: LinearProgressIndicator(
                          value: group.occupancyRate / 100,
                          backgroundColor: isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation(
                            group.isFull ? Colors.red : Colors.green,
                          ),
                          minHeight: 8.h,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: color),
          SizedBox(width: 6.w),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.all(32.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(32.w),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.grey.shade800.withValues(alpha: 0.5)
                  : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.groups_outlined,
              size: 80.sp,
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            'لا توجد مجموعات بعد',
            style: GoogleFonts.cairo(
              fontSize: 22.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'ابدأ بإنشاء أول مجموعة لتنظيم طلابك',
            style: GoogleFonts.cairo(
              fontSize: 14.sp,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 32.h),
          FilledButton.icon(
            onPressed: _showAddGroupDialog,
            style: FilledButton.styleFrom(
              backgroundColor: isDark
                  ? const Color(0xFF667EEA)
                  : const Color(0xFF764BA2),
              padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 16.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
            ),
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: Text(
              'إنشاء مجموعة جديدة',
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _shortenGrade(String grade) {
    if (grade.contains('الأول')) return '1 ثانوي';
    if (grade.contains('الثاني')) return '2 ثانوي';
    if (grade.contains('الثالث')) return '3 ثانوي';
    return grade;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  void _showGroupDetails(Group group) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => GroupDetailsScreen(group: group)),
    ).then((_) => _loadGroups());
  }

  void _showEditGroupDialog(Group group) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AddEditGroupDialog(group: group),
    );
    if (result == true) {
      _loadGroups(forceRefresh: true);
    }
  }

  void _confirmDeleteGroup(Group group) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final repository = context.read<GroupsRepository>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: const Icon(Icons.warning_rounded, color: Colors.red),
            ),
            SizedBox(width: 12.w),
            Text(
              'تأكيد الحذف',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'هل أنت متأكد من حذف مجموعة "${group.groupName}"؟\n\nسيتم حذف جميع البيانات المرتبطة بها.',
          style: GoogleFonts.cairo(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'إلغاء',
              style: GoogleFonts.cairo(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await repository.deleteGroup(group.id);
                _loadGroups(forceRefresh: true);
                if (mounted) context.read<CenterProvider>().refreshCounts();
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: 8.w),
                          Text(
                            'تم حذف المجموعة بنجاح',
                            style: GoogleFonts.cairo(),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('خطأ: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text(
              'حذف',
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🧠 SMART AI INSIGHTS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSmartInsights() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 🧠 AI Analysis
    final insights = _analyzeGroups();

    if (insights.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1A1F35), const Color(0xFF0D1117)]
              : [const Color(0xFFFFF3E0), Colors.white],
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isDark
              ? Colors.amber.withValues(alpha: 0.3)
              : Colors.orange.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFB347), Color(0xFFFFCC33)],
                    ),
                    borderRadius: BorderRadius.circular(12.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.psychology_rounded,
                    color: Colors.white,
                    size: 24.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'رؤى ذكية 🧠',
                        style: GoogleFonts.cairo(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        'تحليل ذكي لمجموعاتك',
                        style: GoogleFonts.cairo(
                          fontSize: 12.sp,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                // AI Badge
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                    ),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 14.sp,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        'AI',
                        style: GoogleFonts.cairo(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Insights List
          ...insights.map((insight) => _buildInsightItem(insight, isDark)),

          SizedBox(height: 8.h),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _analyzeGroups() {
    final List<Map<String, dynamic>> insights = [];

    // 1. 🔴 المجموعات الممتلئة - تحتاج مجموعة جديدة
    final fullGroups = _groups
        .where((g) => g.status == GroupStatus.full || g.occupancyRate >= 90)
        .toList();
    if (fullGroups.isNotEmpty) {
      insights.add({
        'type': 'warning',
        'icon': Icons.group_add_rounded,
        'title': '${fullGroups.length} مجموعة ممتلئة',
        'message': 'قد تحتاج لإنشاء مجموعات جديدة لاستيعاب المزيد من الطلاب',
        'action': 'إضافة مجموعة',
        'actionCallback': _showAddGroupDialog,
        'color': Colors.orange,
      });
    }

    // 2. 🟢 المجموعات ذات الأداء الممتاز
    final excellentGroups = _groups
        .where(
          (g) =>
              g.occupancyRate >= 70 &&
              g.occupancyRate < 90 &&
              g.status == GroupStatus.active,
        )
        .toList();
    if (excellentGroups.isNotEmpty) {
      final bestGroup = excellentGroups.reduce(
        (a, b) => a.occupancyRate > b.occupancyRate ? a : b,
      );
      insights.add({
        'type': 'success',
        'icon': Icons.emoji_events_rounded,
        'title': 'أفضل مجموعة: ${bestGroup.groupName}',
        'message':
            'نسبة إشغال ${bestGroup.occupancyRate.toInt()}% - أداء ممتاز!',
        'action': 'عرض التفاصيل',
        'actionCallback': () => _showGroupDetails(bestGroup),
        'color': Colors.green,
      });
    }

    // 3. 🔵 مجموعات تحتاج طلاب
    final lowOccupancy = _groups
        .where(
          (g) =>
              g.occupancyRate < 30 &&
              g.maxStudents > 0 &&
              g.status == GroupStatus.active,
        )
        .toList();
    if (lowOccupancy.isNotEmpty) {
      insights.add({
        'type': 'info',
        'icon': Icons.person_add_alt_1_rounded,
        'title': '${lowOccupancy.length} مجموعة تحتاج طلاب',
        'message': 'يمكنك تسجيل طلاب جدد في هذه المجموعات',
        'action': 'عرض المجموعات',
        'actionCallback': () {
          setState(() => _selectedStatus = GroupStatus.active);
          _loadGroups();
        },
        'color': Colors.blue,
      });
    }

    // 4. 📊 توزيع المراحل
    final gradeDistribution = <String, int>{};
    for (final g in _groups) {
      if (g.gradeLevel != null) {
        gradeDistribution[g.gradeLevel!] =
            (gradeDistribution[g.gradeLevel!] ?? 0) + 1;
      }
    }
    if (gradeDistribution.isNotEmpty) {
      final dominant = gradeDistribution.entries.reduce(
        (a, b) => a.value > b.value ? a : b,
      );
      final shortGrade = _shortenGrade(dominant.key);
      insights.add({
        'type': 'stat',
        'icon': Icons.pie_chart_rounded,
        'title': 'أكثر المراحل: $shortGrade',
        'message': '${dominant.value} مجموعة من إجمالي ${_groups.length}',
        'color': Colors.purple,
      });
    }

    // 5. 👨‍🏫 أكثر المعلمين نشاطاً
    final teacherGroups = <String, int>{};
    for (final g in _groups) {
      if (g.teacherName != null && g.teacherName!.isNotEmpty) {
        teacherGroups[g.teacherName!] =
            (teacherGroups[g.teacherName!] ?? 0) + 1;
      }
    }
    if (teacherGroups.isNotEmpty && teacherGroups.length > 1) {
      final topTeacher = teacherGroups.entries.reduce(
        (a, b) => a.value > b.value ? a : b,
      );
      insights.add({
        'type': 'stat',
        'icon': Icons.star_rounded,
        'title': 'أكثر المعلمين نشاطاً',
        'message': '${topTeacher.key} - ${topTeacher.value} مجموعة',
        'color': Colors.amber,
      });
    }

    // 6. 💡 نصيحة ذكية
    final avgOccupancy = _groups.isEmpty
        ? 0
        : _groups.fold<double>(0, (sum, g) => sum + g.occupancyRate) /
              _groups.length;
    if (avgOccupancy < 50 && _groups.length > 2) {
      insights.add({
        'type': 'tip',
        'icon': Icons.lightbulb_rounded,
        'title': 'نصيحة ذكية',
        'message':
            'متوسط الإشغال ${avgOccupancy.toInt()}% - فكر في دمج بعض المجموعات لتحسين الكفاءة',
        'color': Colors.teal,
      });
    } else if (avgOccupancy > 80) {
      insights.add({
        'type': 'tip',
        'icon': Icons.trending_up_rounded,
        'title': 'أداء رائع! 🎉',
        'message':
            'متوسط إشغال ${avgOccupancy.toInt()}% - مجموعاتك تعمل بكفاءة عالية',
        'color': Colors.green,
      });
    }

    return insights.take(4).toList(); // Show max 4 insights
  }

  Widget _buildInsightItem(Map<String, dynamic> insight, bool isDark) {
    final color = insight['color'] as Color;
    final hasAction = insight['action'] != null;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: isDark
              ? color.withValues(alpha: 0.1)
              : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(
                insight['icon'] as IconData,
                color: color,
                size: 20.sp,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    insight['title'] as String,
                    style: GoogleFonts.cairo(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    insight['message'] as String,
                    style: GoogleFonts.cairo(
                      fontSize: 12.sp,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (hasAction)
              TextButton(
                onPressed: insight['actionCallback'] as VoidCallback?,
                style: TextButton.styleFrom(
                  foregroundColor: color,
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 6.h,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  backgroundColor: color.withValues(alpha: 0.1),
                ),
                child: Text(
                  insight['action'] as String,
                  style: GoogleFonts.cairo(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
