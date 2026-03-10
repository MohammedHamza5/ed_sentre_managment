/// Export Students Screen - EdSentre
/// شاشة تصدير بيانات الطلاب بصيغ متعددة
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../shared/models/models.dart';
import '../../../../core/constants/educational_consts.dart';

enum ExportFormat { pdf, excel, csv }

class ExportStudentsScreen extends StatefulWidget {
  final List<Student>? preSelectedStudents;

  const ExportStudentsScreen({super.key, this.preSelectedStudents});

  @override
  State<ExportStudentsScreen> createState() => _ExportStudentsScreenState();
}

class _ExportStudentsScreenState extends State<ExportStudentsScreen> {
  ExportFormat _selectedFormat = ExportFormat.pdf;
  bool _isLoading = false;

  // Filters
  String? _selectedGrade;
  StudentStatus? _selectedStatus;
  bool _includePhone = true;
  bool _includeEmail = true;
  bool _includeBirthDate = true;
  bool _includeAddress = true;
  bool _includeSubjects = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Modern App Bar
          SliverAppBar.large(
            expandedHeight: 160,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'تصدير بيانات الطلاب',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [Colors.indigo.shade900, Colors.indigo.shade700]
                        : [Colors.indigo.shade400, Colors.indigo.shade600],
                  ),
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Format Selection
                  _buildFormatSelection(),

                  const SizedBox(height: 24),

                  // Filters
                  _buildFiltersSection(),

                  const SizedBox(height: 24),

                  // Fields Selection
                  _buildFieldsSelection(),

                  const SizedBox(height: 32),

                  // Export Button
                  _buildExportButton(),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatSelection() {
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
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.file_download_rounded,
                    color: Colors.indigo.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'صيغة التصدير',
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Format Options
            Row(
              children: [
                Expanded(
                  child: _buildFormatOption(
                    format: ExportFormat.pdf,
                    icon: Icons.picture_as_pdf_rounded,
                    label: 'PDF',
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildFormatOption(
                    format: ExportFormat.excel,
                    icon: Icons.table_chart_rounded,
                    label: 'Excel',
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildFormatOption(
                    format: ExportFormat.csv,
                    icon: Icons.description_rounded,
                    label: 'CSV',
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatOption({
    required ExportFormat format,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final isSelected = _selectedFormat == format;

    return InkWell(
      onTap: () => setState(() => _selectedFormat = format),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.1)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.cairo(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersSection() {
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
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.filter_list_rounded,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'الفلاتر',
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Grade Filter
            DropdownButtonFormField<String>(
              value: _selectedGrade,
              decoration: InputDecoration(
                labelText: 'المرحلة الدراسية',
                prefixIcon: const Icon(Icons.school_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('الكل')),
                ...EducationalStages.allGrades.map(
                  (grade) => DropdownMenuItem(value: grade, child: Text(grade)),
                ),
              ],
              onChanged: (value) => setState(() => _selectedGrade = value),
            ),

            const SizedBox(height: 12),

            // Status Filter
            DropdownButtonFormField<StudentStatus>(
              value: _selectedStatus,
              decoration: InputDecoration(
                labelText: 'الحالة',
                prefixIcon: const Icon(Icons.flag_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('الكل')),
                DropdownMenuItem(
                  value: StudentStatus.active,
                  child: Text('نشط'),
                ),
                DropdownMenuItem(
                  value: StudentStatus.inactive,
                  child: Text('غير نشط'),
                ),
                DropdownMenuItem(
                  value: StudentStatus.suspended,
                  child: Text('موقوف'),
                ),
                DropdownMenuItem(
                  value: StudentStatus.overdue,
                  child: Text('متأخر'),
                ),
              ],
              onChanged: (value) => setState(() => _selectedStatus = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldsSelection() {
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
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.checklist_rounded,
                    color: Colors.purple.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'الحقول المطلوبة',
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Always included: Name, ID
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_rounded,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'مضمنة دائماً: الاسم، رقم الطالب',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Optional Fields
            CheckboxListTile(
              value: _includePhone,
              onChanged: (value) => setState(() => _includePhone = value!),
              title: const Text('رقم الهاتف'),
              controlAffinity: ListTileControlAffinity.leading,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            CheckboxListTile(
              value: _includeEmail,
              onChanged: (value) => setState(() => _includeEmail = value!),
              title: const Text('البريد الإلكتروني'),
              controlAffinity: ListTileControlAffinity.leading,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            CheckboxListTile(
              value: _includeBirthDate,
              onChanged: (value) => setState(() => _includeBirthDate = value!),
              title: const Text('تاريخ الميلاد'),
              controlAffinity: ListTileControlAffinity.leading,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            CheckboxListTile(
              value: _includeAddress,
              onChanged: (value) => setState(() => _includeAddress = value!),
              title: const Text('العنوان'),
              controlAffinity: ListTileControlAffinity.leading,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            CheckboxListTile(
              value: _includeSubjects,
              onChanged: (value) => setState(() => _includeSubjects = value!),
              title: const Text('المواد المسجلة'),
              controlAffinity: ListTileControlAffinity.leading,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.icon(
        onPressed: _isLoading ? null : _exportData,
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.download_rounded),
        label: Text(
          _isLoading ? 'جاري التصدير...' : 'تصدير البيانات',
          style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Future<void> _exportData() async {
    setState(() => _isLoading = true);

    try {
      // TODO: Implement actual export logic
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                'تم التصدير بنجاح (${_selectedFormat.name.toUpperCase()})',
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

      Navigator.pop(context);
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
}
