import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../core/utils/form_validators.dart';
import '../../../../core/providers/center_provider.dart';
import '../../../../core/offline/network_monitor.dart';
import '../../../../shared/widgets/cards/stat_card.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../../../shared/widgets/charts/charts.dart';
import '../../../../shared/models/models.dart';
import '../../bloc/dashboard_bloc.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../widgets/center_pulse_widget.dart';
import '../widgets/financial_forecast_widget.dart';
import '../../../reports/presentation/screens/student_profitability_screen.dart';
import '../../../reports/presentation/screens/financial_security_logs_screen.dart';
import '../../../reports/presentation/screens/system_debug_logs_screen.dart';

/// شاشة الصفحة الرئيسية (Dashboard)
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final centerProvider = context.watch<CenterProvider>();
    final networkMonitor = context.watch<NetworkMonitor>();

    if (!centerProvider.hasCenter) {
      // Check if offline or loading
      final isOffline = !networkMonitor.isOnline;
      final isLoading = centerProvider.isLoading;

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon based on state
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: isOffline
                      ? Colors.orange.withValues(alpha: 0.1)
                      : AppColors.gray100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isLoading
                      ? Icons.hourglass_empty
                      : isOffline
                      ? Icons.wifi_off_rounded
                      : Icons.business_center,
                  size: 48,
                  color: isOffline ? Colors.orange : AppColors.gray400,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Title
              Text(
                isLoading
                    ? 'جاري التحميل...'
                    : isOffline
                    ? 'الاتصال ضعيف أو غير متوفر'
                    : 'لم يتم العثور على بيانات السنتر',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),

              // Subtitle
              Text(
                isLoading
                    ? 'يرجى الانتظار'
                    : isOffline
                    ? 'تأكد من اتصالك بالإنترنت ثم أعد المحاولة'
                    : 'قد يكون هناك مشكلة في الاتصال أو لم يتم تعيين مركز',
                style: TextStyle(color: AppColors.gray500, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),

              // Loading indicator or retry button
              if (isLoading)
                const CircularProgressIndicator()
              else
                Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        // Check connection first
                        await networkMonitor.checkConnection();
                        // Retry loading center data
                        if (context.mounted) {
                          await context.read<CenterProvider>().reinitialize();
                        }
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('إعادة المحاولة'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('تسجيل الخروج وإعادة الدخول'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      );
    }

    return BlocProvider(
      create: (context) => DashboardBloc(
        context.read<DashboardRepository>(),
        centerProvider.centerId!,
      )..add(LoadDashboard()),
      child: BlocListener<DashboardBloc, DashboardState>(
        listenWhen: (prev, curr) =>
            prev.status == DashboardStatus.loading &&
            curr.status == DashboardStatus.success,
        listener: (context, state) {
          // 🔄 تحديث العدادات المركزية عند نجاح تحميل Dashboard
          centerProvider.refreshCounts();
        },
        child: const _DashboardView(),
      ),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final padding = ResponsiveUtils.getPagePadding(context);
    final gridColumns = ResponsiveUtils.getGridColumns(context);

    final gridSpacing = ResponsiveUtils.getGridSpacing(
      context,
    ).w; // Responsive spacing
    final strings = AppStrings.of(context);

    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, state) {
        if (state.status == DashboardStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.status == DashboardStatus.failure) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: AppColors.error,
                ),
                SizedBox(height: AppSpacing.lg.h),
                Text(state.errorMessage ?? strings.error),
                SizedBox(height: AppSpacing.lg.h),
                AppButton(
                  text: strings.retry,
                  onPressed: () =>
                      context.read<DashboardBloc>().add(LoadDashboard()),
                ),
              ],
            ),
          );
        }

        if (state.stats == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: () async {
            context.read<DashboardBloc>().add(RefreshDashboard());
          },
          child: SingleChildScrollView(
            padding: EdgeInsets.all(
              AppSpacing.pagePadding.w,
            ), // Manual overridden for responsiveness
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWelcomeSection(context, isDark, strings),
                SizedBox(height: AppSpacing.xxl.h),

                // GENIUS SECTION 🧠
                if (!ResponsiveUtils.isMobile(context))
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildStatsGrid(
                          context,
                          state.stats!,
                          gridColumns,
                          gridSpacing,
                          strings,
                        ),
                      ),
                      SizedBox(width: AppSpacing.lg.w),
                      Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                            // Pulse Widget (Visible to Everyone)
                            SizedBox(
                              width: double.infinity,
                              child: CenterPulseWidget(
                                data: state.centerPulse,
                                isDark: isDark,
                              ),
                            ),
                            SizedBox(height: AppSpacing.lg.h),

                            // Forecast Widget (Managers Only 🔒)
                            if (context.watch<CenterProvider>().isManager)
                              SizedBox(
                                width: double.infinity,
                                child: FinancialForecastWidget(
                                  data: state.financialForecast,
                                  isDark: isDark,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      CenterPulseWidget(
                        data: state.centerPulse,
                        isDark: isDark,
                      ),
                      SizedBox(height: AppSpacing.lg.h),
                      // Forecast Widget (Managers Only 🔒)
                      if (context.watch<CenterProvider>().isManager) ...[
                        FinancialForecastWidget(
                          data: state.financialForecast,
                          isDark: isDark,
                        ),
                        SizedBox(height: AppSpacing.sm.h),
                        // 🧠 GENIUS REPORT ENTRY POINT
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const StudentProfitabilityScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.analytics_outlined),
                            label: const Text('تقرير ربحية الطلاب'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark
                                  ? Colors.white
                                  : AppColors.primary,
                              side: BorderSide(
                                color: isDark
                                    ? Colors.white24
                                    : AppColors.primary.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        // 🛡️ SECURITY ENTRY POINT
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const FinancialSecurityLogsScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.security_rounded),
                            label: const Text('سجل الرقابة المالية'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: BorderSide(
                                color: AppColors.error.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        // 🐛 DEBUG LOGS ENTRY POINT
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SystemDebugLogsScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.bug_report_rounded),
                            label: const Text('سجلات النظام (Debug)'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey,
                              side: BorderSide(
                                color: Colors.grey.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (context.watch<CenterProvider>().isManager)
                        SizedBox(height: AppSpacing.lg.h),

                      _buildStatsGrid(
                        context,
                        state.stats!,
                        gridColumns,
                        gridSpacing,
                        strings,
                      ),
                    ],
                  ),

                SizedBox(height: AppSpacing.xxl.h),
                if (!ResponsiveUtils.isMobile(context)) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: WeeklyAttendanceChart(
                          data: state.weeklyAttendance,
                        ),
                      ),
                      SizedBox(width: AppSpacing.lg.w),
                      Expanded(
                        child: StudentDistributionChart(
                          data: state.studentDistribution,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.lg.h),
                ] else ...[
                  WeeklyAttendanceChart(data: state.weeklyAttendance),
                  SizedBox(height: AppSpacing.lg.h),
                  StudentDistributionChart(data: state.studentDistribution),
                  SizedBox(height: AppSpacing.lg.h),
                ],
                ResponsiveUtils.isMobile(context)
                    ? _buildMobileBottomSection(context, isDark, state, strings)
                    : _buildDesktopBottomSection(
                        context,
                        isDark,
                        state,
                        strings,
                      ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWelcomeSection(
    BuildContext context,
    bool isDark,
    AppStrings strings,
  ) {
    final now = DateTime.now();
    final dayNames = strings.daysList;
    final dayIndex = (now.weekday + 1) % 7;
    final dayName = dayNames[dayIndex];

    final monthNames = strings.isArabic
        ? [
            'يناير',
            'فبراير',
            'مارس',
            'أبريل',
            'مايو',
            'يونيو',
            'يوليو',
            'أغسطس',
            'سبتمبر',
            'أكتوبر',
            'نوفمبر',
            'ديسمبر',
          ]
        : [
            'January',
            'February',
            'March',
            'April',
            'May',
            'June',
            'July',
            'August',
            'September',
            'October',
            'November',
            'December',
          ];

    final centerProvider = context.watch<CenterProvider>();

    return Container(
      padding: EdgeInsets.all(AppSpacing.md.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.md.w,
                        vertical: AppSpacing.xs.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusFull,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 12.sp, // Reduced
                            color: Colors.white,
                          ),
                          SizedBox(width: AppSpacing.xs.w),
                          Text(
                            '$dayName، ${now.day} ${monthNames[now.month - 1]}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.sp, // Reduced
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.sm.h), // Reduced from md
                Text(
                  '${strings.welcome}، ${centerProvider.centerName} 👋',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                    fontSize: 22.sp, // Reduced from 28
                  ),
                ),
                SizedBox(height: 4.h), // Reduced from sm (8)
                Text(
                  'إليك نظرة عامة على أداء سنترك اليوم',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12.sp, // Reduced from 14
                  ),
                ),
                // عرض نظام الدفع الحالي - جديد ✨
                SizedBox(height: AppSpacing.sm.h),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md.w,
                    vertical: AppSpacing.xs.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        centerProvider.billingConfig.isPerSession
                            ? Icons.confirmation_number
                            : centerProvider.billingConfig.isMonthly
                            ? Icons.calendar_month
                            : Icons.payment,
                        size: 12.sp, // Reduced
                        color: Colors.white,
                      ),
                      SizedBox(width: AppSpacing.xs.w),
                      Text(
                        'نظام الدفع: ${centerProvider.billingConfig.billingTypeArabic}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.sp, // Reduced
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!ResponsiveUtils.isMobile(context)) ...[
            SizedBox(width: AppSpacing.xl.w),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg.r),
                  onTap: () => context.go('/students/add'),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl.w,
                      vertical: AppSpacing.md.h,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 32.w,
                          height: 32.w,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusSm.r,
                            ),
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 18.sp,
                          ),
                        ),
                        SizedBox(width: AppSpacing.md.w),
                        Text(
                          strings.addNewStudent,
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsGrid(
    BuildContext context,
    DashboardStats stats,
    int columns,
    double spacing,
    AppStrings strings,
  ) {
    final centerProvider = context.watch<CenterProvider>();
    final isManager = centerProvider.isManager;

    final statsList = [
      _StatData(
        title: strings.totalStudents,
        value: stats.totalStudents.toString(),
        icon: Icons.school_rounded,
        color: AppColors.primary,
        changePercent: stats.totalStudentsChange.abs(),
        isIncreasing: stats.totalStudentsChange >= 0,
        subtitle: strings.isArabic
            ? '${stats.totalStudentsChange >= 0 ? '+' : ''}${stats.totalStudentsChange.toStringAsFixed(1)}% عن الشهر الماضي'
            : '${stats.totalStudentsChange >= 0 ? '+' : ''}${stats.totalStudentsChange.toStringAsFixed(1)}% from last month',
        gradient: AppColors.primaryGradient,
      ),
      _StatData(
        title: strings.totalTeachers,
        value: stats.totalTeachers.toString(),
        icon: Icons.person_rounded,
        color: AppColors.secondary,
        changePercent: stats.totalTeachersChange.abs(),
        isIncreasing: stats.totalTeachersChange >= 0,
        subtitle: strings.isArabic
            ? '${stats.totalTeachersChange >= 0 ? '+' : ''}${stats.totalTeachersChange.toStringAsFixed(1)}% عن الشهر الماضي'
            : '${stats.totalTeachersChange >= 0 ? '+' : ''}${stats.totalTeachersChange.toStringAsFixed(1)}% from last month',
        gradient: AppColors.purpleGradient,
      ),
      _StatData(
        title: strings.subjects,
        value: stats.totalSubjects.toString(),
        icon: Icons.menu_book_rounded,
        color: AppColors.info,
        subtitle: strings.isArabic
            ? '${stats.totalSubjects} مواد مسجلة'
            : '${stats.totalSubjects} registered subjects',
        gradient: AppColors.infoGradient,
      ),
      // Hide Revenue from non-managers 🔒
      if (isManager)
        _StatData(
          title: strings.todayRevenue,
          value: FormUtils.formatCurrency(stats.todayRevenue),
          icon: Icons.payments_rounded,
          color: AppColors.success,
          changePercent: stats.todayRevenueChange.abs(),
          isIncreasing: stats.todayRevenueChange >= 0,
          subtitle: strings.isArabic
              ? '${stats.todayRevenueChange >= 0 ? '+' : ''}${stats.todayRevenueChange.toStringAsFixed(1)}% عن أمس'
              : '${stats.todayRevenueChange >= 0 ? '+' : ''}${stats.todayRevenueChange.toStringAsFixed(1)}% from yesterday',
          gradient: AppColors.successGradient,
        ),
      _StatData(
        title: strings.todaySessions,
        value: stats.todaySessions.toString(),
        icon: Icons.event_rounded,
        color: AppColors.warning,
        subtitle: '${stats.completedSessions} ${strings.completed}',
        gradient: AppColors.warningGradient,
      ),
      _StatData(
        title: strings.attendanceRate,
        value: '${stats.attendanceRate.toStringAsFixed(0)}%',
        icon: Icons.trending_up_rounded,
        color: AppColors.success,
        changePercent: stats.attendanceRateChange.abs(),
        isIncreasing: stats.attendanceRateChange >= 0,
        subtitle: strings.isArabic
            ? '${stats.attendanceRateChange >= 0 ? '+' : ''}${stats.attendanceRateChange.toStringAsFixed(1)}% عن الأسبوع الماضي'
            : '${stats.attendanceRateChange >= 0 ? '+' : ''}${stats.attendanceRateChange.toStringAsFixed(1)}% from last week',
        gradient: AppColors.accentGradient,
      ),
      _StatData(
        title: strings.isArabic ? 'المجموعات النشطة' : 'Active Groups',
        value: stats.activeGroups.toString(),
        icon: Icons.groups_rounded,
        color: const Color(0xFF8B5CF6), // Violet
        subtitle: strings.isArabic
            ? '${stats.fullGroups} مجموعة مكتملة'
            : '${stats.fullGroups} full groups',
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFFC4B5FD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      // 🕐 أقرب حصة - Next Session
      _StatData(
        title: strings.isArabic ? 'أقرب حصة' : 'Next Session',
        value: stats.nextSessionTime ?? '--:--',
        icon: Icons.schedule_rounded,
        color: const Color(0xFF5B9EA6), // Teal
        subtitle:
            stats.nextSessionName ??
            (strings.isArabic ? 'لا توجد حصص' : 'No sessions'),
        gradient: const LinearGradient(
          colors: [Color(0xFF5B9EA6), Color(0xFF7FC8D4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: ResponsiveUtils.getGridAspectRatio(context),
      ),
      itemCount: statsList.length,
      itemBuilder: (context, index) {
        final stat = statsList[index];
        return StatCard(
          title: stat.title,
          value: stat.value,
          icon: stat.icon,
          iconColor: stat.color,
          changePercent: stat.changePercent,
          isIncreasing: stat.isIncreasing,
          subtitle: stat.subtitle,
          gradient: stat.gradient,
        );
      },
    );
  }

  Widget _buildDesktopBottomSection(
    BuildContext context,
    bool isDark,
    DashboardState state,
    AppStrings strings,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: _TodayScheduleCard(
            isDark: isDark,
            sessions: state.todaySessions,
            strings: strings,
          ),
        ),
        const SizedBox(width: AppSpacing.xl),
        Expanded(
          child: Column(
            children: [
              _RecentActivitiesCard(
                isDark: isDark,
                notifications: state.recentNotifications,
                strings: strings,
              ),
              const SizedBox(height: AppSpacing.lg),
              _AlertsCard(
                isDark: isDark,
                overduePayments: state.overduePayments,
                strings: strings,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileBottomSection(
    BuildContext context,
    bool isDark,
    DashboardState state,
    AppStrings strings,
  ) {
    return Column(
      children: [
        _TodayScheduleCard(
          isDark: isDark,
          sessions: state.todaySessions,
          strings: strings,
        ),
        const SizedBox(height: AppSpacing.lg),
        _RecentActivitiesCard(
          isDark: isDark,
          notifications: state.recentNotifications,
          strings: strings,
        ),
        const SizedBox(height: AppSpacing.lg),
        _AlertsCard(
          isDark: isDark,
          overduePayments: state.overduePayments,
          strings: strings,
        ),
      ],
    );
  }
}

class _StatData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final double? changePercent;
  final bool isIncreasing;
  final String? subtitle;
  final LinearGradient? gradient;

  _StatData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.changePercent,
    this.isIncreasing = true,
    this.subtitle,
    this.gradient,
  });
}

/// بطاقة جدول اليوم
class _TodayScheduleCard extends StatelessWidget {
  final bool isDark;
  final List<ScheduleSession> sessions;
  final AppStrings strings;

  const _TodayScheduleCard({
    required this.isDark,
    required this.sessions,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg.r),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(AppSpacing.lg.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      color: AppColors.primary,
                      size: 20.sp,
                    ),
                    SizedBox(width: AppSpacing.sm.w),
                    Text(
                      strings.todaySchedule,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => context.go('/schedule'),
                  child: Text(strings.viewAll),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (sessions.isEmpty)
            Padding(
              padding: EdgeInsets.all(AppSpacing.xl.w),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.event_busy,
                      size: 48.sp,
                      color: AppColors.gray400,
                    ),
                    SizedBox(height: AppSpacing.md.h),
                    Text(
                      strings.isArabic
                          ? 'لا توجد حصص اليوم'
                          : 'No sessions today',
                      style: TextStyle(color: AppColors.gray500),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sessions.length.clamp(0, 5),
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final session = sessions[index];
                return ListTile(
                  leading: Container(
                    width: 40.w,
                    height: 40.w,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: const Icon(Icons.schedule, color: AppColors.primary),
                  ),
                  title: Text(session.subjectName ?? 'حصة'),
                  subtitle: Text(session.teacherName ?? ''),
                  trailing: Text(
                    session.startTime ?? '--:--',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// بطاقة الأنشطة الأخيرة
class _RecentActivitiesCard extends StatelessWidget {
  final bool isDark;
  final List<AppNotification> notifications;
  final AppStrings strings;

  const _RecentActivitiesCard({
    required this.isDark,
    required this.notifications,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg.r),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(AppSpacing.lg.w),
            child: Row(
              children: [
                Icon(
                  Icons.notifications_active,
                  color: AppColors.warning,
                  size: 20.sp,
                ),
                SizedBox(width: AppSpacing.sm.w),
                Text(
                  strings.isArabic ? 'آخر الأنشطة' : 'Recent Activities',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (notifications.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: Text(
                  strings.isArabic
                      ? 'لا توجد أنشطة حديثة'
                      : 'No recent activities',
                  style: TextStyle(color: AppColors.gray500),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: notifications.length.clamp(0, 3),
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16.r,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: Icon(
                      Icons.info_outline,
                      size: 16.sp,
                      color: AppColors.primary,
                    ),
                  ),
                  title: Text(notification.title),
                  subtitle: Text(notification.body),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// بطاقة التنبيهات
class _AlertsCard extends StatelessWidget {
  final bool isDark;
  final List<Payment> overduePayments;
  final AppStrings strings;

  const _AlertsCard({
    required this.isDark,
    required this.overduePayments,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg.r),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(AppSpacing.lg.w),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: AppColors.error, size: 20.sp),
                SizedBox(width: AppSpacing.sm.w),
                Text(
                  strings.isArabic ? 'تنبيهات المدفوعات' : 'Payment Alerts',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (overduePayments.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.success),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    strings.isArabic
                        ? 'لا توجد متأخرات'
                        : 'No overdue payments',
                    style: TextStyle(color: AppColors.success),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: overduePayments.length.clamp(0, 3),
              itemBuilder: (context, index) {
                final payment = overduePayments[index];
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16.r,
                    backgroundColor: AppColors.error.withValues(alpha: 0.1),
                    child: Icon(
                      Icons.money_off,
                      size: 16.sp,
                      color: AppColors.error,
                    ),
                  ),
                  title: Text(payment.studentName ?? ''),
                  subtitle: Text('${payment.amount} ج.م'),
                  trailing: Icon(Icons.arrow_forward_ios, size: 14.sp),
                  onTap: () {
                    final studentId = payment.studentId;
                    if (studentId.isNotEmpty) {
                      context.go('/students/$studentId');
                    }
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}
