import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/providers/center_provider.dart';
import '../../../../shared/widgets/cards/stat_card.dart';
import '../../data/reports_repository.dart';

/// شاشة التقارير الشاملة
class ComprehensiveReportsScreen extends StatefulWidget {
  const ComprehensiveReportsScreen({super.key});

  @override
  State<ComprehensiveReportsScreen> createState() =>
      _ComprehensiveReportsScreenState();
}

class _ComprehensiveReportsScreenState extends State<ComprehensiveReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _reportsRepo = ReportsRepository();

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  Map<String, dynamic> _overviewData = {};
  Map<String, dynamic> _attendanceData = {};
  Map<String, dynamic> _financialData = {};
  Map<String, dynamic> _teacherData = {};
  Map<String, dynamic> _groupData = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadAllReports();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllReports() async {
    setState(() => _isLoading = true);

    try {
      final centerId = context.read<CenterProvider>().centerId ?? '';

      final results = await Future.wait([
        _reportsRepo.getGeneralSummary(centerId),
        _reportsRepo.getAttendanceReport(centerId, _startDate, _endDate),
        _reportsRepo.getFinancialReport(centerId, _startDate, _endDate),
        _reportsRepo.getTeacherSalaryReport(centerId, _startDate),
        _reportsRepo.getGroupsReport(centerId),
      ]);

      if (!mounted) return;

      setState(() {
        _overviewData = results[0];
        _attendanceData = results[1];
        _financialData = results[2];
        _teacherData = results[3];
        _groupData = results[4];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في تحميل التقارير: $e')));
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadAllReports();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'التقارير الشاملة',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _selectDateRange,
                          icon: const Icon(Icons.date_range, size: 18),
                          label: Text(
                            '${DateFormat('dd/MM').format(_startDate)} - ${DateFormat('dd/MM').format(_endDate)}',
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        IconButton(
                          onPressed: _loadAllReports,
                          icon: const Icon(Icons.refresh),
                          tooltip: 'تحديث',
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                  indicatorColor: AppColors.primary,
                  isScrollable: true,
                  tabs: const [
                    Tab(text: 'الملخص', icon: Icon(Icons.dashboard, size: 18)),
                    Tab(
                      text: 'المالية',
                      icon: Icon(Icons.attach_money, size: 18),
                    ),
                    Tab(text: 'الحضور', icon: Icon(Icons.people, size: 18)),
                    Tab(text: 'المعلمين', icon: Icon(Icons.person, size: 18)),
                    Tab(text: 'المجموعات', icon: Icon(Icons.groups, size: 18)),
                  ],
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(isDark),
                      _buildFinancialTab(isDark),
                      _buildAttendanceTab(isDark),
                      _buildTeachersTab(isDark),
                      _buildGroupsTab(isDark),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(bool isDark) {
    final totalStudents = _overviewData['totalStudents'] ?? 0;
    final totalTeachers = _overviewData['totalTeachers'] ?? 0;
    final totalSubjects = _overviewData['totalSubjects'] ?? 0;
    final totalRooms = _overviewData['totalRooms'] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ملخص عام',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.lg),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 1.5,
            children: [
              StatCard(
                title: 'الطلاب',
                value: '$totalStudents',
                icon: Icons.school,
                iconBackgroundColor: AppColors.primary,
              ),
              StatCard(
                title: 'المعلمين',
                value: '$totalTeachers',
                icon: Icons.person,
                iconBackgroundColor: AppColors.success,
              ),
              StatCard(
                title: 'المواد',
                value: '$totalSubjects',
                icon: Icons.book,
                iconBackgroundColor: AppColors.info,
              ),
              StatCard(
                title: 'القاعات',
                value: '$totalRooms',
                icon: Icons.meeting_room,
                iconBackgroundColor: AppColors.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialTab(bool isDark) {
    final totalRevenue = _financialData['totalRevenue'] ?? 0.0;
    final count = _financialData['count'] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'التقارير المالية',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.lg),

          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'إجمالي الإيرادات',
                  value: '${totalRevenue.toStringAsFixed(0)} جنيه',
                  icon: Icons.monetization_on,
                  iconBackgroundColor: AppColors.success,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: StatCard(
                  title: 'عدد المدفوعات',
                  value: '$count',
                  icon: Icons.receipt,
                  iconBackgroundColor: AppColors.info,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),

          Card(
            color: isDark
                ? AppColors.darkSurfaceVariant
                : AppColors.lightSurfaceVariant,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تفاصيل إضافية',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text('سيتم إضافة رسوم بيانية ومخططات دائرية قريباً'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceTab(bool isDark) {
    final total = _attendanceData['total'] ?? 0;
    final present = _attendanceData['present'] ?? 0;
    final absent = _attendanceData['absent'] ?? 0;
    final late = _attendanceData['late'] ?? 0;
    final rate = _attendanceData['rate'] ?? 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'تقرير الحضور',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.lg),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 1.5,
            children: [
              StatCard(
                title: 'نسبة الحضور',
                value: '${rate.toStringAsFixed(1)}%',
                icon: Icons.trending_up,
                iconBackgroundColor: AppColors.success,
              ),
              StatCard(
                title: 'حاضر',
                value: '$present',
                icon: Icons.check_circle,
                iconBackgroundColor: AppColors.primary,
              ),
              StatCard(
                title: 'غائب',
                value: '$absent',
                icon: Icons.cancel,
                iconBackgroundColor: AppColors.error,
              ),
              StatCard(
                title: 'متأخر',
                value: '$late',
                icon: Icons.access_time,
                iconBackgroundColor: AppColors.warning,
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),

          if (total == 0)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xxl),
                child: Text('لا توجد سجلات حضور في هذه الفترة'),
              ),
            )
          else
            Card(
              color: isDark
                  ? AppColors.darkSurfaceVariant
                  : AppColors.lightSurfaceVariant,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تفاصيل الحضور ($total سجل)',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text('سيتم عرض جدول تفصيلي بسجلات الحضور قريباً'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTeachersTab(bool isDark) {
    final totalSalaries = _teacherData['totalSalaries'] ?? 0.0;
    final teacherCount = _teacherData['teacherCount'] ?? 0;
    final approved = _teacherData['approved'] ?? 0;
    final pending = _teacherData['pending'] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'تقرير رواتب المعلمين',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.lg),

          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'إجمالي الرواتب',
                  value: '${totalSalaries.toStringAsFixed(0)} جنيه',
                  icon: Icons.monetization_on,
                  iconBackgroundColor: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: StatCard(
                  title: 'عدد المعلمين',
                  value: '$teacherCount',
                  icon: Icons.person,
                  iconBackgroundColor: AppColors.info,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'معتمد',
                  value: '$approved',
                  icon: Icons.check_circle,
                  iconBackgroundColor: AppColors.success,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: StatCard(
                  title: 'قيد المراجعة',
                  value: '$pending',
                  icon: Icons.pending,
                  iconBackgroundColor: AppColors.warning,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),

          if (teacherCount == 0)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xxl),
                child: Text('لا توجد رواتب مسجلة'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGroupsTab(bool isDark) {
    final totalGroups = _groupData['totalGroups'] ?? 0;
    final groups = _groupData['groups'] as List<dynamic>? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'تقرير المجموعات',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              StatCard(
                title: 'إجمالي المجموعات',
                value: '$totalGroups',
                icon: Icons.groups,
                iconBackgroundColor: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          if (groups.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xxl),
                child: Text('لا توجد مجموعات مسجلة'),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
                final enrolled = group['enrolled'] ?? 0;
                final capacity = group['capacity'] ?? 0;
                final fillRate = capacity > 0 ? (enrolled / capacity * 100) : 0;

                return Card(
                  color: isDark
                      ? AppColors.darkSurfaceVariant
                      : AppColors.lightSurfaceVariant,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary,
                      child: Text('${index + 1}'),
                    ),
                    title: Text(
                      group['name'] ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('المادة: ${group['subject']}'),
                        Text('المعلم: ${group['teacher']}'),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.people, size: 16, color: AppColors.info),
                            const SizedBox(width: 4),
                            Text('$enrolled / $capacity طالب'),
                            const SizedBox(width: 16),
                            Icon(
                              Icons.trending_up,
                              size: 16,
                              color: fillRate > 80
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                            const SizedBox(width: 4),
                            Text('${fillRate.toStringAsFixed(0)}%'),
                          ],
                        ),
                      ],
                    ),
                    trailing: Text(
                      '${group['monthlyFee']} جنيه',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
