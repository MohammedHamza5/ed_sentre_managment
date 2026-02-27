/// Course Prices Screen - EdSentre
/// شاشة جدول أسعار المواد
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/center_provider.dart';
import '../../data/repositories/settings_repository.dart';
import '../../../subjects/data/repositories/subjects_repository.dart';
import '../../../teachers/data/repositories/teachers_repository.dart';
import '../../../../shared/models/models.dart';

class CoursePricesScreen extends StatefulWidget {
  final String? initialSubjectName;
  final bool autoOpenAddDialog;

  const CoursePricesScreen({
    super.key,
    this.initialSubjectName,
    this.autoOpenAddDialog = false,
  });

  @override
  State<CoursePricesScreen> createState() => _CoursePricesScreenState();
}

class _CoursePricesScreenState extends State<CoursePricesScreen> {
  List<CoursePrice> _prices = [];
  List<Teacher> _teachers = [];
  List<Subject> _subjects = [];
  BillingConfig? _billingConfig;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final settingsRepo = SettingsRepository();
      final teachersRepo = context.read<TeachersRepository>();
      final subjectsRepo = context.read<SubjectsRepository>();
      final centerId = context.read<CenterProvider>().centerId!;

      // جلب الأسعار والمدرسين والمواد
      final pricesData = await settingsRepo.getCoursePrices(centerId);
      final teachersData = await teachersRepo.getTeachers();
      final subjectsData = await subjectsRepo.getSubjects();
      final billingConfig = context.read<CenterProvider>().billingConfig;

      if (mounted) {
        setState(() {
          _prices = pricesData;
          _teachers = teachersData;
          _subjects = subjectsData;
          _billingConfig = billingConfig;
          _isLoading = false;
        });

        // 🧠 GENIUS: Auto-open dialog if requested
        if (widget.autoOpenAddDialog && widget.initialSubjectName != null) {
          // Small delay to ensure UI is ready
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _showAddPriceDialog(
                preselectedSubject: widget.initialSubjectName,
              );
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '💰 جدول الأسعار',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(_errorMessage!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadData,
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            )
          : _prices.isEmpty
          ? _buildEmptyState()
          : _buildPricesList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddPriceDialog(),
        icon: const Icon(Icons.add),
        label: Text(
          'إضافة سعر',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.price_change_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد أسعار بعد',
            style: GoogleFonts.cairo(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'أضف أسعار المواد لتسهيل عملية الدفع',
            style: TextStyle(color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddPriceDialog(),
            icon: const Icon(Icons.add),
            label: const Text('إضافة أول سعر'),
          ),
        ],
      ),
    );
  }

  Widget _buildPricesList() {
    // تجميع الأسعار حسب المادة
    final groupedPrices = <String, List<CoursePrice>>{};
    for (final price in _prices) {
      groupedPrices.putIfAbsent(price.subjectName, () => []).add(price);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ملخص
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.price_check, size: 40, color: Colors.white),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'جدول الأسعار الذكي',
                        style: GoogleFonts.cairo(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${_prices.length} سعر | ${groupedPrices.length} مادة',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // قائمة الأسعار حسب المادة
          ...groupedPrices.entries.map(
            (entry) => _buildSubjectPriceCard(entry.key, entry.value),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectPriceCard(String subjectName, List<CoursePrice> prices) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.book, color: Colors.blue),
        ),
        title: Text(
          subjectName,
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${prices.length} أسعار مختلفة'),
        children: prices.map((price) => _buildPriceRow(price)).toList(),
      ),
    );
  }

  Widget _buildPriceRow(CoursePrice price) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getLevelColor(
          price.specificityLevel,
        ).withValues(alpha: 0.1),
        child: Text(
          price.specificityLevel == 1
              ? '🎯'
              : price.specificityLevel == 2
              ? '📊'
              : '📋',
          style: const TextStyle(fontSize: 16),
        ),
      ),
      title: Row(
        children: [
          if (price.teacherName != null && price.teacherName != 'أي مدرس') ...[
            Chip(
              label: Text(
                price.teacherName!,
                style: const TextStyle(fontSize: 11),
              ),
              backgroundColor: Colors.purple.withValues(alpha: 0.1),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
          ],
          if (price.gradeLevel != null && price.gradeLevel != 'كل المراحل') ...[
            Chip(
              label: Text(
                price.gradeLevel!,
                style: const TextStyle(fontSize: 11),
              ),
              backgroundColor: Colors.orange.withValues(alpha: 0.1),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ],
          if (price.teacherId == null && price.gradeLevel == null)
            Text(
              'السعر الافتراضي',
              style: TextStyle(color: Colors.grey.shade600),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${price.sessionPrice.toStringAsFixed(0)} ج/حصة',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              Text(
                '${price.calculatedMonthlyPrice.toStringAsFixed(0)} ج/شهر',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            onPressed: () => _showEditPriceDialog(price),
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
            onPressed: () => _confirmDeletePrice(price),
          ),
        ],
      ),
    );
  }

  Color _getLevelColor(int level) {
    switch (level) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  void _showAddPriceDialog({String? preselectedSubject}) {
    _showPriceDialog(null, preselectedSubject: preselectedSubject);
  }

  void _showEditPriceDialog(CoursePrice price) {
    _showPriceDialog(price);
  }

  void _showPriceDialog(
    CoursePrice? existingPrice, {
    String? preselectedSubject,
  }) {
    // التأكد من أن القيمة موجودة في القائمة
    final subjectNames = _subjects.map((s) => s.name).toList();
    String? selectedSubjectName = existingPrice?.subjectName ?? preselectedSubject;
    if (selectedSubjectName != null && !subjectNames.contains(selectedSubjectName)) {
      selectedSubjectName = null; // إعادة تعيين إذا لم تكن موجودة
    }
    
    final sessionPriceController = TextEditingController(
      text: existingPrice?.sessionPrice.toStringAsFixed(0) ?? '',
    );
    final monthlyPriceController = TextEditingController(
      text: existingPrice?.monthlyPrice?.toStringAsFixed(0) ?? '',
    );
    final sessionsController = TextEditingController(
      text: (existingPrice?.sessionsPerMonth ?? 8).toString(),
    );
    String? selectedTeacherId = existingPrice?.teacherId;
    String? selectedGradeLevel = existingPrice?.gradeLevel;

    final gradeLevels = ['أولى ثانوي', 'ثانية ثانوي', 'ثالثة ثانوي'];
    
    // التأكد من أن المرحلة موجودة في القائمة
    if (selectedGradeLevel != null && !gradeLevels.contains(selectedGradeLevel)) {
      selectedGradeLevel = null;
    }

    final isMonthly = _billingConfig?.isMonthly ?? false;
    final isPerSession = _billingConfig?.isPerSession ?? false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            existingPrice == null ? 'إضافة سعر جديد' : 'تعديل السعر',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // اختيار المادة من القائمة
                DropdownButtonFormField<String?>(
                  value: selectedSubjectName,
                  decoration: const InputDecoration(
                    labelText: 'المادة *',
                    prefixIcon: Icon(Icons.book),
                    border: OutlineInputBorder(),
                  ),
                  items: _subjects
                      .map(
                        (s) => DropdownMenuItem(
                          value: s.name,
                          child: Text(s.name),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() {
                    selectedSubjectName = v;
                    selectedTeacherId =
                        null; // إعادة تعيين المدرس عند تغيير المادة
                  }),
                ),
                const SizedBox(height: 16),

                // المدرس (فلترة حسب المادة المختارة)
                Builder(
                  builder: (context) {
                    // جلب المدرسين المرتبطين بالمادة المختارة
                    final selectedSubject = _subjects
                        .where((s) => s.name == selectedSubjectName)
                        .firstOrNull;
                    final subjectTeacherIds = selectedSubject?.teacherIds ?? [];
                    final filteredTeachers = subjectTeacherIds.isEmpty
                        ? _teachers // إذا لم تُختر مادة، أظهر كل المدرسين
                        : _teachers
                              .where((t) => subjectTeacherIds.contains(t.id))
                              .toList();

                    return DropdownButtonFormField<String?>(
                      value: selectedTeacherId,
                      decoration: InputDecoration(
                        labelText:
                            filteredTeachers.isEmpty &&
                                selectedSubjectName != null
                            ? 'لا يوجد مدرسين لهذه المادة'
                            : 'المدرس (اختياري)',
                        prefixIcon: const Icon(Icons.person),
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('أي مدرس'),
                        ),
                        ...filteredTeachers.map(
                          (t) => DropdownMenuItem(
                            value: t.id,
                            child: Text(t.name),
                          ),
                        ),
                      ],
                      onChanged: (v) =>
                          setDialogState(() => selectedTeacherId = v),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // المرحلة الدراسية (اختياري)
                DropdownButtonFormField<String?>(
                  value: selectedGradeLevel,
                  decoration: const InputDecoration(
                    labelText: 'المرحلة الدراسية (اختياري)',
                    prefixIcon: Icon(Icons.school),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('كل المراحل'),
                    ),
                    ...gradeLevels.map(
                      (g) => DropdownMenuItem(value: g, child: Text(g)),
                    ),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => selectedGradeLevel = v),
                ),
                const SizedBox(height: 16),

                // سعر الحصة (يظهر دائماً إلا إذا شهري فقط)
                if (!isMonthly) ...[
                  TextField(
                    controller: sessionPriceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: isPerSession ? 'سعر الحصة *' : 'سعر الحصة',
                      hintText: '50',
                      prefixIcon: const Icon(Icons.attach_money),
                      suffixText: 'ج.م',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // السعر الشهري (يظهر إذا شهري أو مختلط)
                if (isMonthly || (!isPerSession && !isMonthly)) ...[
                  TextField(
                    controller: monthlyPriceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: isMonthly
                          ? 'الاشتراك الشهري *'
                          : 'السعر الشهري (اختياري)',
                      hintText: '400',
                      prefixIcon: const Icon(Icons.calendar_month),
                      suffixText: 'ج.م',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // عدد الحصص في الشهر
                if (!isMonthly) ...[
                  TextField(
                    controller: sessionsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'عدد الحصص في الشهر',
                      hintText: '8',
                      prefixIcon: Icon(Icons.numbers),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // معاينة السعر
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      if (!isMonthly)
                        Row(
                          children: [
                            const Icon(
                              Icons.monetization_on,
                              color: Colors.green,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'الحصة: ${sessionPriceController.text.isEmpty ? '0' : sessionPriceController.text} ج.م',
                            ),
                          ],
                        ),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            color: Colors.blue,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'الشهر: ${monthlyPriceController.text.isEmpty ? _calculateMonthly(sessionPriceController.text, sessionsController.text) : monthlyPriceController.text} ج.م',
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 🧠 GENIUS: Impact Analysis Button
          actions: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton.icon(
                onPressed: () async {
                  if (selectedSubjectName == null ||
                      monthlyPriceController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('يرجى اختيار المادة وتحديد السعر'),
                      ),
                    );
                    return;
                  }

                  final newPrice =
                      double.tryParse(monthlyPriceController.text) ?? 0;
                  if (newPrice == existingPrice?.monthlyPrice) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('لم يتم تغيير السعر لتشغيل المحاكاة'),
                      ),
                    );
                    return;
                  }

                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (c) =>
                        const Center(child: CircularProgressIndicator()),
                  );

                  final repo = SettingsRepository();
                  final centerId = context.read<CenterProvider>().centerId!;

                  final impact = await repo.simulatePriceImpact(
                    centerId: centerId,
                    subjectName: selectedSubjectName!,
                    teacherId: selectedTeacherId,
                    gradeLevel: selectedGradeLevel,
                    newPrice: newPrice,
                  );

                  if (context.mounted) {
                    Navigator.of(
                      context,
                      rootNavigator: true,
                    ).pop(); // Close loading
                    _showImpactResultDialog(context, impact, newPrice);
                  }
                },
                icon: const Icon(
                  Icons.analytics_outlined,
                  color: Colors.purple,
                ),
                label: const Text('تحليل التأثير (Impact Analysis)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.purple,
                  side: const BorderSide(color: Colors.purple),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () async {
                    // التحقق حسب نظام الدفع
                    final hasSessionPrice =
                        sessionPriceController.text.isNotEmpty;
                    final hasMonthlyPrice =
                        monthlyPriceController.text.isNotEmpty;

                    if (selectedSubjectName == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('يرجى اختيار المادة')),
                      );
                      return;
                    }

                    if (isPerSession && !hasSessionPrice) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('يرجى إدخال سعر الحصة')),
                      );
                      return;
                    }

                    if (isMonthly && !hasMonthlyPrice) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('يرجى إدخال السعر الشهري'),
                        ),
                      );
                      return;
                    }

                    final repository = SettingsRepository();
                    final centerId = context.read<CenterProvider>().centerId!;

                    // 🔍 تحقق: هل المدرس مسجل في مادة أخرى؟
                    if (selectedTeacherId != null) {
                      final teacherOtherSubjects = _prices
                          .where(
                            (p) =>
                                p.teacherId == selectedTeacherId &&
                                p.subjectName != selectedSubjectName,
                          )
                          .map((p) => p.subjectName)
                          .toSet()
                          .toList();

                      if (teacherOtherSubjects.isNotEmpty) {
                        final teacher = _teachers
                            .where((t) => t.id == selectedTeacherId)
                            .firstOrNull;
                        final shouldContinue = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            icon: const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.orange,
                              size: 48,
                            ),
                            title: const Text('تنبيه'),
                            content: Text(
                              '⚠️ المدرس "${teacher?.name ?? 'غير معروف'}" مسجل بالفعل في:\n'
                              '${teacherOtherSubjects.join(', ')}\n\n'
                              'هل تريد المتابعة؟',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('إلغاء'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('متابعة'),
                              ),
                            ],
                          ),
                        );
                        if (shouldContinue != true) return;
                      }
                    }

                    // حساب السعر
                    final double sessionPrice = hasSessionPrice
                        ? double.parse(sessionPriceController.text)
                        : (hasMonthlyPrice
                              ? double.parse(monthlyPriceController.text) / 8
                              : 0.0);
                    final monthlyPrice = hasMonthlyPrice
                        ? double.parse(monthlyPriceController.text)
                        : null;

                    try {
                      await repository.upsertCoursePrice(
                        centerId: centerId,
                        subjectName: selectedSubjectName!,
                        sessionPrice: sessionPrice,
                        teacherId: selectedTeacherId,
                        gradeLevel: selectedGradeLevel,
                        sessionsPerMonth:
                            int.tryParse(sessionsController.text) ?? 8,
                        monthlyPrice: monthlyPrice,
                      );

                      if (mounted) {
                        Navigator.pop(context);
                        _loadData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم حفظ السعر بنجاح ✅')),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                    }
                  },
                  child: const Text('حفظ'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _calculateMonthly(String sessionPrice, String sessions) {
    final price = double.tryParse(sessionPrice) ?? 0;
    final count = int.tryParse(sessions) ?? 8;
    return (price * count).toStringAsFixed(0);
  }

  void _showImpactResultDialog(
    BuildContext context,
    Map<String, dynamic> impact,
    double newPrice,
  ) {
    final count = impact['impacted_invoices'] ?? 0;
    final diff = (impact['revenue_difference'] as num?)?.toDouble() ?? 0.0;
    final sample = (impact['sample_students'] as List?)?.cast<String>() ?? [];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.auto_graph, color: Colors.purple),
            SizedBox(width: 8),
            Text('محاكاة التأثير المالي'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (count == 0)
              const Text('✅ هذا التغيير لن يؤثر على أي فواتير معلقة حالياً.')
            else ...[
              Text(
                'تنبيه: هذا التغيير سيؤثر على $count فاتورة معلقة!',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: diff >= 0
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      diff >= 0 ? Icons.trending_up : Icons.trending_down,
                      color: diff >= 0 ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'فرق الإيراد المتوقع:\n${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(0)} ج.م',
                        style: TextStyle(
                          color: diff >= 0
                              ? Colors.green[700]
                              : Colors.red[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'من الطلاب المتأثرين:',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: sample
                    .map(
                      (name) => Chip(
                        label: Text(name, style: const TextStyle(fontSize: 10)),
                        backgroundColor: Colors.grey.withValues(alpha: 0.1),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('فهمت'),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePrice(CoursePrice price) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف السعر'),
        content: Text('هل تريد حذف سعر "${price.priceDescription}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () async {
              final repository = SettingsRepository();
              try {
                await repository.deleteCoursePrice(price.id);
                if (mounted) {
                  Navigator.pop(context);
                  _loadData();
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('تم الحذف')));
                }
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}


