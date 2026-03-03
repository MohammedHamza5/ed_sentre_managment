import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/constants/app_colors.dart';
import 'center_library_provider.dart';

/// شاشة رفع مذكرة جديدة
/// Upload Center Book Screen
class UploadCenterBookScreen extends StatefulWidget {
  const UploadCenterBookScreen({super.key});

  @override
  State<UploadCenterBookScreen> createState() => _UploadCenterBookScreenState();
}

class _UploadCenterBookScreenState extends State<UploadCenterBookScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _subjectController = TextEditingController();
  final _yearController = TextEditingController();
  File? _selectedPdf;

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedPdf = File(result.files.single.path!);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedPdf == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى ملء الحقول المطلوبة واختيار ملف PDF'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final provider = context.read<CenterLibraryProvider>();
    final success = await provider.uploadBook(
      pdfFile: _selectedPdf!,
      title: _titleController.text.trim(),
      subject: _subjectController.text.trim(),
      academicYear: _yearController.text.trim().isNotEmpty
          ? _yearController.text.trim()
          : null,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم الرفع والمعالجة بنجاح!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.uploadStatus),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CenterLibraryProvider>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('رفع مذكرة جديدة')),
      body: provider.isUploading
          ? _buildUploadingView(provider.uploadStatus, colorScheme)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'المذكرة المرفوعة ستكون متاحة حصرياً لطلاب سنترك فقط عبر الذكاء الاصطناعي',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Title
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'العنوان (مثال: مذكرة الكيمياء العضوية)',
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (val) =>
                          val == null || val.isEmpty ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 16),
                    // Subject
                    TextFormField(
                      controller: _subjectController,
                      decoration: const InputDecoration(
                        labelText: 'المادة (مثال: كيمياء)',
                        prefixIcon: Icon(Icons.subject),
                      ),
                      validator: (val) =>
                          val == null || val.isEmpty ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 16),
                    // Academic Year (optional)
                    TextFormField(
                      controller: _yearController,
                      decoration: const InputDecoration(
                        labelText: 'السنة الدراسية (اختياري)',
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // File Picker
                    InkWell(
                      onTap: _pickFile,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 140,
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedPdf == null
                                ? colorScheme.outline
                                : AppColors.success,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _selectedPdf == null
                                  ? Icons.upload_file_rounded
                                  : Icons.check_circle_rounded,
                              size: 40,
                              color: _selectedPdf == null
                                  ? colorScheme.primary
                                  : AppColors.success,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _selectedPdf == null
                                  ? 'اضغط لاختيار ملف PDF'
                                  : _selectedPdf!.path
                                        .split(Platform.pathSeparator)
                                        .last,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Submit Button
                    ElevatedButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.rocket_launch_rounded),
                      label: const Text('رفع ومعالجة بالذكاء الاصطناعي'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildUploadingView(String status, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: colorScheme.primary),
          const SizedBox(height: 24),
          Text(
            'لا تغلق هذه الشاشة...',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              status,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
