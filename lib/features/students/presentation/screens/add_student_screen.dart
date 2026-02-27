import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../core/utils/form_validators.dart';
import '../../../../shared/models/models.dart';
import '../../data/repositories/students_repository.dart';
import '../../../subjects/data/repositories/subjects_repository.dart';
import '../../../teachers/data/repositories/teachers_repository.dart';

/// شاشة إضافة/تعديل طالب
class AddStudentScreen extends StatefulWidget {
  final Student? student; // الطالب المراد تعديله (اختياري)

  const AddStudentScreen({super.key, this.student});

  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isEditing = false; // هل نحن في وضع التعديل؟

  // Form Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _parentNameController = TextEditingController();
  final _parentPhoneController = TextEditingController();

  String? _selectedStage;
  DateTime? _selectedBirthDate;
  final Set<String> _selectedSubjects = {};
  String? _parentRelation;

  // Data from database
  List<Subject> _subjects = [];
  List<Teacher> _teachers = [];
  List<Student> _existingStudents = []; // For validation
  bool _isLoadingData = true;

  // Section expansion state
  bool _showParentSection = false;
  bool _showOptionalFields = false;

  // Animation
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);

    // إعداد البيانات إذا كنا في وضع التعديل
    if (widget.student != null) {
      _isEditing = true;
      _populateDataForEditing();
    }

    _loadInitialData();
    _animController.forward();
  }

  void _populateDataForEditing() {
    final s = widget.student!;
    _nameController.text = s.name;
    _phoneController.text = s.phone;
    _emailController.text = s.email ?? '';
    _addressController.text = s.address;
    _selectedStage = s.stage;
    _selectedBirthDate = s.birthDate;

    // Add previously selected subjects
    // Add previously selected subjects
    // _selectedSubjects.addAll(s.subjectIds); // Now loaded in _loadInitialData

    // نفتح الأقسام الإضافية إذا كان بها بيانات
    if (_emailController.text.isNotEmpty ||
        _addressController.text.isNotEmpty) {
      _showOptionalFields = true;
    }
  }

  Future<void> _loadInitialData() async {
    final subjectsRepo = context.read<SubjectsRepository>();
    final teachersRepo = context.read<TeachersRepository>();
    final studentsRepo = context.read<StudentsRepository>();

    // Start fetching data in parallel
    final subjectsFuture = subjectsRepo.getSubjects();
    final teachersFuture = teachersRepo.getTeachers();
    final studentsFuture = studentsRepo.getStudents();

    // If editing, fetch student's active subjects
    Future<List<String>>? studentSubjectsFuture;
    if (_isEditing && widget.student != null) {
      studentSubjectsFuture = studentsRepo.getStudentSubjectIds(
        widget.student!.id,
      );
    }

    final subjects = await subjectsFuture;
    final teachers = await teachersFuture;
    final students = await studentsFuture;
    final studentSubjectIds = studentSubjectsFuture != null
        ? await studentSubjectsFuture
        : <String>[];

    if (mounted) {
      setState(() {
        _subjects = subjects;
        _teachers = teachers;
        _existingStudents = students;
        if (studentSubjectIds.isNotEmpty) {
          _selectedSubjects.addAll(studentSubjectIds);
        }
        _isLoadingData = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _parentNameController.dispose();
    _parentPhoneController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _saveStudent() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار المرحلة الدراسية')),
      );
      return;
    }

    // Check for duplicates
    final isDuplicate = _existingStudents.any((s) {
      if (_isEditing && widget.student != null && s.id == widget.student!.id) {
        return false;
      }
      return s.name.trim().toLowerCase() ==
          _nameController.text.trim().toLowerCase();
    });

    if (isDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('هذا الاسم موجود بالفعل'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final student = Student(
        id: widget.student?.id ?? '',
        name: _nameController.text,
        phone: _phoneController.text,
        email: _emailController.text.isEmpty ? null : _emailController.text,
        address: _addressController.text,
        imageUrl: widget.student?.imageUrl,
        studentNumber: widget.student?.studentNumber,
        stage: _selectedStage!,
        birthDate: _selectedBirthDate ?? DateTime.now(),
        status: widget.student?.status ?? StudentStatus.active,
        createdAt: widget.student?.createdAt ?? DateTime.now(),
        lastAttendance: widget.student?.lastAttendance,
        subjectIds: _selectedSubjects.toList(),
      );

      final repo = context.read<StudentsRepository>();

      if (_isEditing) {
        await repo.updateStudent(student);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تحديث البيانات بنجاح ✅'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        // Add new student returns specific codes map
        debugPrint('\n${'=' * 60}');
        debugPrint('[STUDENT_FLOW] بدء عملية إضافة طالب جديد');
        debugPrint('[STUDENT_FLOW] اسم الطالب: ${student.name}');
        debugPrint('[STUDENT_FLOW] رقم الهاتف: ${student.phone}');
        debugPrint('[STUDENT_FLOW] المرحلة: ${student.stage}');
        debugPrint('${'=' * 60}\n');

        final result = await repo.addStudent(student);

        debugPrint('\n${'=' * 60}');
        debugPrint('[STUDENT_FLOW] ✅ تمت إضافة الطالب بنجاح!');
        debugPrint('[STUDENT_FLOW] النتيجة المرجعة:');
        debugPrint(
          '[STUDENT_FLOW]   - student_code: ${result['student_code']}',
        );
        debugPrint('[STUDENT_FLOW]   - parent_code: ${result['parent_code']}');
        debugPrint('[STUDENT_FLOW]   - student_id: ${result['student_id']}');
        debugPrint('${'=' * 60}\n');

        if (mounted) {
          debugPrint('[STUDENT_UI] جاري عرض ديالوج أكواد الطالب');
          debugPrint(
            '[STUDENT_UI]   - student_code: ${result['student_code']}',
          );
          debugPrint('[STUDENT_UI]   - parent_code: ${result['parent_code']}');

          // Show Success Dialog with Codes
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => _buildSuccessDialog(
              studentName: student.name,
              studentCode: result['student_code'],
              parentCode: result['parent_code'],
            ),
          );

          Navigator.pop(context); // Close Screen after dialog is closed
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildSuccessDialog({
    required String studentName,
    required String? studentCode,
    required String? parentCode,
  }) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      contentPadding: const EdgeInsets.all(24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: Color(0xFF10B981),
              size: 48,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'تمت إضافة الطالب بنجاح',
            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            studentName,
            style: TextStyle(fontSize: 16.sp, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),

          // Codes Section
          if (studentCode != null && parentCode != null) ...[
            _buildCodeItem(
              label: 'كود الطالب (للدخول)',
              code: studentCode,
              icon: Icons.person,
              color: Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildCodeItem(
              label: 'كود ولي الأمر (للدعوة)',
              code: parentCode,
              icon: Icons.family_restroom,
              color: Colors.orange,
            ),
            const SizedBox(height: 24),
            Text(
              'يرجى مشاركة هذه الأكواد مع الطالب وولي الأمر',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'تم',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCodeItem({
    required String label,
    required String code,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                ),
                SelectableText(
                  code,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 20, color: Colors.grey),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('تم نسخ الكود')));
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final padding = ResponsiveUtils.getPagePadding(context);

    if (_isLoadingData) {
      return const Center(child: CircularProgressIndicator());
    }

    return FadeTransition(
      opacity: _fadeAnim,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(AppSpacing.pagePadding.w),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Premium Header
              _buildPremiumHeader(context, isDark),

              const SizedBox(height: AppSpacing.xl),

              // Main Content - Two Column Layout
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column - Form
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        // Essential Info Card
                        _buildEssentialInfoCard(isDark),

                        const SizedBox(height: AppSpacing.lg),

                        // Subject Selection Card
                        _buildSubjectSelectionCard(isDark),

                        const SizedBox(height: AppSpacing.lg),

                        // Optional: Parent Info (Collapsible)
                        _buildParentInfoCard(isDark),

                        const SizedBox(height: AppSpacing.lg),

                        // Optional Fields (Collapsible)
                        _buildOptionalFieldsCard(isDark),
                      ],
                    ),
                  ),

                  const SizedBox(width: AppSpacing.xl),

                  // Right Column - Live Summary
                  Expanded(flex: 1, child: _buildLiveSummary(isDark)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumHeader(BuildContext context, bool isDark) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.xl.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(AppSpacing.md.w),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r),
            ),
            child: Icon(
              _isEditing ? Icons.edit_note : Icons.person_add_alt_1,
              color: Colors.white,
              size: 32.sp,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEditing ? 'تعديل بيانات الطالب' : 'إضافة طالب جديد',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _isEditing
                    ? 'تحديث المعلومات الشخصية والبيانات الأساسية'
                    : 'أدخل بيانات الطالب لإضافته للنظام',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14.sp,
                ),
              ),
            ],
          ),
          const Spacer(), // Added Spacer to push the next icon to the end
          // Quick Tips Icon
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: const Icon(Icons.lightbulb_outline, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildEssentialInfoCard(bool isDark) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.xl.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg.r),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: const Icon(Icons.person_add, color: Color(0xFF6366F1)),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                'البيانات الأساسية',
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'مطلوب',
                  style: TextStyle(color: AppColors.error, fontSize: 12.sp),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),

          // Name & Phone Row
          Row(
            children: [
              Expanded(
                child: _buildPremiumTextField(
                  controller: _nameController,
                  label: 'اسم الطالب',
                  hint: 'أدخل الاسم الثلاثي',
                  icon: Icons.person_outline,
                  validator: FormValidators.name,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: _buildPremiumTextField(
                  controller: _phoneController,
                  label: 'رقم الهاتف',
                  hint: '01XXXXXXXXX',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: FormValidators.phone,
                  isDark: isDark,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // Stage & Birthdate Row
          Row(
            children: [
              Expanded(
                child: _buildPremiumDropdown(
                  value: _selectedStage,
                  label: 'المرحلة الدراسية',
                  icon: Icons.school_outlined,
                  items: FormUtils.stages,
                  onChanged: (v) => setState(() => _selectedStage = v),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(child: _buildDatePicker(isDark)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white70 : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon),
            filled: true,
            fillColor: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumDropdown({
    required String? value,
    required String label,
    required IconData icon,
    required List<String> items,
    required Function(String?) onChanged,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white70 : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            prefixIcon: Icon(icon),
            filled: true,
            fillColor: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
          ),
          items: items
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: onChanged,
          validator: (v) => v == null ? 'مطلوب' : null,
        ),
      ],
    );
  }

  Widget _buildDatePicker(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'تاريخ الميلاد',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white70 : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedBirthDate ?? DateTime(2010),
              firstDate: DateTime(1990),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              setState(() => _selectedBirthDate = picked);
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 16.h),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined),
                const SizedBox(width: 12),
                Text(
                  _selectedBirthDate != null
                      ? '${_selectedBirthDate!.day}/${_selectedBirthDate!.month}/${_selectedBirthDate!.year}'
                      : 'اختر التاريخ',
                  style: TextStyle(
                    color: _selectedBirthDate != null
                        ? null
                        : (isDark ? Colors.white54 : Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectSelectionCard(bool isDark) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.xl.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg.r),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: const Icon(Icons.menu_book, color: Color(0xFF10B981)),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                'اختيار المواد',
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (_selectedSubjects.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_selectedSubjects.length} مادة',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // Subject Chips Grid
          if (_subjects.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 12),
                    const Text('لا توجد مواد متاحة'),
                  ],
                ),
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _subjects.map((subject) {
                final isSelected = _selectedSubjects.contains(subject.id);
                final color = _getSubjectColor(subject.id);

                return InkWell(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedSubjects.remove(subject.id);
                      } else {
                        _selectedSubjects.add(subject.id);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withValues(alpha: 0.15)
                          : (isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.grey.withValues(alpha: 0.08)),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: isSelected
                            ? color
                            : (isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.white,
                            ),
                          )
                        else
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              shape: BoxShape.circle,
                            ),
                          ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subject.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isSelected ? color : null,
                              ),
                            ),
                            // السعر يُحدد من جدول الأسعار الذكي
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Color _getSubjectColor(String id) {
    const colors = [
      Color(0xFF6366F1),
      Color(0xFFEC4899),
      Color(0xFF14B8A6),
      Color(0xFFF59E0B),
      Color(0xFF8B5CF6),
      Color(0xFF06B6D4),
    ];
    return colors[id.hashCode.abs() % colors.length];
  }

  Widget _buildParentInfoCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        children: [
          // Collapsible Header
          InkWell(
            onTap: () =>
                setState(() => _showParentSection = !_showParentSection),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.family_restroom,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  const Expanded(
                    child: Text(
                      'بيانات ولي الأمر',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'اختياري',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _showParentSection
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                  ),
                ],
              ),
            ),
          ),

          // Expandable Content
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: _showParentSection
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.xl,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildPremiumTextField(
                          controller: _parentNameController,
                          label: 'اسم ولي الأمر',
                          hint: 'الاسم الكامل',
                          icon: Icons.person_outline,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: _buildPremiumTextField(
                          controller: _parentPhoneController,
                          label: 'رقم الهاتف',
                          hint: '01XXXXXXXXX',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _buildPremiumDropdown(
                    value: _parentRelation,
                    label: 'صلة القرابة',
                    icon: Icons.family_restroom,
                    items: FormUtils.relations,
                    onChanged: (v) => setState(() => _parentRelation = v),
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionalFieldsCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        children: [
          // Collapsible Header
          InkWell(
            onTap: () =>
                setState(() => _showOptionalFields = !_showOptionalFields),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.more_horiz, color: Colors.grey),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  const Expanded(
                    child: Text(
                      'بيانات إضافية',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    _showOptionalFields
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                  ),
                ],
              ),
            ),
          ),

          // Expandable Content
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: _showOptionalFields
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.xl,
              ),
              child: Column(
                children: [
                  _buildPremiumTextField(
                    controller: _emailController,
                    label: 'البريد الإلكتروني',
                    hint: 'example@email.com',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    isDark: isDark,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _buildPremiumTextField(
                    controller: _addressController,
                    label: 'العنوان',
                    hint: 'المدينة - المنطقة',
                    icon: Icons.location_on_outlined,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveSummary(bool isDark) {
    // السعر يُحسب من نظام التسعير الذكي
    final selectedCount = _selectedSubjects.length;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ملخص التسجيل',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const Divider(height: 24),

          // Student Name
          _buildSummaryItem(
            icon: Icons.person,
            label: 'الطالب',
            value: _nameController.text.isEmpty ? '—' : _nameController.text,
            isDark: isDark,
          ),

          // Stage
          _buildSummaryItem(
            icon: Icons.school,
            label: 'المرحلة',
            value: _selectedStage ?? '—',
            isDark: isDark,
          ),

          // Subjects
          _buildSummaryItem(
            icon: Icons.menu_book,
            label: 'المواد',
            value: _selectedSubjects.isEmpty
                ? '—'
                : '${_selectedSubjects.length} مادة',
            isDark: isDark,
          ),

          const Divider(height: 24),

          // Total Fees
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF6366F1).withValues(alpha: 0.1),
                  const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'المواد المختارة',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '$selectedCount مادة',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6366F1),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Save Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline),
                        SizedBox(width: 8),
                        Text(
                          'حفظ الطالب',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600]),
          ),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _handleSave() async {
    // Validate required fields
    if (_nameController.text.isEmpty) {
      _showError('يرجى إدخال اسم الطالب');
      return;
    }
    if (_phoneController.text.isEmpty ||
        FormValidators.phone(_phoneController.text) != null) {
      _showError('يرجى إدخال رقم هاتف صالح');
      return;
    }
    if (_selectedStage == null) {
      _showError('يرجى اختيار المرحلة الدراسية');
      return;
    }

    setState(() => _isSaving = true);

    try {
      const uuid = Uuid();
      final newStudent = Student(
        id: uuid.v4(),
        name: _nameController.text,
        phone: _phoneController.text,
        email: _emailController.text.isEmpty ? null : _emailController.text,
        birthDate: _selectedBirthDate ?? DateTime.now(),
        address: _addressController.text,
        stage: _selectedStage!,
        subjectIds: _selectedSubjects.toList(),
        status: StudentStatus.active,
        createdAt: DateTime.now(),
        studentNumber: 'STD${DateTime.now().millisecondsSinceEpoch}',
      );

      debugPrint('\n${'=' * 60}');
      debugPrint('[STUDENT_FLOW] بدء عملية إضافة طالب جديد (handleSave)');
      debugPrint('[STUDENT_FLOW] اسم الطالب: ${newStudent.name}');
      debugPrint('[STUDENT_FLOW] رقم الهاتف: ${newStudent.phone}');
      debugPrint('[STUDENT_FLOW] المرحلة: ${newStudent.stage}');
      debugPrint('${'=' * 60}\n');

      // حفظ الطالب والحصول على أكواد الدعوة
      final repository = StudentsRepository();
      final result = await repository.addStudent(newStudent);

      debugPrint('\n${'=' * 60}');
      debugPrint('[STUDENT_FLOW] ✅ تمت إضافة الطالب بنجاح!');
      debugPrint('[STUDENT_FLOW] النتيجة المرجعة:');
      debugPrint('[STUDENT_FLOW]   - student_code: ${result['student_code']}');
      debugPrint('[STUDENT_FLOW]   - parent_code: ${result['parent_code']}');
      debugPrint('[STUDENT_FLOW]   - student_id: ${result['student_id']}');
      debugPrint('${'=' * 60}\n');

      List<Map<String, dynamic>> allocations = [];
      if (_selectedSubjects.isNotEmpty) {
        allocations = await context
            .read<StudentsRepository>()
            .updateStudentSubjects(newStudent.id, _selectedSubjects.toList());
      }

      if (!mounted) return;

      // Show Allocation Report if applicable
      if (allocations.isNotEmpty) {
        await _showAllocationReportDialog(allocations);
      }

      // عرض Dialog بأكواد الدعوة الحقيقية
      if (mounted) {
        debugPrint('[STUDENT_UI] جاري عرض ديالوج أكواد الطالب (handleSave)');
        debugPrint('[STUDENT_UI]   - student_code: ${result['student_code']}');
        debugPrint('[STUDENT_UI]   - parent_code: ${result['parent_code']}');

        await _showInvitationCodeDialog(
          newStudent,
          studentCode: result['student_code'],
          parentCode: result['parent_code'],
        );
      }

      if (!mounted) return;
      context.go('/students');
    } catch (e) {
      debugPrint('[STUDENT_FLOW] ❌ خطأ في إضافة الطالب: $e');
      if (!mounted) return;
      _showError('خطأ في حفظ البيانات: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// عرض أكواد الدعوة للطالب وولي الأمر
  Future<void> _showInvitationCodeDialog(
    Student student, {
    String? studentCode,
    String? parentCode,
  }) async {
    debugPrint(
      '[INVITATION_CODE] عرض ديالوج أكواد الدعوة للطالب: ${student.name}',
    );
    debugPrint('[INVITATION_CODE] كود الطالب: $studentCode');
    debugPrint('[INVITATION_CODE] كود ولي الأمر: $parentCode');

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success Header
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  size: 50,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'تم تسجيل الطالب بنجاح!',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 8),
              Text(student.name, style: Theme.of(ctx).textTheme.bodyLarge),

              const SizedBox(height: 24),

              // أكواد الدعوة
              if (studentCode != null && parentCode != null) ...[
                // كود الطالب
                _buildInvitationCodeBox(
                  ctx: ctx,
                  label: '📱 كود الطالب (للدخول)',
                  code: studentCode,
                  icon: Icons.person,
                  color: Colors.blue,
                ),
                const SizedBox(height: 16),
                // كود ولي الأمر
                _buildInvitationCodeBox(
                  ctx: ctx,
                  label: '👨‍👩‍👧 كود ولي الأمر (للدعوة)',
                  code: parentCode,
                  icon: Icons.family_restroom,
                  color: Colors.orange,
                ),
              ] else ...[
                // في حالة عدم وجود أكواد، عرض QR code
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '📱 كود الدعوة لتطبيق الطالب',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      QrImageView(
                        data: student.id,
                        version: QrVersions.auto,
                        size: 180,
                        backgroundColor: Colors.white,
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              Text(
                'يرجى مشاركة هذه الأكواد مع الطالب وولي الأمر',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // Close Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('تم - الذهاب لقائمة الطلاب'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// عنصر عرض كود الدعوة مع زر النسخ
  Widget _buildInvitationCodeBox({
    required BuildContext ctx,
    required String label,
    required String code,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SelectableText(
                  code,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: Icon(Icons.copy, size: 20, color: color),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text('تم نسخ الكود: $code'),
                        duration: const Duration(seconds: 2),
                        backgroundColor: color,
                      ),
                    );
                  },
                  tooltip: 'نسخ الكود',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _showAllocationReportDialog(
    List<Map<String, dynamic>> allocations,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.purple),
            SizedBox(width: 8),
            Text('تقرير التوزيع الذكي'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'بناءً على خوارزمية "الموفر الذكي"، تم توزيع الطالب كالتالي:',
              ),
              const SizedBox(height: 16),
              ...allocations.map((alloc) {
                final isAssigned = alloc['status'] == 'assigned';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isAssigned
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isAssigned
                          ? Colors.green.withValues(alpha: 0.3)
                          : Colors.red.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isAssigned ? Icons.check_circle : Icons.error,
                        color: isAssigned ? Colors.green : Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              alloc['course_name'] ?? 'مادة غير معروفة',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isAssigned)
                              Text(
                                'تم التسكين في: ${alloc['group_name']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              )
                            else
                              Text(
                                'فشل التسكين: ${alloc['reason'] == 'No suitable group found (Conflict or Full)' ? 'لا توجد مجموعة مناسبة (تعارض أو اكتمال)' : alloc['reason']}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.red,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('متابعة'),
          ),
        ],
      ),
    );
  }
}

/// Form Utils Helper
class FormUtils {
  static const stages = [
    'الصف الأول الثانوي',
    'الصف الثاني الثانوي',
    'الصف الثالث الثانوي',
  ];

  static const relations = ['الأب', 'الأم', 'الأخ/الأخت', 'آخر'];
}
