import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../data/repositories/teachers_repository.dart';

/// شاشة إحصائيات المعلمين الذكية
class TeacherStatisticsScreen extends StatefulWidget {
  const TeacherStatisticsScreen({super.key});

  @override
  State<TeacherStatisticsScreen> createState() =>
      _TeacherStatisticsScreenState();
}

class _TeacherStatisticsScreenState extends State<TeacherStatisticsScreen>
    with SingleTickerProviderStateMixin {
  final TeachersRepository _repo = TeachersRepository();
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _error;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadData();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _repo.getTeacherStatistics();
      if (!mounted) return;
      setState(() {
        _data = data;
        _isLoading = false;
      });
      _animController.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF1a1a2e), const Color(0xFF16213e)]
                : [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(isDark),
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : _error != null
                    ? _buildErrorState()
                    : _buildContent(isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg.w),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios, size: 20.sp),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📊 إحصائيات المعلمين',
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'نظرة شاملة على أداء المعلمين',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          SizedBox(height: 16.h),
          Text('جاري تحميل الإحصائيات...', style: TextStyle(fontSize: 14.sp)),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64.sp, color: Colors.red),
          SizedBox(height: 16.h),
          Text(
            'حدث خطأ: $_error',
            style: TextStyle(fontSize: 14.sp),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: _loadData,
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    final teachers = (_data?['teachers'] as List?) ?? [];
    final teachersCount = _data?['teachers_count'] ?? 0;
    final month = _data?['month'];
    final year = _data?['year'];

    // حساب الإجماليات الجديدة
    double totalExpected = 0;
    double totalCollected = 0;
    double totalTeacherShare = 0;
    double totalCenterShare = 0;
    int totalStudents = 0;
    int totalGroups = 0;

    for (final t in teachers) {
      totalExpected += (t['expected_revenue'] as num?)?.toDouble() ?? 0;
      totalCollected += (t['collected_revenue'] as num?)?.toDouble() ?? 0;
      totalTeacherShare += (t['teacher_share'] as num?)?.toDouble() ?? 0;
      totalCenterShare += (t['center_share'] as num?)?.toDouble() ?? 0;
      totalStudents += (t['total_students'] as int?) ?? 0;
      totalGroups += (t['groups_count'] as int?) ?? 0;
    }

    final collectionRate = totalExpected > 0
        ? (totalCollected / totalExpected * 100).round()
        : 0;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: EdgeInsets.all(AppSpacing.md.w),
        children: [
          // Month indicator
          if (month != null && year != null)
            Container(
              padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_month,
                    size: 16,
                    color: Color(0xFF6366F1),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    '$month/$year',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(height: 16.h),

          // Summary Cards - Row 1
          _buildSummarySection(
            isDark,
            teachersCount,
            totalGroups,
            totalStudents,
            totalCollected,
          ),
          SizedBox(height: 12.h),

          // Financial Summary - Row 2
          _buildFinancialSummary(
            isDark,
            totalExpected,
            totalCollected,
            totalTeacherShare,
            totalCenterShare,
            collectionRate,
          ),
          SizedBox(height: 20.h),

          // Teachers List
          Text(
            '👨‍🏫 المعلمون',
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12.h),

          ...teachers.map((t) => _buildTeacherCard(isDark, t)),
        ],
      ),
    );
  }

  Widget _buildFinancialSummary(
    bool isDark,
    double expected,
    double collected,
    double teacherShare,
    double centerShare,
    int rate,
  ) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFFFFFFFF), const Color(0xFFF8FAFC)],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics, color: Color(0xFF6366F1)),
              SizedBox(width: 8.w),
              Text(
                'ملخص مالي',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: rate >= 80
                      ? Colors.green.withValues(alpha: 0.2)
                      : Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  '$rate% تحصيل',
                  style: TextStyle(
                    color: rate >= 80 ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.sp,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: _buildFinancialItem(
                  'المتوقع',
                  expected,
                  Colors.blue,
                  isDark,
                ),
              ),
              Expanded(
                child: _buildFinancialItem(
                  'المحصل',
                  collected,
                  Colors.green,
                  isDark,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: _buildFinancialItem(
                  'نصيب المعلمين',
                  teacherShare,
                  Colors.purple,
                  isDark,
                ),
              ),
              Expanded(
                child: _buildFinancialItem(
                  'نصيب المركز',
                  centerShare,
                  Colors.teal,
                  isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialItem(
    String label,
    double value,
    Color color,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          '${value.toStringAsFixed(0)} ج',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSummarySection(
    bool isDark,
    int teachersCount,
    int totalGroups,
    int totalStudents,
    double totalRevenue,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            isDark,
            '👨‍🏫',
            teachersCount.toString(),
            'معلم',
            const Color(0xFF6366F1),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: _buildSummaryCard(
            isDark,
            '📚',
            totalGroups.toString(),
            'مجموعة',
            const Color(0xFF22C55E),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: _buildSummaryCard(
            isDark,
            '👨‍🎓',
            totalStudents.toString(),
            'طالب',
            const Color(0xFFF59E0B),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: _buildSummaryCard(
            isDark,
            '💰',
            totalRevenue.toStringAsFixed(0),
            'جنيه',
            const Color(0xFFEC4899),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    bool isDark,
    String emoji,
    String value,
    String label,
    Color color,
  ) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * _animController.value),
          child: Opacity(
            opacity: _animController.value,
            child: Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Text(emoji, style: TextStyle(fontSize: 24.sp)),
                  SizedBox(height: 4.h),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTeacherCard(bool isDark, Map<String, dynamic> teacher) {
    final groups = (teacher['groups'] as List?) ?? [];
    final isExpanded = ValueNotifier<bool>(false);

    return ValueListenableBuilder<bool>(
      valueListenable: isExpanded,
      builder: (context, expanded, _) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: EdgeInsets.only(bottom: 12.h),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Teacher Header
              InkWell(
                onTap: () => isExpanded.value = !expanded,
                borderRadius: BorderRadius.circular(16.r),
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 50.w,
                        height: 50.w,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                          ),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Center(
                          child: Text(
                            (teacher['teacher_name'] as String?)?.substring(
                                  0,
                                  1,
                                ) ??
                                '?',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),

                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              teacher['teacher_name'] ?? 'غير معروف',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Row(
                              children: [
                                _buildMiniStat(
                                  '📚',
                                  '${teacher['groups_count']}',
                                ),
                                SizedBox(width: 12.w),
                                _buildMiniStat(
                                  '👨‍🎓',
                                  '${teacher['total_students']}',
                                ),
                                SizedBox(width: 12.w),
                                _buildMiniStat(
                                  '💰',
                                  '${(teacher['collected_revenue'] as num?)?.toStringAsFixed(0) ?? 0}',
                                ),
                              ],
                            ),
                            SizedBox(height: 4.h),
                            Row(
                              children: [
                                Text(
                                  'نصيبه: ${(teacher['teacher_share'] as num?)?.toStringAsFixed(0) ?? 0} ج',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    color: Colors.purple,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Text(
                                  '(${teacher['salary_type'] ?? 'percentage'})',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Expand Icon
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Groups List (Expanded)
              if (expanded)
                Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.2)
                        : Colors.grey.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(16.r),
                      bottomRight: Radius.circular(16.r),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Divider(height: 1),
                      ...groups.map((g) => _buildGroupTile(isDark, g)),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniStat(String emoji, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: TextStyle(fontSize: 12.sp)),
        SizedBox(width: 4.w),
        Text(
          value,
          style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildGroupTile(bool isDark, Map<String, dynamic> group) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Center(
              child: Text('📚', style: TextStyle(fontSize: 18.sp)),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group['group_name'] ?? 'غير معروف',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2.h),
                Row(
                  children: [
                    Text(
                      '🎓 ${group['grade_level'] ?? 'غير محدد'}',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Text(
                      '📅 ${group['schedules_count'] ?? 0} مواعيد',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${(group['collected_revenue'] as num?)?.toStringAsFixed(0) ?? 0} ج',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF22C55E),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: ((group['collection_rate'] as num?) ?? 0) >= 80
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(
                  '${group['collection_rate'] ?? 0}%',
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                    color: ((group['collection_rate'] as num?) ?? 0) >= 80
                        ? Colors.green
                        : Colors.orange,
                  ),
                ),
              ),
              Text(
                '${group['students_count'] ?? 0} طالب',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
