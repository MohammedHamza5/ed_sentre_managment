import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/repositories/teachers_repository.dart';

class TeacherInvitationsDialog extends StatefulWidget {
  const TeacherInvitationsDialog({super.key});

  @override
  State<TeacherInvitationsDialog> createState() =>
      _TeacherInvitationsDialogState();
}

class _TeacherInvitationsDialogState extends State<TeacherInvitationsDialog> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController(); // Optional
  final _specializationController = TextEditingController(); // Optional

  bool _isLoading = false;
  List<Map<String, dynamic>> _invitations = [];
  bool _showCreateForm = false;

  @override
  void initState() {
    super.initState();
    _loadInvitations();
  }

  Future<void> _loadInvitations() async {
    setState(() => _isLoading = true);
    try {
      final repo = context.read<TeachersRepository>();
      final data = await repo.getTeacherInvitations();
      if (mounted) {
        setState(() {
          _invitations = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createInvitation() async {
    if (_nameController.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final repo = context.read<TeachersRepository>();
      await repo.createTeacherInvitation(
        teacherName: _nameController.text,
        phone: _phoneController.text.isEmpty ? null : _phoneController.text,
        specialization: _specializationController.text.isEmpty
            ? null
            : _specializationController.text,
      );

      _nameController.clear();
      _phoneController.clear();
      _specializationController.clear();
      _showCreateForm = false;

      await _loadInvitations(); // Reload list
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _specializationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 600.w,
        height: 700.h,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'دعوات المعلمين',
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),

            // Create New Button
            if (!_showCreateForm)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() => _showCreateForm = true),
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text(
                      'إنشاء دعوة جديدة',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ),

            // Create Form
            if (_showCreateForm)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'بيانات المعلم الجديد',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'اسم المعلم (مطلوب)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _phoneController,
                            decoration: const InputDecoration(
                              labelText: 'رقم الهاتف (اختياري)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _specializationController,
                            decoration: const InputDecoration(
                              labelText: 'التخصص (اختياري)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () =>
                              setState(() => _showCreateForm = false),
                          child: const Text('إلغاء'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _createInvitation,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('توليد الكود'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'سجل الدعوات',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),

            // List
            Expanded(
              child: _isLoading && _invitations.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _invitations.isEmpty
                  ? Center(
                      child: Text(
                        'لا توجد دعوات سابقة',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _invitations.length,
                      separatorBuilder: (c, i) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final invite = _invitations[index];
                        final isUsed = invite['status'] == 'claimed';
                        final code = invite['code'] ?? '---';

                        return Container(
                          decoration: BoxDecoration(
                            color: isUsed ? Colors.grey[100] : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isUsed
                                  ? Colors.grey
                                  : AppColors.primary,
                              child: Icon(
                                isUsed ? Icons.check : Icons.vpn_key,
                                color: Colors.white,
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(invite['teacher_name'] ?? 'Unknown'),
                                if (invite['specialization'] != null)
                                  Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      invite['specialization'],
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.blue[800],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Code: $code',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isUsed ? Colors.grey : Colors.black,
                                  ),
                                ),
                                if (isUsed)
                                  Text(
                                    'تم الانضمام',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.green,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: isUsed
                                ? const Icon(
                                    Icons.verified,
                                    color: Colors.green,
                                  )
                                : IconButton(
                                    icon: const Icon(
                                      Icons.copy,
                                      color: AppColors.primary,
                                    ),
                                    onPressed: () {
                                      Clipboard.setData(
                                        ClipboardData(text: code),
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('تم نسخ الكود'),
                                        ),
                                      );
                                    },
                                  ),
                          ),
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


