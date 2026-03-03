import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/center_provider.dart';
import '../../bloc/auth_bloc.dart';

class _BaseStatusScreen extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final String? reason;
  final String buttonText;
  final VoidCallback onAction;

  const _BaseStatusScreen({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    this.reason,
    required this.buttonText,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;
    final surfaceColor = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final primaryTextColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final secondaryTextColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: Container(
          width: 500.w,
          padding: EdgeInsets.all(32.w),
          margin: EdgeInsets.all(24.w),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 64.sp, color: color),
              ),
              SizedBox(height: 24.h),
              Text(
                title,
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                  color: primaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16.h),
              Text(
                message,
                style: TextStyle(
                  fontSize: 16.sp,
                  color: secondaryTextColor,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              if (reason != null && reason!.isNotEmpty) ...[
                SizedBox(height: 24.h),
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'السبب:',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        reason!,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: 32.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        context.read<AuthBloc>().add(AuthLogoutRequested());
                        context.go('/login');
                      },
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        side: BorderSide(color: borderColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Text(
                        'تسجيل الخروج',
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: 16.sp,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onAction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Text(
                        buttonText,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _BaseStatusScreen(
      icon: Icons.hourglass_top_rounded,
      color: AppColors.warning,
      title: 'طلبكم قيد المراجعة',
      message:
          'برجاء الانتظار حتى يقوم الإدارة بمراجعة بيانات المركز والموافقة عليه. سيتم إشعاركم فور الموافقة.',
      buttonText: 'تحديث الحالة',
      onAction: () => context.read<CenterProvider>().refresh(),
    );
  }
}

class RejectedCenterScreen extends StatelessWidget {
  const RejectedCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reason = context.read<CenterProvider>().rejectionReason;
    return _BaseStatusScreen(
      icon: Icons.cancel_rounded,
      color: AppColors.error,
      title: 'تم رفض الطلب',
      message: 'نأسف، لقد تم رفض طلب تسجيل المركز من قبل الإدارة.',
      reason: reason,
      buttonText: 'تحديث الحالة',
      onAction: () => context.read<CenterProvider>().refresh(),
    );
  }
}

class FrozenCenterScreen extends StatelessWidget {
  const FrozenCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reason = context.read<CenterProvider>().freezeReason;
    return _BaseStatusScreen(
      icon: Icons.ac_unit_rounded,
      color: Colors.lightBlue,
      title: 'المركز متوقف مؤقتاً',
      message:
          'تم إيقاف تفعيل المركز مؤقتاً. لن يتمكن الطلاب أو المعلمون من التفاعل مع النظام حتى يتم حل المشكلة.',
      reason: reason,
      buttonText: 'تحديث الحالة',
      onAction: () => context.read<CenterProvider>().refresh(),
    );
  }
}

class TerminatedCenterScreen extends StatelessWidget {
  const TerminatedCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _BaseStatusScreen(
      icon: Icons.dangerous_rounded,
      color: Colors.grey.shade700,
      title: 'تم إنهاء المركز',
      message:
          'لقد تم إغلاق المركز نهائياً. سيتم حذف جميع البيانات المتبقية بعد 90 يوماً من تاريخ الإغلاق.',
      buttonText: 'تسجيل الخروج',
      onAction: () {
        context.read<AuthBloc>().add(AuthLogoutRequested());
        context.go('/login');
      },
    );
  }
}
