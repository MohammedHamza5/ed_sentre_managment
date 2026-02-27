import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';

/// أنواع الأزرار
enum AppButtonType {
  primary,
  secondary,
  outlined,
  text,
  danger,
  success,
}

/// أحجام الأزرار
enum AppButtonSize {
  small,
  medium,
  large,
}

/// موقع الأيقونة
enum IconPosition {
  left,
  right,
}

/// زر التطبيق المخصص
class AppButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonType type;
  final AppButtonSize size;
  final IconData? icon;
  final IconPosition iconPosition;
  final bool isLoading;
  final bool isFullWidth;
  final double? width;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = AppButtonType.primary,
    this.size = AppButtonSize.medium,
    this.icon,
    this.iconPosition = IconPosition.left,
    this.isLoading = false,
    this.isFullWidth = false,
    this.width,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _isHovered = false;

  double get _height {
    switch (widget.size) {
      case AppButtonSize.small:
        return AppSpacing.buttonHeightSm;
      case AppButtonSize.medium:
        return AppSpacing.buttonHeight;
      case AppButtonSize.large:
        return AppSpacing.buttonHeightLg;
    }
  }

  double get _iconSize {
    switch (widget.size) {
      case AppButtonSize.small:
        return 16;
      case AppButtonSize.medium:
        return 18;
      case AppButtonSize.large:
        return 20;
    }
  }

  EdgeInsets get _padding {
    switch (widget.size) {
      case AppButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
      case AppButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
      case AppButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
    }
  }

  Color get _backgroundColor {
    if (widget.onPressed == null) {
      return AppColors.gray300;
    }
    switch (widget.type) {
      case AppButtonType.primary:
        return _isHovered ? AppColors.primaryDark : AppColors.primary;
      case AppButtonType.secondary:
        return _isHovered ? AppColors.secondaryDark : AppColors.secondary;
      case AppButtonType.danger:
        return _isHovered ? AppColors.errorDark : AppColors.error;
      case AppButtonType.success:
        return _isHovered ? AppColors.successDark : AppColors.success;
      case AppButtonType.outlined:
      case AppButtonType.text:
        return _isHovered 
            ? AppColors.primary.withValues(alpha: 0.1) 
            : Colors.transparent;
    }
  }

  Color get _foregroundColor {
    if (widget.onPressed == null) {
      return AppColors.gray500;
    }
    switch (widget.type) {
      case AppButtonType.primary:
      case AppButtonType.secondary:
      case AppButtonType.danger:
      case AppButtonType.success:
        return AppColors.white;
      case AppButtonType.outlined:
      case AppButtonType.text:
        return AppColors.primary;
    }
  }

  Border? get _border {
    if (widget.type == AppButtonType.outlined) {
      return Border.all(
        color: widget.onPressed == null 
            ? AppColors.gray300 
            : AppColors.primary,
        width: 1.5,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.isLoading) ...[
          SizedBox(
            width: _iconSize,
            height: _iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _foregroundColor,
            ),
          ),
        ] else ...[
          if (widget.icon != null && widget.iconPosition == IconPosition.left) ...[
            Icon(widget.icon, size: _iconSize, color: _foregroundColor),
            const SizedBox(width: AppSpacing.sm),
          ],
          Text(
            widget.text,
            style: TextStyle(
              color: _foregroundColor,
              fontWeight: FontWeight.w600,
              fontSize: widget.size == AppButtonSize.small ? 13 : 14,
            ),
          ),
          if (widget.icon != null && widget.iconPosition == IconPosition.right) ...[
            const SizedBox(width: AppSpacing.sm),
            Icon(widget.icon, size: _iconSize, color: _foregroundColor),
          ],
        ],
      ],
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: widget.isFullWidth ? double.infinity : widget.width,
        height: _height,
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: _border,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.isLoading ? null : widget.onPressed,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: Padding(
              padding: _padding,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// زر أيقونة
class AppIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? backgroundColor;
  final double size;
  final String? tooltip;

  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.color,
    this.backgroundColor,
    this.size = 40,
    this.tooltip,
  });

  @override
  State<AppIconButton> createState() => _AppIconButtonState();
}

class _AppIconButtonState extends State<AppIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = isDark 
        ? AppColors.darkTextSecondary 
        : AppColors.lightTextSecondary;

    final button = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: _isHovered
              ? (widget.backgroundColor ?? AppColors.primary.withValues(alpha: 0.1))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: Icon(
              widget.icon,
              color: _isHovered 
                  ? (widget.color ?? AppColors.primary)
                  : (widget.color ?? defaultColor),
              size: widget.size * 0.5,
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(
        message: widget.tooltip!,
        child: button,
      );
    }

    return button;
  }
}


