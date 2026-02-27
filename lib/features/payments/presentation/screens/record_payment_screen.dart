/// Modern Record Payment Screen - EdSentre
/// واجهة تسجيل دفعة محسّنة مع UI مودرن
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/center_provider.dart';
import '../../../../shared/models/models.dart';
import '../widgets/smart_payment_item_card.dart';
import '../../data/repositories/payment_repository.dart';
import '../../../students/data/repositories/students_repository.dart';
import '../../../students/presentation/screens/smart_invoice_screen.dart';

class RecordPaymentScreen extends StatefulWidget {
  final Student?
  student; // Renamed from studentId to object for checks, but router passes studentId usually
  final String? studentId;

  const RecordPaymentScreen({super.key, this.student, this.studentId});

  @override
  State<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends State<RecordPaymentScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;

  // Data State
  Student? _selectedStudent;
  List<Map<String, dynamic>> _studentSubjects =
      []; // {id, name, teacher_id, etc}
  List<Map<String, dynamic>> _studentSessions =
      []; // {id, date, status, subject_id}

  // Form State
  List<PaymentItem> _items = [];
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  final TextEditingController _notesController = TextEditingController();

  bool _isLoading = false;
  final bool _isFetchingDetails = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();

    // Add initial item
    _addItem();

    if (widget.student != null) {
      _onStudentSelected(widget.student);
    }
    // If studentId passed, would typically fetch student object here
  }

  void _addItem() {
    PaymentItemType? defaultType;
    if (mounted) {
      // Ensure default type matches allowed types
      try {
        final allowed = _getAllowedTypes();
        defaultType = allowed.contains(PaymentItemType.session)
            ? PaymentItemType.session
            : allowed.first;
      } catch (_) {}
    }

    setState(() {
      _items.add(
        PaymentItem.empty().copyWith(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          createdAt: DateTime.now(),
          itemType: defaultType, // Force correct type
        ),
      );
    });
  }

  void _removeItem(int index) {
    if (_items.length > 1) {
      setState(() {
        _items.removeAt(index);
      });
    }
  }

  void _updateItem(int index, PaymentItem newItem) {
    setState(() {
      _items[index] = newItem;
    });
  }

  // Fetch Student Context (Subjects, Teachers, Unpaid Sessions)
  Future<void> _onStudentSelected(Student? student) async {
    if (student == null) {
      setState(() {
        _selectedStudent = null;
        _studentSubjects = [];
        _studentSessions = [];
      });
      return;
    }

    setState(() {
      _selectedStudent = student;
      _studentSubjects = [];
      _studentSessions = [];
    });

    // IMMEDIATE REDIRECT TO SMART INVOICE
    if (mounted) {
      // Use push() to avoid "Page-based route" assertion error
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SmartInvoiceScreen(
            studentId: student.id,
            studentName: student.name,
          ),
        ),
      );

      // WHEN RETURNED: Clear selection to reset UI
      if (mounted) {
        setState(() {
          _selectedStudent = null;
          _items = [];
          _addItem(); // Add fresh empty item
          _paymentMethod = PaymentMethod.cash; // Reset method
          _notesController.clear();
        });
      }
    }
  }

  // Deprecated: Old fetching logic removed as we redirect now.
  /*
    setState(() => _isFetchingDetails = true);
    // ... old logic ...
  */

  @override
  void dispose() {
    _animationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// 🔍 Smart Student Picker - بحث ذكي للطلاب
  Future<void> _showSmartStudentPicker() async {
    final result = await showDialog<Student>(
      context: context,
      builder: (context) => _SmartStudentPickerDialog(
        centerId: context.read<CenterProvider>().centerId ?? '',
      ),
    );

    if (result != null) {
      _onStudentSelected(result);
    }
  }

  double get _totalAmount => _items.fold(0.0, (sum, item) => sum + item.amount);

  // Helper to get allowed items
  List<PaymentItemType> _getAllowedTypes() {
    try {
      final billingConfig = context.read<CenterProvider>().billingConfig;
      if (billingConfig.isPerSession) return [PaymentItemType.session];
      if (billingConfig.isMonthly) return [PaymentItemType.monthlySubscription];
      return PaymentItemType.values.toList();
    } catch (_) {
      return PaymentItemType.values.toList();
    }
  }

  Future<void> _recordPayment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء اختيار الطالب'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final centerId = context.read<CenterProvider>().centerId;
      if (centerId == null || centerId.isEmpty) {
        throw Exception('خطأ: لم يتم تحديد المركز الحالي');
      }

      final repository = context.read<PaymentRepository>();

      await repository.recordComplexPayment(
        studentId: _selectedStudent!.id,
        totalAmount: _totalAmount,
        method: _paymentMethod.name,
        items: _items,
        notes: _notesController.text,
      );

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                'تم تسجيل الدفعة بنجاح (${_totalAmount.toStringAsFixed(2)} ج)',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // جلب إعدادات نظام الدفع من CenterProvider
    final centerProvider = context.watch<CenterProvider>();
    final billingConfig = centerProvider.billingConfig;
    final isPerSession = billingConfig.isPerSession;
    final isMonthly = billingConfig.isMonthly;
    final isMixed = billingConfig.isMixed;

    // تحديد العنوان حسب النظام
    String screenTitle;
    IconData screenIcon;
    Color screenColor;

    if (isPerSession) {
      screenTitle = '💳 شراء حصص';
      screenIcon = Icons.confirmation_number;
      screenColor = Colors.orange;
    } else if (isMonthly) {
      screenTitle = '📅 دفع الشهر';
      screenIcon = Icons.calendar_month;
      screenColor = Colors.deepPurple;
    } else {
      screenTitle = '💰 تسجيل دفعة';
      screenIcon = Icons.payment;
      screenColor = Colors.green;
    }

    // Filter available types based on billing system
    List<PaymentItemType> availableTypes;
    if (isPerSession) {
      availableTypes = [PaymentItemType.session]; // فقط الحصص
    } else if (isMonthly) {
      availableTypes = [PaymentItemType.monthlySubscription]; // فقط الشهري
    } else {
      // مختلط أو غير محدد - كل الأنواع
      availableTypes = PaymentItemType.values.toList();
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Modern App Bar with Gradient
          SliverAppBar.large(
            expandedHeight: 160,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                screenTitle,
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            screenColor.withValues(alpha: 0.9),
                            screenColor.withValues(alpha: 0.7),
                          ]
                        : [screenColor.withValues(alpha: 0.7), screenColor],
                  ),
                ),
                child: Center(
                  child: Icon(
                    screenIcon,
                    size: 60,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _recordPayment,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded),
                  label: const Text('حفظ'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.deepPurple.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Content
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Student Selection
                      _buildStudentSelector(),

                      const SizedBox(height: 24),

                      if (_selectedStudent != null) ...[
                        if (_isFetchingDetails) const LinearProgressIndicator(),
                        const SizedBox(height: 20),

                        // Smart Items List
                        _buildSmartItemsList(availableTypes),
                      ],

                      const SizedBox(height: 24),

                      // Payment Details Section
                      _buildPaymentDetailsSection(),

                      const SizedBox(height: 32),

                      // Total Amount Card
                      _buildTotalAmountCard(),

                      const SizedBox(height: 100), // Space for bottom bar
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),

      // Floating Total Bar at bottom
      bottomNavigationBar: _buildBottomTotalBar(),
    );
  }

  Widget _buildStudentSelector() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    color: Colors.deepPurple.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'الطالب',
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Student dropdown or autocomplete
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.deepPurple.shade100,
                  child: _selectedStudent != null
                      ? Text(
                          _selectedStudent!.name.isNotEmpty
                              ? _selectedStudent!.name[0]
                              : '?',
                          style: TextStyle(
                            color: Colors.deepPurple.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : Icon(
                          Icons.search_rounded,
                          color: Colors.deepPurple.shade700,
                        ),
                ),
                title: Text(
                  _selectedStudent?.name ?? 'اختر الطالب',
                  style: GoogleFonts.cairo(
                    fontWeight: _selectedStudent != null
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                subtitle: _selectedStudent != null
                    ? Text(
                        'طالب',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      )
                    : null,
                trailing: const Icon(Icons.arrow_drop_down_rounded),
                onTap: _showSmartStudentPicker,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartItemsList(List<PaymentItemType> availableTypes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.receipt_long_rounded,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '1. بنود الدفعة',
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            FilledButton.tonalIcon(
              onPressed: _addItem,
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة بند'),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        if (_items.isEmpty)
          const Center(child: Text('اضغط على "إضافة بند" للبدء')),

        ..._items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return SmartPaymentItemCard(
            item: item,
            student:
                _selectedStudent ??
                Student(
                  id: 'dummy',
                  name: '',
                  createdAt: DateTime.now(),
                  phone: '',
                  address: '',
                  stage: '',
                  subjectIds: [],
                  status: StudentStatus.active,
                  birthDate: DateTime.now(),
                ),
            availableTypes: availableTypes,
            onUpdate: (newItem) => _updateItem(i, newItem),
            onRemove: () => _removeItem(i),
            enrolledSubjects: _studentSubjects,
            sessions: _studentSessions,
            isCompact: false,
          );
        }),
      ],
    );
  }

  Widget _buildPaymentDetailsSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<PaymentMethod>(
              value: _paymentMethod,
              decoration: const InputDecoration(labelText: 'طريقة الدفع'),
              items: PaymentMethod.values
                  .map(
                    (m) =>
                        DropdownMenuItem(value: m, child: Text(m.arabicName)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _paymentMethod = v!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'ملاحظات عامة على الفاتورة',
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalAmountCard() {
    return Container();
  }

  Widget _buildBottomTotalBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الإجمالي المطلوب',
                  style: GoogleFonts.cairo(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${_totalAmount.toStringAsFixed(2)} ج.م',
                  style: GoogleFonts.cairo(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: 160,
              height: 56,
              child: FilledButton(
                onPressed: _isLoading ? null : _recordPayment,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'دفع الآن',
                        style: GoogleFonts.cairo(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 🔍 Smart Student Picker Dialog
// ═══════════════════════════════════════════════════════════════════════════
//
// Features:
// - بحث فوري بالاسم أو رقم الهاتف
// - فلترة حسب المرحلة الدراسية
// - عرض حالة المديونية
// - أداء عالي مع 1000+ طالب
// ═══════════════════════════════════════════════════════════════════════════

class _SmartStudentPickerDialog extends StatefulWidget {
  final String centerId;

  const _SmartStudentPickerDialog({required this.centerId});

  @override
  State<_SmartStudentPickerDialog> createState() =>
      _SmartStudentPickerDialogState();
}

class _SmartStudentPickerDialogState extends State<_SmartStudentPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  List<Student> _allStudents = [];
  List<Student> _filteredStudents = [];
  String? _selectedStage;
  bool _isLoading = true;
  String? _error;

  // Stage options for filter
  final List<String> _stages = [
    'الصف الأول الابتدائي',
    'الصف الثاني الابتدائي',
    'الصف الثالث الابتدائي',
    'الصف الرابع الابتدائي',
    'الصف الخامس الابتدائي',
    'الصف السادس الابتدائي',
    'الصف الأول الإعدادي',
    'الصف الثاني الإعدادي',
    'الصف الثالث الإعدادي',
    'الصف الأول الثانوي',
    'الصف الثاني الثانوي',
    'الصف الثالث الثانوي',
  ];

  @override
  void initState() {
    super.initState();
    _loadStudents();
    // Auto-focus on search
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Use the Repository (Lightning Fast RPC + Fallback)
      final repository = context.read<StudentsRepository>();
      final students = await repository.getStudents(
        limit: 1000, // Load enough students for the picker
        searchQuery: '', // Load all initially
      );

      if (mounted) {
        setState(() {
          _allStudents = students;
          _filteredStudents = students;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading students: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _filterStudents(String query) {
    setState(() {
      _filteredStudents = _allStudents.where((student) {
        // Search by name or phone
        final matchesSearch =
            query.isEmpty ||
            student.name.toLowerCase().contains(query.toLowerCase()) ||
            student.phone.contains(query);

        // Filter by stage
        final matchesStage =
            _selectedStage == null || student.stage == _selectedStage;

        return matchesSearch && matchesStage;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 500,
        height: 600,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.person_search,
                    color: Colors.deepPurple.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'اختر الطالب',
                    style: GoogleFonts.cairo(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 🔍 Search Bar
            TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم أو رقم الهاتف...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterStudents('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              onChanged: _filterStudents,
            ),

            const SizedBox(height: 12),

            // Stage Filter Chips
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  FilterChip(
                    label: const Text('الكل'),
                    selected: _selectedStage == null,
                    onSelected: (_) {
                      setState(() => _selectedStage = null);
                      _filterStudents(_searchController.text);
                    },
                  ),
                  const SizedBox(width: 8),
                  ..._stages
                      .where(
                        (stage) => _allStudents.any((s) => s.stage == stage),
                      )
                      .map(
                        (stage) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(stage.replaceFirst('الصف ', '')),
                            selected: _selectedStage == stage,
                            onSelected: (_) {
                              setState(() {
                                _selectedStage = _selectedStage == stage
                                    ? null
                                    : stage;
                              });
                              _filterStudents(_searchController.text);
                            },
                          ),
                        ),
                      ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Results count
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Text(
                    '${_filteredStudents.length} طالب',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_selectedStage != null) ...[
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(_selectedStage!.replaceFirst('الصف ', '')),
                      onDeleted: () {
                        setState(() => _selectedStage = null);
                        _filterStudents(_searchController.text);
                      },
                      deleteIcon: const Icon(Icons.close, size: 16),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 8),
            const Divider(height: 1),

            // Students List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 12),
                          Text('حدث خطأ: $_error'),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _loadStudents,
                            icon: const Icon(Icons.refresh),
                            label: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ),
                    )
                  : _filteredStudents.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _searchController.text.isNotEmpty
                                ? 'لا توجد نتائج للبحث'
                                : 'لا يوجد طلاب',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredStudents.length,
                      itemBuilder: (context, index) {
                        final student = _filteredStudents[index];
                        return _StudentListTile(
                          student: student,
                          onTap: () => Navigator.pop(context, student),
                          searchQuery: _searchController.text,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Student List Tile with highlighted search
class _StudentListTile extends StatelessWidget {
  final Student student;
  final VoidCallback onTap;
  final String searchQuery;

  const _StudentListTile({
    required this.student,
    required this.onTap,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.deepPurple.shade100,
        child: Text(
          student.name.isNotEmpty ? student.name[0] : '?',
          style: TextStyle(
            color: Colors.deepPurple.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: _buildHighlightedText(student.name, searchQuery, theme),
      subtitle: Row(
        children: [
          if (student.phone.isNotEmpty) ...[
            Icon(Icons.phone, size: 14, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(
              student.phone,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(width: 12),
          ],
          if (student.stage.isNotEmpty) ...[
            Icon(Icons.school, size: 14, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                student.stage.replaceFirst('الصف ', ''),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.grey.shade400,
      ),
      onTap: onTap,
    );
  }

  Widget _buildHighlightedText(String text, String query, ThemeData theme) {
    if (query.isEmpty) {
      return Text(text, style: const TextStyle(fontWeight: FontWeight.w600));
    }

    final lowercaseText = text.toLowerCase();
    final lowercaseQuery = query.toLowerCase();
    final startIndex = lowercaseText.indexOf(lowercaseQuery);

    if (startIndex == -1) {
      return Text(text, style: const TextStyle(fontWeight: FontWeight.w600));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        children: [
          TextSpan(text: text.substring(0, startIndex)),
          TextSpan(
            text: text.substring(startIndex, startIndex + query.length),
            style: TextStyle(
              backgroundColor: Colors.yellow.shade200,
              color: Colors.black,
            ),
          ),
          TextSpan(text: text.substring(startIndex + query.length)),
        ],
      ),
    );
  }
}


