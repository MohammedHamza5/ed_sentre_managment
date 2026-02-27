import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../data/repositories/settings_repository.dart';
import '../../../../shared/models/models.dart';


class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  bool _isLoading = true;
  List<CenterUser> _users = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    debugPrint('🔘 UsersPage: initState - Opening page');
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    debugPrint('🔘 UsersPage: _fetchUsers called');
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repository = SettingsRepository();
      
      debugPrint('🔘 UsersPage: Calling Repository.getCenterUsers()');
      final users = await repository.getCenterUsers();

      debugPrint('🟢 UsersPage: Query successful. Records found: ${users.length}');

      if (mounted) {
        setState(() {
          _users = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('🔴 UsersPage: Error in _fetchUsers: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addUser() async {
    debugPrint('🔘 UsersPage: _addUser dialog requested');
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    String role = 'center_admin'; // Default role

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة مستخدم جديد'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'الاسم الكامل'),
                  validator: (v) => v == null || v.isEmpty ? 'مطلوب' : null,
                ),
                SizedBox(height: AppSpacing.md.h),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                  keyboardType: TextInputType.phone,
                  validator: (v) => v == null || v.isEmpty ? 'مطلوب' : null,
                ),
                SizedBox(height: AppSpacing.md.h),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: const InputDecoration(labelText: 'الدور'),
                  items: const [
                    DropdownMenuItem(value: 'center_admin', child: Text('مدير مركز')),
                    DropdownMenuItem(value: 'super_admin', child: Text('مدير نظام')),
                  ],
                  onChanged: (v) => role = v!,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              debugPrint('🔘 UsersPage: Add User dialog cancelled');
              Navigator.pop(context);
            },
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              debugPrint('🔘 UsersPage: Add User submit pressed');
              if (formKey.currentState!.validate()) {
                debugPrint('🔘 UsersPage: Form validated. Submitting...');
                
                // Store context before closing dialog
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                
                try {
                  setState(() => _isLoading = true);
                  
                  final repository = SettingsRepository();
                  await repository.addCenterUser(
                    fullName: nameController.text,
                    phone: phoneController.text,
                    role: role,
                  );

                  debugPrint('🟢 UsersPage: User insert successful');

                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(content: Text('تم إضافة المستخدم بنجاح'), backgroundColor: AppColors.success),
                    );
                    _fetchUsers();
                  }
                } catch (e) {
                  debugPrint('🔴 UsersPage: User insert failed: $e');
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(content: Text('فشل إضافة المستخدم: $e'), backgroundColor: AppColors.error),
                    );
                    setState(() => _isLoading = false);
                  }
                }
              } else {
                 debugPrint('🔴 UsersPage: Form validation failed');
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🔘 UsersPage: build called');
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المستخدمين'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'إضافة مستخدم',
            onPressed: _addUser,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: () {
                debugPrint('🔘 UsersPage: Refresh button pressed');
                _fetchUsers();
            },
          ),
          SizedBox(width: 8.w),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: AppColors.error),
                      SizedBox(height: AppSpacing.md.h),
                      Text('حدث خطأ: $_error'),
                      SizedBox(height: AppSpacing.md.h),
                      ElevatedButton.icon(
                        onPressed: _fetchUsers,
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                )
              : _users.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                          SizedBox(height: AppSpacing.md.h),
                          Text(
                            'لا يوجد مستخدمين',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: AppSpacing.sm.h),
                          Text(
                            'اضغط على + لإضافة مستخدم جديد',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.all(AppSpacing.pagePadding.w),
                      itemCount: _users.length,
                      itemBuilder: (context, index) {
                        final user = _users[index];
                        return Card(
                          margin: EdgeInsets.only(bottom: AppSpacing.md.h),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(AppSpacing.md.w),
                            child: Row(
                              children: [
                                // Avatar
                                Container(
                                  width: 56.w,
                                  height: 56.w,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      (user.fullName).substring(0, 1).toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 24.sp,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: AppSpacing.md.w),
                                // User Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.fullName,
                                        style: TextStyle(
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 4.h),
                                      if (user.email != null)
                                        Row(
                                          children: [
                                            Icon(Icons.email_outlined, size: 16.sp, color: Colors.grey),
                                            SizedBox(width: 4.w),
                                            Expanded(
                                              child: Text(
                                                user.email!,
                                                style: TextStyle(
                                                  fontSize: 14.sp,
                                                  color: Colors.grey[700],
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      if (user.phone.isNotEmpty)
                                        Row(
                                          children: [
                                            Icon(Icons.phone_outlined, size: 16.sp, color: Colors.grey),
                                            SizedBox(width: 4.w),
                                            Text(
                                              user.phone,
                                              style: TextStyle(
                                                fontSize: 14.sp,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                                // Role Chip
                                Chip(
                                  label: Text(
                                    user.role == 'center_admin' 
                                        ? 'مدير مركز' 
                                        : user.role == 'super_admin'
                                            ? 'مدير نظام'
                                            : user.role
                                  ),
                                  backgroundColor: (user.role == 'center_admin' || user.role == 'super_admin')
                                      ? AppColors.primary.withValues(alpha: 0.1) 
                                      : Colors.grey.withValues(alpha: 0.1),
                                  labelStyle: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w600,
                                    color: (user.role == 'center_admin' || user.role == 'super_admin')
                                        ? AppColors.primary 
                                        : Colors.black87
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}


