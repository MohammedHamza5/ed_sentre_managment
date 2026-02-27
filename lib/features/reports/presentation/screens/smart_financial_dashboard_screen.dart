/// Smart Financial Dashboard - لوحة التحكم المالية الذكية
/// Premium design with comprehensive financial analytics
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/providers/center_provider.dart';
import '../../bloc/reports_bloc.dart';
import '../../../students/data/repositories/students_repository.dart';
import '../../../teachers/data/repositories/teachers_repository.dart';
import '../../../subjects/data/repositories/subjects_repository.dart';
import '../../../payments/data/repositories/payment_repository.dart';
import '../../../attendance/data/repositories/attendance_repository.dart';
import '../../../groups/data/repositories/groups_repository.dart';
import '../../../rooms/data/repositories/rooms_repository.dart';

/// 💰 لوحة التحكم المالية الذكية - شاشة مبهرة
class SmartFinancialDashboardScreen extends StatelessWidget {
  const SmartFinancialDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final centerProvider = context.watch<CenterProvider>();

    if (!centerProvider.hasCenter) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business_center, size: 64),
            SizedBox(height: 16),
            Text('لم يتم العثور على بيانات السنتر'),
          ],
        ),
      );
    }

    return BlocProvider(
      create: (context) => ReportsBloc(
        studentsRepo: context.read<StudentsRepository>(),
        teachersRepo: context.read<TeachersRepository>(),
        subjectsRepo: context.read<SubjectsRepository>(),
        paymentsRepo: context.read<PaymentRepository>(),
        attendanceRepo: context.read<AttendanceRepository>(),
        groupsRepo: context.read<GroupsRepository>(),
        roomsRepo: context.read<RoomsRepository>(),
        centerId: centerProvider.centerId!,
      )..add(LoadReportData()),
      child: const _FinancialDashboardView(),
    );
  }
}

class _FinancialDashboardView extends StatelessWidget {
  const _FinancialDashboardView();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      body: BlocBuilder<ReportsBloc, ReportsState>(
        builder: (context, state) {
          if (state.status == ReportsStatus.loading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('جاري تحليل البيانات المالية...'),
                ],
              ),
            );
          }

          if (state.status == ReportsStatus.failure) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(state.errorMessage ?? 'حدث خطأ'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.read<ReportsBloc>().add(LoadReportData()),
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<ReportsBloc>().add(LoadReportData());
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(AppSpacing.lg.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  _buildHeader(context, isDark),
                  SizedBox(height: AppSpacing.xl.h),

                  // Main Revenue Card
                  _buildMainRevenueCard(context, isDark, state),
                  SizedBox(height: AppSpacing.lg.h),

                  // Collection Stats Row
                  _buildCollectionStatsRow(context, isDark, state),
                  SizedBox(height: AppSpacing.xl.h),

                  // Monthly Trend Chart
                  _buildMonthlyTrendCard(context, isDark, state),
                  SizedBox(height: AppSpacing.xl.h),

                  // Top Performers Section
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Teachers
                      Expanded(
                        child: _buildTopTeachersCard(context, isDark, state),
                      ),
                      SizedBox(width: AppSpacing.md.w),
                      // Top Courses
                      Expanded(
                        child: _buildTopCoursesCard(context, isDark, state),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.xl.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.4),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Icon(
              Icons.analytics_rounded,
              color: Colors.white,
              size: 32.sp,
            ),
          ),
          SizedBox(width: AppSpacing.md.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'لوحة التحكم المالية الذكية',
                  style: GoogleFonts.cairo(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'تحليل شامل للأداء المالي • ${DateTime.now().month}/${DateTime.now().year}',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          // Live Indicator
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Row(
              children: [
                Container(
                  width: 8.w,
                  height: 8.h,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 6.w),
                Text(
                  'مباشر',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainRevenueCard(BuildContext context, bool isDark, ReportsState state) {
    final progress = state.expectedRevenue > 0 
        ? (state.actualRevenue / state.expectedRevenue).clamp(0.0, 1.0) 
        : 0.0;

    return Container(
      padding: EdgeInsets.all(AppSpacing.xl.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Progress Arc
          SizedBox(
            width: 180.w,
            height: 180.h,
            child: CustomPaint(
              painter: _RevenueArcPainter(
                progress: progress,
                isDark: isDark,
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${state.collectionRate.toStringAsFixed(1)}%',
                      style: GoogleFonts.robotoMono(
                        fontSize: 32.sp,
                        fontWeight: FontWeight.bold,
                        color: _getCollectionColor(state.collectionRate),
                      ),
                    ),
                    Text(
                      'نسبة التحصيل',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: AppSpacing.xl.w),

          // Revenue Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Expected Revenue
                _buildRevenueRow(
                  icon: Icons.trending_up_rounded,
                  label: 'الإيراد المتوقع',
                  amount: state.expectedRevenue,
                  color: const Color(0xFF6366F1),
                  isDark: isDark,
                ),
                SizedBox(height: AppSpacing.lg.h),
                
                // Actual Revenue
                _buildRevenueRow(
                  icon: Icons.check_circle_rounded,
                  label: 'الإيراد الفعلي',
                  amount: state.actualRevenue,
                  color: const Color(0xFF10B981),
                  isDark: isDark,
                ),
                SizedBox(height: AppSpacing.lg.h),
                
                // Overdue Amount
                _buildRevenueRow(
                  icon: Icons.warning_rounded,
                  label: 'المبلغ المتأخر',
                  amount: state.overdueAmount,
                  color: const Color(0xFFEF4444),
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueRow({
    required IconData icon,
    required String label,
    required double amount,
    required Color color,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(10.w),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(icon, color: color, size: 22.sp),
        ),
        SizedBox(width: AppSpacing.md.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              Text(
                '${_formatNumber(amount)} جنيه',
                style: GoogleFonts.cairo(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCollectionStatsRow(BuildContext context, bool isDark, ReportsState state) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.people_rounded,
            label: 'الطلاب',
            value: state.totalStudents.toString(),
            color: const Color(0xFF6366F1),
            isDark: isDark,
          ),
        ),
        SizedBox(width: AppSpacing.md.w),
        Expanded(
          child: _buildStatCard(
            icon: Icons.school_rounded,
            label: 'المعلمون',
            value: state.totalTeachers.toString(),
            color: const Color(0xFFF59E0B),
            isDark: isDark,
          ),
        ),
        SizedBox(width: AppSpacing.md.w),
        Expanded(
          child: _buildStatCard(
            icon: Icons.menu_book_rounded,
            label: 'المواد',
            value: state.totalSubjects.toString(),
            color: const Color(0xFF10B981),
            isDark: isDark,
          ),
        ),
        SizedBox(width: AppSpacing.md.w),
        Expanded(
          child: _buildStatCard(
            icon: Icons.percent_rounded,
            label: 'الحضور',
            value: '${state.attendanceRate.toStringAsFixed(0)}%',
            color: const Color(0xFFEC4899),
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, color: color, size: 24.sp),
          ),
          SizedBox(height: AppSpacing.sm.h),
          Text(
            value,
            style: GoogleFonts.cairo(
              fontSize: 22.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyTrendCard(BuildContext context, bool isDark, ReportsState state) {
    final maxRevenue = state.monthlyRevenueTrend.isEmpty 
        ? 1.0 
        : state.monthlyRevenueTrend.map((e) => (e['revenue'] as double)).reduce(math.max);

    return Container(
      padding: EdgeInsets.all(AppSpacing.xl.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart_rounded, color: const Color(0xFF6366F1), size: 24.sp),
              SizedBox(width: AppSpacing.sm.w),
              Text(
                'تطور الإيرادات (آخر 6 أشهر)',
                style: GoogleFonts.cairo(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.xl.h),
          
          SizedBox(
            height: 150.h,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: state.monthlyRevenueTrend.asMap().entries.map((entry) {
                final data = entry.value;
                final revenue = (data['revenue'] as double);
                final height = maxRevenue > 0 ? (revenue / maxRevenue * 120.h) : 0.0;
                
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.w),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          _formatNumber(revenue),
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF6366F1),
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Container(
                          height: height.clamp(10.0, 120.h),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF6366F1),
                                const Color(0xFF8B5CF6),
                              ],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          data['monthName'] ?? '',
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopTeachersCard(BuildContext context, bool isDark, ReportsState state) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(Icons.star_rounded, color: const Color(0xFFF59E0B), size: 20.sp),
              ),
              SizedBox(width: AppSpacing.sm.w),
              Text(
                'أفضل المعلمين تحصيلاً',
                style: GoogleFonts.cairo(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.lg.h),
          
          if (state.topTeachersByRevenue.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xl.w),
                child: Text(
                  'لا توجد بيانات',
                  style: TextStyle(
                    color: isDark ? Colors.grey[500] : Colors.grey[400],
                  ),
                ),
              ),
            )
          else
            ...state.topTeachersByRevenue.asMap().entries.map((entry) {
              final index = entry.key;
              final teacher = entry.value;
              return _buildRankingItem(
                rank: index + 1,
                name: teacher['name'] ?? 'غير معروف',
                value: '${_formatNumber(teacher['revenue'] ?? 0)} جنيه',
                subtitle: '${teacher['studentsCount'] ?? 0} طالب',
                color: _getRankColor(index),
                isDark: isDark,
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTopCoursesCard(BuildContext context, bool isDark, ReportsState state) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(Icons.menu_book_rounded, color: const Color(0xFF10B981), size: 20.sp),
              ),
              SizedBox(width: AppSpacing.sm.w),
              Text(
                'أفضل المواد ربحية',
                style: GoogleFonts.cairo(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.lg.h),
          
          if (state.topCoursesByRevenue.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xl.w),
                child: Text(
                  'لا توجد بيانات',
                  style: TextStyle(
                    color: isDark ? Colors.grey[500] : Colors.grey[400],
                  ),
                ),
              ),
            )
          else
            ...state.topCoursesByRevenue.asMap().entries.map((entry) {
              final index = entry.key;
              final course = entry.value;
              return _buildRankingItem(
                rank: index + 1,
                name: course['name'] ?? 'غير معروف',
                value: '${_formatNumber(course['revenue'] ?? 0)} جنيه',
                subtitle: '${course['studentsCount'] ?? 0} طالب',
                color: _getRankColor(index),
                isDark: isDark,
              );
            }),
        ],
      ),
    );
  }

  Widget _buildRankingItem({
    required int rank,
    required String name,
    required String value,
    required String subtitle,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.sm.h),
      padding: EdgeInsets.all(AppSpacing.md.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 28.w,
            height: 28.h,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SizedBox(width: AppSpacing.md.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getCollectionColor(double rate) {
    if (rate >= 80) return const Color(0xFF10B981);
    if (rate >= 50) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  Color _getRankColor(int index) {
    const colors = [
      Color(0xFFFFD700), // Gold
      Color(0xFFC0C0C0), // Silver
      Color(0xFFCD7F32), // Bronze
      Color(0xFF6366F1), // Purple
      Color(0xFF10B981), // Green
    ];
    return colors[index % colors.length];
  }

  String _formatNumber(double number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toStringAsFixed(0);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CUSTOM PAINTER - Revenue Arc
// ═══════════════════════════════════════════════════════════════════════════

class _RevenueArcPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  _RevenueArcPainter({
    required this.progress,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 15;

    // Background arc
    final bgPaint = Paint()
      ..color = isDark ? Colors.grey[800]! : Colors.grey[200]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi * 0.75,
      math.pi * 1.5,
      false,
      bgPaint,
    );

    // Progress arc
    final progressPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF10B981),
          const Color(0xFF059669),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi * 0.75,
      math.pi * 1.5 * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
