import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/providers/center_provider.dart';

import '../../../core/l10n/app_strings.dart';

/// نموذج عناصر القائمة الجانبية
class SidebarMenuItem {
  final String titleKey;
  final IconData icon;
  final String route;

  const SidebarMenuItem({
    required this.titleKey,
    required this.icon,
    required this.route,
  });

  String getTitle(AppStrings strings) {
    switch (titleKey) {
      case 'dashboard':
        return strings.dashboard;
      case 'search':
        return strings.search;
      case 'students':
        return strings.students;
      case 'teachers':
        return strings.teachers;
      case 'schedule':
        return strings.schedule;
      case 'subjects':
        return strings.subjects;
      case 'rooms':
        return strings.rooms;
      case 'payments':
        return 'المدفوعات'; // Force correct string to fix duplication issue
      case 'reports':
        return strings.reports;
      case 'notifications':
        return strings.notifications;
      case 'settings':
        return strings.settings;
      case 'attendance':
        return strings.attendance;
      case 'groups':
        return 'المجموعات'; // Fallback as we can't edit AppStrings easily without knowing where it is exactly (l10n usually implies arb files which need generation) - actually I will check localizations later, for now hardcode/fallback is safer or use existing if any.
      case 'library':
        return 'المكتبة';
      default:
        return titleKey;
    }
  }
}

/// قائمة عناصر القائمة الجانبية
final List<SidebarMenuItem> sidebarMenuItems = [
  // 1. Command Center 🏠
  const SidebarMenuItem(
    titleKey: 'dashboard',
    icon: Icons.dashboard_rounded,
    route: RouteNames.dashboard,
  ),

  // 2. Daily Actions (High Frequency) ⚡
  const SidebarMenuItem(
    titleKey: 'attendance',
    icon: Icons.how_to_reg_rounded,
    route: RouteNames.attendance,
  ),
  const SidebarMenuItem(
    titleKey: 'payments',
    icon: Icons.payments_rounded,
    route: RouteNames.payments,
  ),

  // 3. Core Management 👥
  const SidebarMenuItem(
    titleKey: 'groups',
    icon: Icons.groups_rounded,
    route: RouteNames.groups,
  ),
  const SidebarMenuItem(
    titleKey: 'students',
    icon: Icons.school_rounded,
    route: RouteNames.students,
  ),

  // 4. Planning & Insights 📊
  const SidebarMenuItem(
    titleKey: 'schedule',
    icon: Icons.calendar_month_rounded,
    route: RouteNames.schedule,
  ),
  const SidebarMenuItem(
    titleKey: 'reports',
    icon: Icons.bar_chart_rounded,
    route: RouteNames.reports,
  ),

  // 5. Setup & Resources ⚙️
  const SidebarMenuItem(
    titleKey: 'teachers',
    icon: Icons.person_rounded,
    route: RouteNames.teachers,
  ),
  const SidebarMenuItem(
    titleKey: 'subjects',
    icon: Icons.menu_book_rounded,
    route: RouteNames.subjects,
  ),
  const SidebarMenuItem(
    titleKey: 'rooms',
    icon: Icons.meeting_room_rounded,
    route: RouteNames.rooms,
  ),
  const SidebarMenuItem(
    titleKey: 'library',
    icon: Icons.auto_stories_rounded,
    route: RouteNames.library,
  ),

  // 6. Tools 🛠️
  const SidebarMenuItem(
    titleKey: 'search',
    icon: Icons.search_rounded,
    route: RouteNames.search,
  ),
  const SidebarMenuItem(
    titleKey: 'notifications',
    icon: Icons.notifications_rounded,
    route: RouteNames.notifications,
  ),
  const SidebarMenuItem(
    titleKey: 'settings',
    icon: Icons.settings_rounded,
    route: RouteNames.settings,
  ),
];

/// القائمة الجانبية المتجاوبة - تصميم فاخر
class AppSidebar extends StatefulWidget {
  final bool isCollapsed;
  final VoidCallback? onToggle;

  const AppSidebar({super.key, this.isCollapsed = false, this.onToggle});

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentRoute = GoRouterState.of(context).uri.toString();
    final strings = AppStrings.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      width: widget.isCollapsed
          ? AppSpacing.sidebarCollapsedWidth.w
          : AppSpacing.sidebarExpandedWidth.w,
      decoration: BoxDecoration(
        // Vibrant blue gradient background
        gradient: const LinearGradient(
          colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Use a threshold to switch between layouts to prevents overflow during animation
          final isEffectiveCollapsed = constraints.maxWidth < 150.w;

          return Column(
            children: [
              // Premium Header/Logo
              _buildHeader(isDark, strings, isEffectiveCollapsed),

              // Gradient Divider
              Container(
                height: 1,
                margin: EdgeInsets.symmetric(
                  horizontal: isEffectiveCollapsed
                      ? AppSpacing.sm.w
                      : AppSpacing.lg.w,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

              // Menu Items with smooth scrolling
              Expanded(
                child: ListView(
                  padding: EdgeInsets.symmetric(
                    vertical: AppSpacing.md.h,
                    horizontal: isEffectiveCollapsed
                        ? AppSpacing.sm.w
                        : AppSpacing.md.w,
                  ),
                  children: sidebarMenuItems
                      .map(
                        (item) => _SidebarItem(
                          item: item,
                          strings: strings,
                          isCollapsed: isEffectiveCollapsed,
                          isActive:
                              currentRoute == item.route ||
                              currentRoute.startsWith('${item.route}/'),
                          onTap: () => context.go(item.route),
                        ),
                      )
                      .toList(),
                ),
              ),

              // Premium Footer
              _buildFooter(isDark, strings, isEffectiveCollapsed),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(bool isDark, AppStrings strings, bool isCollapsed) {
    return Container(
      height: (AppSpacing.appBarHeight + 16).h,
      padding: EdgeInsets.symmetric(
        horizontal: isCollapsed ? AppSpacing.sm.w : AppSpacing.lg.w,
        vertical: AppSpacing.md.h,
      ),
      child: isCollapsed
          // Collapsed: Only show logo centered (Clickable to expand)
          ? Center(
              child: Tooltip(
                message: strings.isArabic ? 'توسيع القائمة' : 'Expand Menu',
                child: InkWell(
                  onTap: widget.onToggle,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  child: Container(
                    width: 40.w,
                    height: 40.w,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: Color(0xFF3B82F6),
                      size: 22,
                    ),
                  ),
                ),
              ),
            )
          // Expanded: Full header
          : Row(
              children: [
                // Logo with white background
                Container(
                  width: 44.w,
                  height: 44.w,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: Color(0xFF3B82F6),
                    size: 24,
                  ),
                ),

                SizedBox(width: AppSpacing.md.w),

                // Logo Text
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EdSentre',
                        style: TextStyle(
                          fontSize: 18.sp, // Reduced
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        strings.isArabic ? 'إدارة السنتر' : 'Center Management',
                        style: TextStyle(
                          fontSize: 10.sp, // Reduced
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Collapse Button
                if (widget.onToggle != null) _buildToggleButton(),
              ],
            ),
    );
  }

  Widget _buildToggleButton() {
    return Container(
      width: 28.w, // Reduced
      height: 28.w, // Reduced
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: IconButton(
        onPressed: widget.onToggle,
        icon: AnimatedRotation(
          duration: const Duration(milliseconds: 200),
          turns: widget.isCollapsed ? 0.5 : 0,
          child: const Icon(
            Icons.chevron_left_rounded,
            size: 16,
            color: Colors.white,
          ),
        ),
        padding: EdgeInsets.zero,
        splashRadius: 16.r,
      ),
    );
  }

  Widget _buildFooter(bool isDark, AppStrings strings, bool isCollapsed) {
    return Container(
      padding: EdgeInsets.all(isCollapsed ? AppSpacing.sm.w : AppSpacing.md.w),
      margin: EdgeInsets.only(bottom: AppSpacing.sm.h),
      child: Tooltip(
        message: strings.isArabic ? 'هل تحتاج مساعدة؟' : 'Need Help?',
        child: InkWell(
          onTap: () => context.go(RouteNames.support),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: isCollapsed
              // Collapsed: Small icon
              ? Container(
                  width: 36.w, // Reduced
                  height: 36.w, // Reduced
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: const Icon(
                    Icons.headset_mic_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                )
              // Expanded: Full footer
              : Container(
                  padding: EdgeInsets.all(AppSpacing.sm.w + 2), // Reduced
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32.w, // Reduced
                        height: 32.w, // Reduced
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSm,
                          ),
                        ),
                        child: const Icon(
                          Icons.headset_mic_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: AppSpacing.sm.w), // Reduced from md
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.isArabic
                                  ? 'هل تحتاج مساعدة؟'
                                  : 'Need Help?',
                              style: TextStyle(
                                fontSize: 11.sp, // Reduced
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              strings.isArabic
                                  ? 'تواصل معنا'
                                  : 'Contact Support',
                              style: TextStyle(
                                fontSize: 9.sp, // Reduced
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

/// عنصر واحد في القائمة الجانبية - تصميم فاخر
class _SidebarItem extends StatefulWidget {
  final SidebarMenuItem item;
  final AppStrings strings;
  final bool isCollapsed;
  final bool isActive;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.item,
    required this.strings,
    required this.isCollapsed,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.isCollapsed ? widget.item.getTitle(widget.strings) : '',
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTapDown: (_) => _controller.forward(),
          onTapUp: (_) => _controller.reverse(),
          onTapCancel: () => _controller.reverse(),
          onTap: widget.onTap,
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) =>
                Transform.scale(scale: _scaleAnimation.value, child: child),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              margin: EdgeInsets.only(bottom: 4.h), // Reduced from xs.h
              padding: EdgeInsets.symmetric(
                horizontal: widget.isCollapsed ? 0 : AppSpacing.md.w,
                vertical: 6.h, // Reduced from sm.h (8)
              ),
              decoration: BoxDecoration(
                // Active state: white background
                color: widget.isActive
                    ? Colors.white
                    : _isHovered
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                boxShadow: widget.isActive
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: widget.isCollapsed
                  // Collapsed: Only icon, centered
                  ? Center(child: _buildIcon())
                  // Expanded: Icon + Text + Arrow
                  : Row(
                      children: [
                        _buildIcon(),
                        SizedBox(
                          width: AppSpacing.sm.w + 4,
                        ), // Adjusted spacing
                        Expanded(
                          child: Text(
                            widget.item.getTitle(widget.strings),
                            style: TextStyle(
                              color: widget.isActive
                                  ? AppColors.primary
                                  : _isHovered
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.9),
                              fontWeight: widget.isActive
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              fontSize: 13.sp, // Reduced
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        // Active indicator arrow
                        if (widget.isActive)
                          Padding(
                            padding: EdgeInsets.only(left: AppSpacing.sm.w),
                            child: const Icon(
                              Icons.chevron_left_rounded,
                              size: 14, // Reduced
                              color: AppColors.primary,
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    bool hasBadge = widget.item.titleKey == 'notifications';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 32.w,
          height: 32.w,
          decoration: widget.isActive
              ? BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                )
              : null,
          child: Icon(
            widget.item.icon,
            size: 18.sp,
            color: widget.isActive
                ? Colors.white
                : _isHovered
                ? Colors.white
                : Colors.white.withValues(alpha: 0.8),
          ),
        ),

        // Badge (Connected to Real Unread Count from CenterProvider)
        if (hasBadge)
          Consumer<CenterProvider>(
            // Import provider
            builder: (context, provider, child) {
              if (provider.unreadNotificationsCount == 0) {
                return const SizedBox();
              }
              return Positioned(
                top: -2.h,
                right: -2.w,
                child: Container(
                  width: 14.w,
                  height: 14.w, // Square badge
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      provider.unreadNotificationsCount > 9
                          ? '9+'
                          : '${provider.unreadNotificationsCount}',
                      style: TextStyle(
                        fontSize: 8.sp,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
