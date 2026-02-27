import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/providers/center_provider.dart';
import '../../../../core/supabase/supabase_client.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../data/repositories/settings_repository.dart';

class RolesManagementWidget extends StatefulWidget {
  final bool isDark;

  const RolesManagementWidget({super.key, required this.isDark});

  @override
  State<RolesManagementWidget> createState() => _RolesManagementWidgetState();
}

class _RolesManagementWidgetState extends State<RolesManagementWidget> {
  List<AppRole> _roles = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    debugPrint('🔐 ══════════════════════════════════════════════');
    debugPrint('🔐 [Roles] _loadRoles called');
    setState(() => _isLoading = true);
    try {
      final centerId = context.read<CenterProvider>().centerId;
      if (centerId == null) throw Exception('Center ID required');

      final response = await SupabaseClientManager.client
          .from('app_roles')
          .select('*, role_permissions(permission_code)')
          .eq('center_id', centerId);

      final roles = (response as List).map((e) => AppRole.fromJson(e)).toList();

      debugPrint('🟢 [Roles] Query successful!');
      debugPrint('🔐 [Roles] Roles count: ${roles.length}');

      setState(() {
        _roles = roles;
      });
      debugPrint('🔐 ══════════════════════════════════════════════');
    } catch (e) {
      debugPrint('🔴 [Roles] Error loading roles: $e');
      debugPrint('🔐 ══════════════════════════════════════════════');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'الأدوار والصلاحيات',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            AppButton(
              text: 'إضافة دور',
              icon: Icons.add,
              onPressed: () => _showAddRoleDialog(),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_roles.isEmpty)
          const Center(child: Text('لا توجد أدوار مضافة'))
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _roles.length,
            itemBuilder: (context, index) {
              final role = _roles[index];
              final roleName = role.nameAr;
              final roleDescription = role.description;
              final roleCode = role.name;
              return Card(
                color: widget.isDark
                    ? AppColors.darkSurfaceVariant
                    : AppColors.lightSurfaceVariant,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                child: ListTile(
                  title: Text(
                    roleName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(roleDescription),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.security),
                        tooltip: 'تعديل الصلاحيات',
                        onPressed: () => _showPermissionsDialog(role),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showEditRoleDialog(role),
                      ),
                      if (roleCode != 'owner' &&
                          !role
                              .isSystem) // Prevent deleting owner or system roles
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: AppColors.error,
                          ),
                          onPressed: () => _confirmDeleteRole(role),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _showAddRoleDialog() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة دور جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'اسم الدور (Admin, Teacher...)',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'وصف الدور'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await _createRole(nameController.text, descController.text);
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  Future<void> _createRole(String name, String desc) async {
    try {
      await SupabaseClientManager.client.from('roles').insert({
        'name_ar': name,
        'description': desc,
        'created_at': DateTime.now().toIso8601String(),
      });
      _loadRoles();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _showPermissionsDialog(AppRole role) async {
    // 1. Fetch available permissions
    // 2. Fetch current role permissions
    // 3. Show checkboxes

    final allPermissions = await SupabaseClientManager.client
        .from('permissions')
        .select();
    final currentPerms = role.permissions.toSet();

    final selected = Set<String>.from(currentPerms);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateSB) {
          return AlertDialog(
            title: Text('صلاحيات: ${role.nameAr}'),
            content: SizedBox(
              width: 400,
              height: 400,
              child: SingleChildScrollView(
                child: Column(
                  children: (allPermissions as List).map((p) {
                    final code = (p['code'] ?? '') as String;
                    final desc =
                        (p['name_ar'] ?? p['description'] ?? code) as String;
                    return CheckboxListTile(
                      title: Text(code),
                      subtitle: Text(desc),
                      value: selected.contains(code),
                      onChanged: (val) {
                        setStateSB(() {
                          if (val == true) {
                            selected.add(code);
                          } else {
                            selected.remove(code);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _updatePermissions(role.id, selected.toList());
                  if (mounted) Navigator.pop(context);
                },
                child: const Text('حفظ'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _updatePermissions(String roleId, List<String> codes) async {
    try {
      // 1. Delete existing permissions
      await SupabaseClientManager.client
          .from('role_permissions')
          .delete()
          .eq('role_id', roleId);

      // 2. Insert new permissions
      if (codes.isNotEmpty) {
        // Get permission IDs
        final perms = await SupabaseClientManager.client
            .from('permissions')
            .select('id')
            .inFilter('code', codes);

        final inserts = (perms as List)
            .map((p) => {'role_id': roleId, 'permission_id': p['id']})
            .toList();

        if (inserts.isNotEmpty) {
          await SupabaseClientManager.client
              .from('role_permissions')
              .insert(inserts);
        }
      }
      _loadRoles();
    } catch (e) {
      debugPrint('Error updating permisssions: $e');
    }
  }

  // Edit Role Dialog
  Future<void> _showEditRoleDialog(AppRole role) async {
    final nameController = TextEditingController(text: role.nameAr);
    final descController = TextEditingController(text: role.description);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تعديل الدور'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'اسم الدور'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'وصف الدور'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                Navigator.pop(dialogContext);
                try {
                  final repository = SettingsRepository();
                  await repository.updateRole(
                    roleId: role.id,
                    name: nameController.text,
                    description: descController.text,
                  );

                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('تم تحديث الدور بنجاح ✅'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                  _loadRoles();
                } catch (e) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('خطأ: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  // Confirm Delete Role
  Future<void> _confirmDeleteRole(AppRole role) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Check if it's a system role
    if (role.isSystem) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('لا يمكن حذف الأدوار الأساسية'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text(
          'هل أنت متأكد من حذف دور "${role.nameAr}"؟\n\nسيتم إلغاء تعيين هذا الدور من جميع المستخدمين.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                final repository = SettingsRepository();
                await repository.deleteRole(role.id);

                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('تم حذف الدور بنجاح ✅'),
                    backgroundColor: AppColors.success,
                  ),
                );
                _loadRoles();
              } catch (e) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('خطأ: $e'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}


