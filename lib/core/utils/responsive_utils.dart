import 'package:flutter/material.dart';

/// EdSentre Responsive Utilities
/// أدوات التصميم المتجاوب
class ResponsiveUtils {
  ResponsiveUtils._();

  // ═══════════════════════════════════════════════════════════════════════════
  // BREAKPOINTS - نقاط التحول
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Mobile: 0 - 599
  static const double mobileBreakpoint = 600;
  
  /// Tablet: 600 - 1023
  static const double tabletBreakpoint = 1024;
  
  /// Desktop: 1024 - 1439
  static const double desktopBreakpoint = 1440;
  
  /// Large Desktop: 1440+
  static const double largeDesktopBreakpoint = 1440;

  // ═══════════════════════════════════════════════════════════════════════════
  // DEVICE TYPE DETECTION - اكتشاف نوع الجهاز
  // ═══════════════════════════════════════════════════════════════════════════

  /// هل الشاشة موبايل؟
  static bool isMobile(BuildContext context) {
    return MediaQuery.sizeOf(context).width < mobileBreakpoint;
  }

  /// هل الشاشة تابلت؟
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  /// هل الشاشة ديسكتوب؟
  static bool isDesktop(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= tabletBreakpoint;
  }

  /// هل الشاشة ديسكتوب كبير؟
  static bool isLargeDesktop(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= largeDesktopBreakpoint;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DEVICE TYPE ENUM - تعداد نوع الجهاز
  // ═══════════════════════════════════════════════════════════════════════════

  /// الحصول على نوع الجهاز الحالي
  static DeviceType getDeviceType(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    
    if (width < mobileBreakpoint) {
      return DeviceType.mobile;
    } else if (width < tabletBreakpoint) {
      return DeviceType.tablet;
    } else if (width < largeDesktopBreakpoint) {
      return DeviceType.desktop;
    } else {
      return DeviceType.largeDesktop;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RESPONSIVE VALUE - قيمة متجاوبة
  // ═══════════════════════════════════════════════════════════════════════════

  /// إرجاع قيمة بناءً على حجم الشاشة
  static T responsiveValue<T>({
    required BuildContext context,
    required T mobile,
    T? tablet,
    T? desktop,
    T? largeDesktop,
  }) {
    final deviceType = getDeviceType(context);
    
    switch (deviceType) {
      case DeviceType.mobile:
        return mobile;
      case DeviceType.tablet:
        return tablet ?? mobile;
      case DeviceType.desktop:
        return desktop ?? tablet ?? mobile;
      case DeviceType.largeDesktop:
        return largeDesktop ?? desktop ?? tablet ?? mobile;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GRID COLUMNS - أعمدة الشبكة
  // ═══════════════════════════════════════════════════════════════════════════

  /// الحصول على عدد أعمدة الشبكة
  static int getGridColumns(BuildContext context) {
    return responsiveValue(
      context: context,
      mobile: 1,
      tablet: 2,
      desktop: 3,
      largeDesktop: 4,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SIDEBAR STATE - حالة القائمة الجانبية
  // ═══════════════════════════════════════════════════════════════════════════

  /// هل يجب إظهار القائمة الجانبية الكاملة؟
  static bool shouldShowFullSidebar(BuildContext context) {
    return isDesktop(context);
  }

  /// هل يجب إظهار Navigation Rail؟
  static bool shouldShowNavigationRail(BuildContext context) {
    return isTablet(context);
  }

  /// هل يجب استخدام Drawer؟
  static bool shouldUseDrawer(BuildContext context) {
    return isMobile(context);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PADDING & SPACING - الحشو والمسافات
  // ═══════════════════════════════════════════════════════════════════════════

  /// الحصول على حشو الصفحة المتجاوب
  static EdgeInsets getPagePadding(BuildContext context) {
    return responsiveValue(
      context: context,
      mobile: const EdgeInsets.all(16),
      tablet: const EdgeInsets.all(24),
      desktop: const EdgeInsets.all(32),
    );
  }

  /// الحصول على فراغ الشبكة المتجاوب
  static double getGridSpacing(BuildContext context) {
    return responsiveValue(
      context: context,
      mobile: 12.0,
      tablet: 16.0,
      desktop: 20.0,
    );
  }

  /// الحصول على نسبة أبعاد البطاقات في الشبكة
  static double getGridAspectRatio(BuildContext context) {
    return responsiveValue(
      context: context,
      mobile: 1.8,    // Mobile: Wider cards (Short height)
      tablet: 1.3,    // Tablet: Balanced
      desktop: 1.1,   // Desktop: Much Taller cards to prevent overlap
      largeDesktop: 1.25, // Large screens: Standard
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SCREEN SIZE - حجم الشاشة
  // ═══════════════════════════════════════════════════════════════════════════

  /// عرض الشاشة
  static double screenWidth(BuildContext context) {
    return MediaQuery.sizeOf(context).width;
  }

  /// ارتفاع الشاشة
  static double screenHeight(BuildContext context) {
    return MediaQuery.sizeOf(context).height;
  }

  /// نسبة العرض
  static double widthPercent(BuildContext context, double percent) {
    return screenWidth(context) * (percent / 100);
  }

  /// نسبة الارتفاع
  static double heightPercent(BuildContext context, double percent) {
    return screenHeight(context) * (percent / 100);
  }
}

/// تعداد أنواع الأجهزة
enum DeviceType {
  mobile,
  tablet,
  desktop,
  largeDesktop,
}

/// Widget لبناء UI متجاوب
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, DeviceType deviceType) builder;

  const ResponsiveBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return builder(context, ResponsiveUtils.getDeviceType(context));
  }
}

/// Widget لعرض محتوى مختلف حسب الجهاز
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;
  final Widget? largeDesktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
    this.largeDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveUtils.responsiveValue(
      context: context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
      largeDesktop: largeDesktop,
    );
  }
}


