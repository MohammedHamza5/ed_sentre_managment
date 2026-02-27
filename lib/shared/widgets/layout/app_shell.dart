import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart' hide DeviceType;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/responsive_utils.dart';

import '../navigation/app_sidebar.dart';
import '../offline/offline_banner.dart';

import '../../../features/auth/bloc/auth_bloc.dart';
import 'package:ed_sentre/core/supabase/supabase_client.dart';
import '../../../core/providers/center_provider.dart';

/// الهيكل الرئيسي للتطبيق
/// يحتوي على القائمة الجانبية والمحتوى
class AppShell extends StatefulWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _isSidebarCollapsed = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _toggleSidebar() {
    setState(() {
      _isSidebarCollapsed = !_isSidebarCollapsed;
    });
  }

  void _handleMenuAction(String value) {
    switch (value) {
      case 'profile':
        context.pushNamed('profile');
        break;
      case 'settings':
        context.pushNamed('settings');
        break;
      case 'logout':
        _handleLogout();
        break;
    }
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // تسجيل الخروج
              context.read<AuthBloc>().add(AuthLogoutRequested());
              // الانتقال لصفحة تسجيل الدخول
              context.go('/login');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deviceType = ResponsiveUtils.getDeviceType(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,

      // Drawer للموبايل
      drawer: deviceType == DeviceType.mobile
          ? Drawer(
              child: AppSidebar(
                isCollapsed: false,
                onToggle: () => Navigator.pop(context),
              ),
            )
          : null,

      body: Row(
        children: [
          // القائمة الجانبية للتابلت والديسكتوب
          if (deviceType != DeviceType.mobile)
            AppSidebar(
              isCollapsed:
                  deviceType == DeviceType.tablet || _isSidebarCollapsed,
              onToggle: deviceType == DeviceType.tablet
                  ? null
                  : _toggleSidebar,
            ),

          // المحتوى الرئيسي مع مؤشر الاتصال
          Expanded(
            child: OfflineBanner(
              child: Column(
                children: [
                  // شريط الأدوات العلوي
                  _buildAppBar(context, deviceType, isDark),

                  // المحتوى
                  Expanded(child: widget.child),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(
    BuildContext context,
    DeviceType deviceType,
    bool isDark,
  ) {
    return Container(
      margin: EdgeInsets.only(
        top: AppSpacing.md.h,
        left: AppSpacing.md.w,
        right: AppSpacing.md.w,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 70.h,
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurface.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                // زر القائمة للموبايل
                if (deviceType == DeviceType.mobile) ...[
                  IconButton(
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    icon: Icon(
                      Icons.menu_rounded,
                      color: isDark ? Colors.white : AppColors.primary,
                    ),
                  ),
                  SizedBox(width: AppSpacing.md.w),
                ],

                // Welcoming Text / Brand
                if (deviceType != DeviceType.mobile)
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.dashboard_rounded,
                          color: Colors.white,
                          size: 20.sp,
                        ),
                      ),
                      SizedBox(width: AppSpacing.md.w),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isDark ? 'مساء الخير' : 'صباح الخير',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.7)
                                  : AppColors.gray600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Consumer<CenterProvider>(
                            builder: (context, centerProvider, _) {
                              return Text(
                                centerProvider.centerName.isNotEmpty 
                                    ? centerProvider.centerName 
                                    : 'EdSentre',
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : AppColors.primary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),

                const Spacer(),

                 // Icons
                Row(
                  children: [
                    _buildPremiumIconButton(
                      context: context,
                      icon: Icons.notifications_outlined,
                      badgeCount: 0,
                      isDark: isDark,
                      onTap: () => GoRouter.of(context).go('/notifications'),
                      tooltip: 'الإشعارات',
                    ),
                    SizedBox(width: AppSpacing.md.w), // Increased spacing
                    _buildPremiumIconButton(
                      context: context,
                      icon: Icons.chat_bubble_outline_rounded,
                      badgeCount: 0,
                      isDark: isDark,
                      onTap: () => context.pushNamed('messages'),
                      tooltip: 'الرسائل',
                    ),
                  ],
                ),

                SizedBox(width: AppSpacing.lg.w),

                // Divider
                Container(
                  height: 30.h,
                  width: 1,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : AppColors.gray200,
                ),

                SizedBox(width: AppSpacing.lg.w),

                // User Profile
                _buildUserInfo(context, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumIconButton({
    required BuildContext context,
    required IconData icon,
    required int badgeCount,
    required bool isDark,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Container(
          width: 45.w,
          height: 45.h,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : AppColors.primary.withValues(alpha: 0.1),
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                icon,
                size: 22.sp,
                color: isDark ? Colors.white : AppColors.primary.withValues(alpha: 0.8),
              ),
              if (badgeCount > 0)
                Positioned(
                  top: 8.h,
                  right: 8.w,
                  child: Container(
                    width: 8.w,
                    height: 8.h,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.error.withValues(alpha: 0.4),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfo(BuildContext context, bool isDark) {
    final metadata = SupabaseClientManager.currentUser?.userMetadata;
    final displayName = (metadata?['full_name'] as String?) ?? 'مستخدم';
    final role = (metadata?['role'] as String?) ?? 'مدير السنتر';
    final initial = displayName.isNotEmpty ? displayName.characters.first : 'م';

    return PopupMenuButton<String>(
      offset: const Offset(0, 56),
      onSelected: _handleMenuAction,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'profile',
          child: _buildMenuItem(
            icon: Icons.person_outline_rounded,
            title: 'الملف الشخصي',
            isDark: isDark,
          ),
        ),
        PopupMenuItem(
          value: 'settings',
          child: _buildMenuItem(
            icon: Icons.settings_outlined,
            title: 'الإعدادات',
            isDark: isDark,
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'logout',
          child: _buildMenuItem(
            icon: Icons.logout_rounded,
            title: 'تسجيل الخروج',
            isDark: isDark,
            isDestructive: true,
          ),
        ),
      ],
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm.w),
        child: Row(
          children: [
            Container(
              width: 38.w,
              height: 38.w, // Keep it square using w
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ),
            if (!ResponsiveUtils.isMobile(context)) ...[
              SizedBox(width: AppSpacing.md.w),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp,
                      color: isDark ? Colors.white : AppColors.gray800,
                    ),
                  ),
                  Text(
                    role == 'center_admin' ? 'مدير السنتر' : role, // Quick localization fix
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.5)
                          : AppColors.gray500,
                    ),
                  ),
                ],
              ),
              SizedBox(width: AppSpacing.sm.w),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16.sp,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.5)
                    : AppColors.gray400,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required bool isDark,
    bool isDestructive = false,
  }) {
    final color = isDestructive
        ? AppColors.error
        : (isDark ? Colors.white : AppColors.lightTextPrimary);

    return Row(
      children: [
        Container(
          width: 32.w,
          height: 32.w, // Square logic
          decoration: BoxDecoration(
            color: isDestructive
                ? AppColors.error.withValues(alpha: 0.1)
                : (isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.gray100),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          child: Icon(icon, size: 18.sp, color: color),
        ),
        SizedBox(width: AppSpacing.md.w),
        Text(
          title,
          style: TextStyle(color: color, fontWeight: FontWeight.w500, fontSize: 13.sp), // added optional size
        ),
      ],
    );
  }
}


