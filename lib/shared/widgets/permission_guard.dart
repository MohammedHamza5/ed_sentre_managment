import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/permission_service.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// Permission Guard - حارس الصلاحيات
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// يُستخدم لإخفاء/إظهار عناصر UI بناءً على صلاحيات المستخدم
/// ═══════════════════════════════════════════════════════════════════════════

class PermissionGuard extends StatelessWidget {
  /// الصلاحية المطلوبة
  final String permission;
  
  /// العنصر الذي سيظهر إذا كانت الصلاحية متوفرة
  final Widget child;
  
  /// العنصر البديل إذا لم تكن الصلاحية متوفرة (اختياري)
  final Widget? fallback;

  const PermissionGuard({
    super.key,
    required this.permission,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<PermissionService>(
      builder: (context, service, _) {
        if (service.hasPermission(permission)) {
          return child;
        }
        return fallback ?? const SizedBox.shrink();
      },
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// فحص أي صلاحية من قائمة
  /// ═══════════════════════════════════════════════════════════════════════
  static Widget any({
    required List<String> permissions,
    required Widget child,
    Widget? fallback,
  }) {
    return Consumer<PermissionService>(
      builder: (context, service, _) {
        if (service.hasAnyPermission(permissions)) {
          return child;
        }
        return fallback ?? const SizedBox.shrink();
      },
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// فحص كل الصلاحيات
  /// ═══════════════════════════════════════════════════════════════════════
  static Widget all({
    required List<String> permissions,
    required Widget child,
    Widget? fallback,
  }) {
    return Consumer<PermissionService>(
      builder: (context, service, _) {
        if (service.hasAllPermissions(permissions)) {
          return child;
        }
        return fallback ?? const SizedBox.shrink();
      },
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// فحص الدور
  /// ═══════════════════════════════════════════════════════════════════════
  static Widget role({
    required List<String> roles,
    required Widget child,
    Widget? fallback,
  }) {
    return Consumer<PermissionService>(
      builder: (context, service, _) {
        if (roles.contains(service.role)) {
          return child;
        }
        return fallback ?? const SizedBox.shrink();
      },
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// للمالك والمدير فقط
  /// ═══════════════════════════════════════════════════════════════════════
  static Widget managersOnly({
    required Widget child,
    Widget? fallback,
  }) {
    return Consumer<PermissionService>(
      builder: (context, service, _) {
        if (service.isManager) {
          return child;
        }
        return fallback ?? const SizedBox.shrink();
      },
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// للمالك فقط
  /// ═══════════════════════════════════════════════════════════════════════
  static Widget ownerOnly({
    required Widget child,
    Widget? fallback,
  }) {
    return Consumer<PermissionService>(
      builder: (context, service, _) {
        if (service.isOwner) {
          return child;
        }
        return fallback ?? const SizedBox.shrink();
      },
    );
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// Permission Extensions - إضافات مساعدة
/// ═══════════════════════════════════════════════════════════════════════════

extension PermissionContext on BuildContext {
  PermissionService get permissions => read<PermissionService>();
  
  bool hasPermission(String permission) => permissions.hasPermission(permission);
  bool get isOwner => permissions.isOwner;
  bool get isManager => permissions.isManager;
  String get userRole => permissions.role;
}

/// ═══════════════════════════════════════════════════════════════════════════
/// No Permission Page - صفحة عدم الصلاحية
/// ═══════════════════════════════════════════════════════════════════════════

class NoPermissionPage extends StatelessWidget {
  final String? message;
  
  const NoPermissionPage({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'لا يمكنك الوصول',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message ?? 'ليس لديك صلاحية للوصول إلى هذه الصفحة',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('العودة'),
            ),
          ],
        ),
      ),
    );
  }
}


