import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_shadows.dart';

/// بطاقة الإحصائيات المتحركة - تصميم حيوي وملون
class StatCard extends StatefulWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final double? changePercent;
  final bool isIncreasing;
  final VoidCallback? onTap;
  final LinearGradient? gradient; // Custom gradient
  final bool useWhiteText;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    this.iconColor,
    this.iconBackgroundColor,
    this.changePercent,
    this.isIncreasing = true,
    this.onTap,
    this.gradient,
    this.useWhiteText = false,
  });

  @override
  State<StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<StatCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.03,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme
        .of(context)
        .brightness == Brightness.dark;
    final iconColor = widget.iconColor ?? AppColors.primary;
    final hasGradient = widget.gradient != null;
    final useWhite = widget.useWhiteText || hasGradient;

    return MouseRegion(
        onEnter: (_) {
          setState(() => _isHovered = true);
          _controller.forward();
        },
        onExit: (_) {
          setState(() => _isHovered = false);
          _controller.reverse();
        },
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) =>
              Transform.scale(scale: _scaleAnimation.value, child: child),
          child: GestureDetector(
            onTap: widget.onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.all(AppSpacing.md.w), // Reduced padding for better space
                decoration: BoxDecoration(
                  gradient: widget.gradient,
                  color: hasGradient
                      ? null
                      : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl.r),
                  boxShadow: [
                    BoxShadow(
                      color: hasGradient
                          ? widget.gradient!.colors.first.withValues(alpha: 0.3)
                          : Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03),
                  ),
                ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Icon Container
                        Container(
                          width: 40.w, // Reduced
                          height: 40.w, // Reduced
                          decoration: BoxDecoration(
                            color: hasGradient
                                ? Colors.white.withValues(alpha: 0.2)
                                : iconColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusLg.r,
                            ),
                          ),
                          child: Icon(
                            widget.icon,
                            color: useWhite ? Colors.white : iconColor,
                            size: 20.sp, // Reduced
                          ),
                        ),

                        // Change Percentage Badge
                        if (widget.changePercent != null)
                          _buildChangeBadge(useWhite),
                      ],
                    ),

                    SizedBox(height: AppSpacing.xs.h), // Reduced

                    // Value
                    // Removed Expanded as it conflicts with Column's mainAxisSize.min
                    // Replaced with a constrained SizedBox to control height.
                    SizedBox(
                      height: 36.sp, // Adjusted height for smaller font
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          widget.value,
                          style: Theme
                              .of(context)
                              .textTheme
                              .headlineLarge
                              ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: useWhite ? Colors.white : null,
                            letterSpacing: -0.5,
                            fontSize: 28.sp, // Reduced from 32
                          ),
                        ),
                      ),
                    ),

                     SizedBox(height: 2.h), // Minimal spacing

                    // Title
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme
                          .of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(
                        color: useWhite
                            ? Colors.white.withValues(alpha: 0.9)
                            : (isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary),
                        fontWeight: FontWeight.w500,
                        fontSize: 13.sp, // Reduced
                      ),
                    ),

                    // Subtitle
                    if (widget.subtitle != null) ...[
                      SizedBox(height: 2.h),
                      Row(
                        children: [
                          Container(
                            width: 4.w,
                            height: 4.w,
                            decoration: BoxDecoration(
                              color: useWhite
                                  ? Colors.white.withValues(alpha: 0.6)
                                  : iconColor.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Expanded(
                            child: Text(
                              widget.subtitle!,
                              style: Theme
                                  .of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                color: useWhite
                                    ? Colors.white.withValues(alpha: 0.8)
                                    : (isDark
                                    ? AppColors.darkTextTertiary
                                    : AppColors.lightTextTertiary),
                                fontSize: 11.sp, // Reduced
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
        )
    );
  }

  Widget _buildChangeBadge(bool useWhite) {
    final isPositive = widget.isIncreasing;
    final badgeColor = isPositive ? AppColors.success : AppColors.error;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md.w,
        vertical: AppSpacing.sm.h,
      ),
      decoration: BoxDecoration(
        color: useWhite
            ? Colors.white.withValues(alpha: 0.2)
            : badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            size: 14.sp,
            color: useWhite ? Colors.white : badgeColor,
          ),
          SizedBox(width: 4.w),
          Text(
            '${widget.changePercent!.abs().toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: useWhite ? Colors.white : badgeColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// بطاقة معلومات عادية
class InfoCard extends StatelessWidget {
  final String? title;
  final Widget child;
  final List<Widget>? actions;
  final EdgeInsets? padding;
  final VoidCallback? onTap;

  const InfoCard({
    super.key,
    this.title,
    required this.child,
    this.actions,
    this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg.r),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: AppShadows.sm,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              if (title != null || actions != null)
                Container(
                  padding: EdgeInsets.all(AppSpacing.lg.w),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (title != null)
                        Text(
                          title!,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 16.sp,
                              ),
                        ),
                      if (actions != null)
                        Row(mainAxisSize: MainAxisSize.min, children: actions!),
                    ],
                  ),
                ),

              // Content
              Padding(
                padding: padding ?? EdgeInsets.all(AppSpacing.lg.w),
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


