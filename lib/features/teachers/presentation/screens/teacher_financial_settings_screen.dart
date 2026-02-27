import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../data/repositories/teachers_repository.dart';
import '../../../../core/providers/center_provider.dart';
import '../../../../core/monitoring/app_logger.dart';

class TeacherFinancialSettingsScreen extends StatefulWidget {
  final String teacherId;
  final String teacherName;

  const TeacherFinancialSettingsScreen({
    super.key,
    required this.teacherId,
    required this.teacherName,
  });

  @override
  State<TeacherFinancialSettingsScreen> createState() =>
      _TeacherFinancialSettingsScreenState();
}

class _TeacherFinancialSettingsScreenState
    extends State<TeacherFinancialSettingsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _tiers = [];

  // New Tier Inputs
  final _minRevenueController = TextEditingController();
  final _maxRevenueController = TextEditingController();
  final _percentageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    AppLogger.ui(
      '👨‍🏫 [TeacherFinancialSettings] Loading tiers for ${widget.teacherName}',
    );
    setState(() => _isLoading = true);
    final repo = context.read<TeachersRepository>();
    final centerId = context.read<CenterProvider>().centerId!;

    try {
      final tiers = await repo.getTeacherTiers(centerId, widget.teacherId);
      if (mounted) {
        setState(() {
          _tiers = tiers;
          _isLoading = false;
        });
        AppLogger.success(
          '✅ [TeacherFinancialSettings] Tiers loaded',
          data: {'count': tiers.length},
        );
      }
    } catch (e) {
      AppLogger.error(
        '❌ [TeacherFinancialSettings] Load failed',
        error: e,
        source: ErrorSource.backend,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addTier() async {
    if (_percentageController.text.isEmpty) return;

    final repo = context.read<TeachersRepository>();
    final centerId = context.read<CenterProvider>().centerId!;

    try {
      await repo.addTeacherTier(
        centerId: centerId,
        teacherId: widget.teacherId,
        minRevenue: double.tryParse(_minRevenueController.text) ?? 0,
        maxRevenue: double.tryParse(_maxRevenueController.text) ?? 9999999,
        percentage: double.parse(_percentageController.text),
      );

      _minRevenueController.clear();
      _maxRevenueController.clear();
      _percentageController.clear();

      _loadSettings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteTier(String id) async {
    final repo = context.read<TeachersRepository>();
    try {
      await repo.deleteTeacherTier(id);
      _loadSettings();
    } catch (e) {
      // handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الإعدادات المالية',
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                fontSize: 18.sp,
              ),
            ),
            Text(widget.teacherName, style: TextStyle(fontSize: 12.sp)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFairPlayInfo(),
                  SizedBox(height: 24.h),

                  Text(
                    'نظام الشرائح (Tiers)',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'كلما زاد إيراد المعلم (المحصل)، زادت نسبته.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  SizedBox(height: 16.h),

                  _buildTiersList(),
                  SizedBox(height: 16.h),
                  _buildAddTierForm(),
                ],
              ),
            ),
    );
  }

  Widget _buildFairPlayInfo() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.blue),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'سياسة اللعب النظيف (Fair Play)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                Text(
                  'يتم حساب راتب المعلم بناءً على "المبالغ المحصلة فعلياً" من الطلاب، وليس اجمالي الفواتير.',
                  style: TextStyle(fontSize: 12.sp, color: Colors.blue[800]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTiersList() {
    if (_tiers.isEmpty) {
      return const Center(
        child: Text('لم يتم تحديد شرائح بعد. (الافتراضي 0%)'),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _tiers.length,
      itemBuilder: (context, index) {
        final tier = _tiers[index];
        return Card(
          margin: EdgeInsets.only(bottom: 8.h),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green.withValues(alpha: 0.1),
              child: Text(
                '${tier['percentage']}%',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              'من ${tier['min_revenue']} إلى ${tier['max_revenue']} ج.م',
            ),
            trailing: IconButton(
              icon: Icon(Icons.delete, color: Colors.red, size: 20.sp),
              onPressed: () => _deleteTier(tier['id']),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAddTierForm() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'إضافة شريحة جديدة',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minRevenueController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'من (إيراد)',
                      suffixText: 'ج',
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: TextField(
                    controller: _maxRevenueController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'إلى (إيراد)',
                      suffixText: 'ج',
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _percentageController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'النسبة',
                      suffixText: '%',
                    ),
                  ),
                ),
                SizedBox(width: 16.w),
                FilledButton.icon(
                  onPressed: _addTier,
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


