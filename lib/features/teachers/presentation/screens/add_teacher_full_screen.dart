import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/form_validators.dart';
import '../../../../shared/models/models.dart';
import '../../data/repositories/teachers_repository.dart';
import '../../../../features/subjects/data/repositories/subjects_repository.dart';

/// شاشة إضافة معلم جديد - Full Implementation
class AddTeacherScreen extends StatefulWidget {
  const AddTeacherScreen({super.key});

  @override
  State<AddTeacherScreen> createState() => _AddTeacherScreenState();
}

class _AddTeacherScreenState extends State<AddTeacherScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // Form Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  SalaryType _selectedSalaryType = SalaryType.percentage;
  final _salaryAmountController = TextEditingController();
  final Set<String> _selectedSubjects = {};

  // Data
  List<Subject> _subjects = [];
  List<Teacher> _existingTeachers = [];
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final repo = context.read<SubjectsRepository>();
    final teachersRepo = context.read<TeachersRepository>();
    final subjects = await repo.getSubjects();
    final teachers = await teachersRepo.getTeachers();

    if (mounted) {
      setState(() {
        _subjects = subjects;
        _existingTeachers = teachers;
        _isLoadingData = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _salaryAmountController.dispose();
    super.dispose();
  }

  Future<void> _saveTeacher() async {
    if (!_formKey.currentState!.validate()) return;

    // Check for duplicates
    final isDuplicate = _existingTeachers.any(
      (t) =>
          t.name.trim().toLowerCase() ==
          _nameController.text.trim().toLowerCase(),
    );

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
      final teacher = Teacher(
        id: '',
        name: _nameController.text,
        phone: _phoneController.text,
        email: _emailController.text.isEmpty ? null : _emailController.text,
        subjectIds: _selectedSubjects.toList(),
        salaryType: _selectedSalaryType,
        salaryAmount: double.tryParse(_salaryAmountController.text) ?? 0,
        isActive: true,
        createdAt: DateTime.now(),
      );

      final repo = context.read<TeachersRepository>();
      final result = await repo.addTeacher(teacher);

      if (mounted) {
        // Show Success Dialog with Invitation Code
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => _buildSuccessDialog(
            teacherName: teacher.name,
            teacherCode: result['teacher_code'],
            phone: result['phone'],
          ),
        );

        Navigator.pop(context); // Close Screen
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
    required String teacherName,
    required String? teacherCode,
    required String? phone,
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
            'تمت إضافة المعلم بنجاح',
            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            teacherName,
            style: TextStyle(fontSize: 16.sp, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),

          // Invitation Code
          if (teacherCode != null) ...[
            _buildCodeItem(
              label: 'كود الدعوة (للانضمام)',
              code: teacherCode,
              icon: Icons.vpn_key,
              color: Colors.blue,
            ),
            const SizedBox(height: 12),
            if (phone != null)
              Text(
                'رقم الهاتف: $phone',
                style: TextStyle(fontSize: 12.sp, color: Colors.grey),
              ),
            const SizedBox(height: 12),
            Text(
              'يرجى مشاركة هذا الكود مع المعلم',
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

    if (_isLoadingData) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.pagePadding.w),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(isDark),
            const SizedBox(height: AppSpacing.xl),

            // Form Card
            Container(
              padding: EdgeInsets.all(AppSpacing.xl.w),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg.r),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name & Phone
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _nameController,
                          label: 'اسم المعلم',
                          hint: 'الاسم الكامل',
                          icon: Icons.person_outline,
                          validator: FormValidators.name,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: _buildTextField(
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

                  // Email (Optional)
                  _buildTextField(
                    controller: _emailController,
                    label: 'البريد الإلكتروني (اختياري)',
                    hint: 'example@email.com',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    isDark: isDark,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Salary Type & Amount
                  Row(
                    children: [
                      Expanded(child: _buildSalaryTypeDropdown(isDark)),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: _buildTextField(
                          controller: _salaryAmountController,
                          label: _selectedSalaryType == SalaryType.percentage
                              ? 'النسبة %'
                              : 'المبلغ (جنيه)',
                          hint: _selectedSalaryType == SalaryType.percentage
                              ? '30'
                              : '5000',
                          icon: Icons.payments_outlined,
                          keyboardType: TextInputType.number,
                          validator: (v) =>
                              v == null || v.isEmpty ? 'مطلوب' : null,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Subject Selection
                  Text(
                    'المواد التدريسية',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _subjects.map((subject) {
                      final isSelected = _selectedSubjects.contains(subject.id);
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
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.1)
                                : Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.grey,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            subject.name,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected ? AppColors.primary : null,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveTeacher,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'حفظ المعلم',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
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

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.xl.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg.r),
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
              Icons.person_add_alt_1,
              color: Colors.white,
              size: 32.sp,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'إضافة معلم جديد',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'أدخل بيانات المعلم وسيتم توليد كود الدعوة تلقائياً',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14.sp,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
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
        Text(label, style: TextStyle(fontWeight: FontWeight.w500)),
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
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSalaryTypeDropdown(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('نوع الراتب', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        DropdownButtonFormField<SalaryType>(
          value: _selectedSalaryType,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
            filled: true,
            fillColor: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide.none,
            ),
          ),
          items: const [
            DropdownMenuItem(
              value: SalaryType.percentage,
              child: Text('نسبة مئوية'),
            ),
            DropdownMenuItem(value: SalaryType.fixed, child: Text('مبلغ ثابت')),
            DropdownMenuItem(
              value: SalaryType.perSession,
              child: Text('بالحصة'),
            ),
          ],
          onChanged: (v) => setState(() => _selectedSalaryType = v!),
        ),
      ],
    );
  }
}
