/// Auth & Role Models
/// نماذج المصادقة والأدوار والصلاحيات
library;

import 'package:equatable/equatable.dart';

// ═══════════════════════════════════════════════════════════════════════════
// APP ROLE - دور المستخدم
// ═══════════════════════════════════════════════════════════════════════════

class AppRole extends Equatable {
  final String id;
  final String centerId;
  final String name; // Internal code
  final String nameAr; // Display name
  final String description;
  final bool isSystem; // Prevent deletion of system roles
  final List<String> permissions;
  final DateTime createdAt;

  const AppRole({
    required this.id,
    required this.centerId,
    required this.name,
    required this.nameAr,
    required this.description,
    this.isSystem = false,
    required this.permissions,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, centerId, name, permissions];

  factory AppRole.fromJson(Map<String, dynamic> json) {
    // Parsing nested permissions
    final permsRaw = json['role_permissions'] as List?;
    final perms = permsRaw
        ?.map((e) => (e['permission_code'] ?? '').toString())
        .where((e) => e.isNotEmpty)
        .toList() ?? [];

    return AppRole(
      id: (json['id'] ?? '').toString(),
      centerId: (json['center_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      nameAr: (json['name_ar'] ?? json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      isSystem: json['is_system'] ?? false,
      permissions: perms,
      createdAt: DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'center_id': centerId,
      'name': name,
      'name_ar': nameAr,
      'description': description,
      'is_system': isSystem,
      // permission codes not stored directly in app_roles but via relation
    };
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CENTER USER - مستخدم السنتر (Admin/Staff)
// ═══════════════════════════════════════════════════════════════════════════

class CenterUser extends Equatable {
  final String id;
  final String fullName;
  final String? email;
  final String phone;
  final String role; // 'admin', 'staff', etc.
  final bool isActive;
  final String? avatarUrl;

  const CenterUser({
    required this.id,
    required this.fullName,
    this.email,
    required this.phone,
    required this.role,
    required this.isActive,
    this.avatarUrl,
  });

  @override
  List<Object?> get props => [id, fullName, role, isActive];

  factory CenterUser.fromJson(Map<String, dynamic> json) {
    return CenterUser(
      id: (json['id'] ?? '').toString(),
      fullName: (json['full_name'] ?? 'Unknown').toString(),
      email: json['email'] as String?,
      phone: (json['phone'] ?? '').toString(),
      role: (json['role'] ?? 'staff').toString(),
      isActive: json['is_active'] ?? true,
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}


