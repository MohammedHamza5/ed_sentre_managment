import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/center_provider.dart';
import '../../../../core/supabase/supabase_client.dart';
import '../../../../core/supabase/supabase_config.dart';

/// الأدوار الجاهزة مع صلاحياتها
const Map<String, Map<String, dynamic>> _predefinedRoles = {
  'manager': {
    'name_ar': 'مدير',
    'name_en': 'Manager',
    'icon': Icons.admin_panel_settings,
    'color': Colors.blue,
    'description': 'إدارة كاملة للمركز',
    'permissions': [
      'students.view',
      'students.add',
      'students.edit',
      'students.delete',
      'teachers.view',
      'teachers.add',
      'teachers.edit',
      'groups.view',
      'groups.manage',
      'attendance.view',
      'attendance.take',
      'payments.view',
      'payments.add',
      'reports.view',
      'settings.view',
    ],
  },
  'accountant': {
    'name_ar': 'محاسب',
    'name_en': 'Accountant',
    'icon': Icons.account_balance_wallet,
    'color': Colors.green,
    'description': 'إدارة المدفوعات والتقارير',
    'permissions': [
      'students.view',
      'payments.view',
      'payments.add',
      'reports.view',
    ],
  },
  'reception': {
    'name_ar': 'استقبال',
    'name_en': 'Reception',
    'icon': Icons.support_agent,
    'color': Colors.orange,
    'description': 'تسجيل الطلاب والحضور',
    'permissions': [
      'students.view',
      'students.add',
      'students.edit',
      'groups.view',
      'attendance.view',
      'attendance.take',
    ],
  },
  'teacher': {
    'name_ar': 'معلم',
    'name_en': 'Teacher',
    'icon': Icons.school,
    'color': Colors.purple,
    'description': 'إدارة المجموعات والحضور',
    'permissions': [
      'students.view',
      'groups.view',
      'attendance.view',
      'attendance.take',
    ],
  },
};

class TeamManagementWidget extends StatefulWidget {
  final bool isDark;

  const TeamManagementWidget({super.key, required this.isDark});

  @override
  State<TeamManagementWidget> createState() => _TeamManagementWidgetState();
}

class _TeamManagementWidgetState extends State<TeamManagementWidget> {
  List<Map<String, dynamic>> _teamMembers = [];
  bool _isLoading = true;
  String? _centerId;

  @override
  void initState() {
    super.initState();
    _loadTeamMembers();
  }

  Future<void> _loadTeamMembers() async {
    setState(() => _isLoading = true);

    try {
      final centerProvider = context.read<CenterProvider>();
      _centerId = centerProvider.centerId;

      debugPrint('👥 [Team] Loading team for center: $_centerId');

      if (_centerId == null) {
        debugPrint('🔴 [Team] Center ID is null');
        return;
      }

      // Get all users in this center (excluding the owner)
      final currentUserId = SupabaseClientManager.client.auth.currentUser?.id;

      final response = await SupabaseClientManager.client
          .from('users')
          .select('id, full_name, phone, role, is_active, created_at')
          .eq('default_center_id', _centerId!)
          .neq('id', currentUserId ?? '')
          .order('created_at', ascending: false);

      debugPrint('👥 [Team] Loaded ${response.length} members');

      if (!mounted) return;
      setState(() {
        _teamMembers = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('🔴 [Team] Error: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateMemberRole(String memberId, String newRole) async {
    try {
      debugPrint('👥 [Team] Updating role for $memberId to $newRole');

      await SupabaseClientManager.client
          .from('users')
          .update({'role': newRole})
          .eq('id', memberId);

      // Update local state
      if (!mounted) return;
      setState(() {
        final index = _teamMembers.indexWhere((m) => m['id'] == memberId);
        if (index != -1) {
          _teamMembers[index]['role'] = newRole;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تغيير الدور بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('🔴 [Team] Error updating role: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تغيير الدور: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _showAddMemberDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    String selectedRole = 'reception';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.person_add, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text('إضافة عضو جديد'),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'الاسم الكامل',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  decoration: InputDecoration(
                    labelText: 'رقم الهاتف',
                    prefixIcon: const Icon(Icons.phone),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 24),

                // Role Selection Cards
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'اختر الدور:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _predefinedRoles.entries.map((entry) {
                    final roleCode = entry.key;
                    final roleData = entry.value;
                    final isSelected = selectedRole == roleCode;

                    return InkWell(
                      onTap: () =>
                          setDialogState(() => selectedRole = roleCode),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (roleData['color'] as Color).withValues(
                                  alpha: 0.2,
                                )
                              : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? roleData['color'] as Color
                                : Colors.grey.shade400,
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              roleData['icon'] as IconData,
                              color: roleData['color'] as Color,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              roleData['name_ar'] as String,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // Role Description
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (_predefinedRoles[selectedRole]!['color'] as Color)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color:
                            _predefinedRoles[selectedRole]!['color'] as Color,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _predefinedRoles[selectedRole]!['description']
                              as String,
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              onPressed: () => _createMember(
                context,
                nameController.text.trim(),
                phoneController.text.trim(),
                selectedRole,
              ),
              icon: const Icon(Icons.check),
              label: const Text('إضافة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createMember(
    BuildContext dialogContext,
    String name,
    String phone,
    String role,
  ) async {
    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال الاسم ورقم الهاتف')),
      );
      return;
    }

    try {
      final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
      final smartEmail = '$cleanPhone@edsentre.local';
      final tempPassword =
          'Ed${cleanPhone.substring(cleanPhone.length - 4)}${DateTime.now().millisecond}';

      debugPrint('👥 [Team] Creating member: $smartEmail with role: $role');

      // 1. Create auth user with temp client
      final tempClient = SupabaseClient(
        SupabaseConfig.url,
        SupabaseConfig.anonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
      );

      final authResponse = await tempClient.auth.signUp(
        email: smartEmail,
        password: tempPassword,
        data: {
          'full_name': name,
          'role': role,
          'center_id': _centerId,
          'phone': phone,
        },
      );

      if (authResponse.user == null) {
        throw Exception('فشل إنشاء الحساب');
      }

      // 2. Insert/Update in users table via RPC
      await SupabaseClientManager.client.rpc(
        'admin_upsert_user',
        params: {
          'p_user_id': authResponse.user!.id,
          'p_full_name': name,
          'p_phone': phone,
          'p_role': role,
          'p_center_id': _centerId,
        },
      );

      debugPrint('👥 [Team] Member created successfully');

      // Close dialog
      if (mounted) Navigator.pop(dialogContext);

      // Refresh list
      await _loadTeamMembers();

      // Show access card
      if (mounted) {
        _showAccessCard(name, phone, tempPassword, role);
      }
    } catch (e) {
      debugPrint('🔴 [Team] Error creating member: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل إنشاء العضو: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showAccessCard(
    String name,
    String phone,
    String password,
    String role,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success, size: 28),
            const SizedBox(width: 8),
            const Text('تم إنشاء الحساب بنجاح!'),
          ],
        ),
        content: Container(
          width: 350,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.1),
                AppColors.primary.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.primary,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 32, color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _predefinedRoles[role]?['name_ar'] ?? role,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              _buildInfoRow(Icons.phone, 'رقم الهاتف', phone),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.lock, 'كلمة المرور', password),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(
                      text: 'رقم الدخول: $phone\nكلمة المرور: $password',
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم نسخ البيانات')),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('نسخ البيانات'),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('تم'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(color: Colors.grey[600])),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.left,
            textDirection: TextDirection.ltr,
          ),
        ),
      ],
    );
  }

  Future<void> _deleteMember(Map<String, dynamic> member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف العضو'),
        content: Text('هل أنت متأكد من حذف "${member['full_name']}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await SupabaseClientManager.client
            .from('users')
            .update({'is_active': false})
            .eq('id', member['id']);

        await _loadTeamMembers();

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('تم حذف العضو')));
        }
      } catch (e) {
        debugPrint('🔴 [Team] Error deleting: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.groups, color: AppColors.primary, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'إدارة الفريق',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _showAddMemberDialog,
              icon: const Icon(Icons.person_add),
              label: const Text('إضافة عضو'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),
        Text(
          'أعضاء فريق العمل وصلاحياتهم',
          style: TextStyle(color: Colors.grey[600]),
        ),

        const SizedBox(height: 24),

        // Content
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_teamMembers.isEmpty)
          _buildEmptyState()
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _teamMembers.length,
            itemBuilder: (context, index) =>
                _buildMemberCard(_teamMembers[index]),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group_add, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'لا يوجد أعضاء في الفريق',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text('أضف أول عضو للبدء', style: TextStyle(color: Colors.grey[500])),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddMemberDialog,
            icon: const Icon(Icons.add),
            label: const Text('إضافة عضو جديد'),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member) {
    final role = member['role'] as String? ?? 'reception';
    final roleData = _predefinedRoles[role] ?? _predefinedRoles['reception']!;
    final isActive = member['is_active'] as bool? ?? true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 28,
                  backgroundColor: (roleData['color'] as Color).withValues(
                    alpha: 0.2,
                  ),
                  child: Icon(
                    roleData['icon'] as IconData,
                    color: roleData['color'] as Color,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),

                // Name & Phone
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            member['full_name'] ?? 'بدون اسم',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (!isActive) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'غير نشط',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            member['phone'] ?? '',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Role Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (roleData['color'] as Color).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (roleData['color'] as Color).withValues(
                        alpha: 0.3,
                      ),
                    ),
                  ),
                  child: DropdownButton<String>(
                    value: role,
                    underline: const SizedBox(),
                    isDense: true,
                    items: _predefinedRoles.entries.map((e) {
                      return DropdownMenuItem(
                        value: e.key,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              e.value['icon'] as IconData,
                              size: 18,
                              color: e.value['color'] as Color,
                            ),
                            const SizedBox(width: 8),
                            Text(e.value['name_ar'] as String),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (newRole) {
                      if (newRole != null && newRole != role) {
                        _updateMemberRole(member['id'], newRole);
                      }
                    },
                  ),
                ),

                // Delete Button
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red[400]),
                  onPressed: () => _deleteMember(member),
                  tooltip: 'حذف العضو',
                ),
              ],
            ),

            const Divider(height: 24),

            // Permissions Preview - Show unique categories only
            Row(
              children: [
                Icon(Icons.security, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text('الصلاحيات: ', style: TextStyle(color: Colors.grey[600])),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children:
                        _getUniqueCategories(
                              roleData['permissions'] as List<String>,
                            )
                            .map((category) => _buildPermissionChip(category))
                            .toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Get unique permission categories
  List<String> _getUniqueCategories(List<String> permissions) {
    final categories = <String>{};
    for (final p in permissions) {
      categories.add(p.split('.')[0]);
    }
    return categories.toList();
  }

  Widget _buildPermissionChip(String category) {
    final categoryData = {
      'students': {
        'name': 'الطلاب',
        'icon': Icons.school,
        'color': Colors.blue,
      },
      'teachers': {
        'name': 'المعلمين',
        'icon': Icons.person,
        'color': Colors.purple,
      },
      'groups': {
        'name': 'المجموعات',
        'icon': Icons.groups,
        'color': Colors.teal,
      },
      'attendance': {
        'name': 'الحضور',
        'icon': Icons.event_available,
        'color': Colors.green,
      },
      'payments': {
        'name': 'المدفوعات',
        'icon': Icons.payment,
        'color': Colors.orange,
      },
      'reports': {
        'name': 'التقارير',
        'icon': Icons.analytics,
        'color': Colors.indigo,
      },
      'settings': {
        'name': 'الإعدادات',
        'icon': Icons.settings,
        'color': Colors.grey,
      },
    };

    final data = categoryData[category];
    final name = data?['name'] as String? ?? category;
    final icon = data?['icon'] as IconData? ?? Icons.check;
    final color = data?['color'] as Color? ?? AppColors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            name,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
