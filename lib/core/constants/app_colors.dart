import 'package:flutter/material.dart';

/// EdSentre Vibrant Color System
/// نظام الألوان الحيوي والعصري
class AppColors {
  AppColors._();

  // ═══════════════════════════════════════════════════════════════════════════
  // VIBRANT PRIMARY COLORS - الألوان الأساسية الحيوية
  // ═══════════════════════════════════════════════════════════════════════════

  /// Primary Blue - أزرق حيوي وجذاب
  static const Color primary = Color(0xFF3B82F6); // Bright Blue
  static const Color primaryLight = Color(0xFF60A5FA);
  static const Color primaryDark = Color(0xFF2563EB);
  static const Color primarySurface = Color(0xFFDBEAFE);

  /// Secondary Purple - بنفسجي حيوي
  static const Color secondary = Color(0xFF8B5CF6); // Vibrant Purple
  static const Color secondaryLight = Color(0xFFA78BFA);
  static const Color secondaryDark = Color(0xFF7C3AED);
  static const Color secondarySurface = Color(0xFFF3E8FF);

  /// Accent Cyan - سيان مميز
  static const Color accent = Color(0xFF06B6D4); // Cyan
  static const Color accentLight = Color(0xFF22D3EE);
  static const Color accentDark = Color(0xFF0891B2);

  /// Orange Energy - برتقالي حيوي
  static const Color orange = Color(0xFFF97316);
  static const Color orangeLight = Color(0xFFFB923C);
  static const Color orangeSurface = Color(0xFFFFF7ED);

  /// Pink Pop - وردي مميز
  static const Color pink = Color(0xFFEC4899);
  static const Color pinkLight = Color(0xFFF472B6);
  static const Color pinkSurface = Color(0xFFFCE7F3);

  // ═══════════════════════════════════════════════════════════════════════════
  // SEMANTIC COLORS - الألوان الدلالية الحيوية
  // ═══════════════════════════════════════════════════════════════════════════

  /// Success Green - أخضر حيوي
  static const Color success = Color(0xFF22C55E); // Vibrant Green
  static const Color successLight = Color(0xFF4ADE80);
  static const Color successDark = Color(0xFF16A34A);
  static const Color successSurface = Color(0xFFDCFCE7);

  /// Warning Amber - برتقالي حيوي
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color warningLight = Color(0xFFFBBF24);
  static const Color warningDark = Color(0xFFD97706);
  static const Color warningSurface = Color(0xFFFEF3C7);

  /// Error Red - أحمر حيوي
  static const Color error = Color(0xFFEF4444); // Red
  static const Color errorLight = Color(0xFFF87171);
  static const Color errorDark = Color(0xFFDC2626);
  static const Color errorSurface = Color(0xFFFEE2E2);

  /// Info Blue - أزرق سماوي
  static const Color info = Color(0xFF0EA5E9); // Sky Blue
  static const Color infoLight = Color(0xFF38BDF8);
  static const Color infoDark = Color(0xFF0284C7);
  static const Color infoSurface = Color(0xFFE0F2FE);

  // ═══════════════════════════════════════════════════════════════════════════
  // NEUTRAL COLORS - الألوان المحايدة
  // ═══════════════════════════════════════════════════════════════════════════

  /// Light Mode Neutrals
  static const Color white = Color(0xFFFFFFFF);
  static const Color gray50 = Color(0xFFF9FAFB);
  static const Color gray100 = Color(0xFFF3F4F6);
  static const Color gray200 = Color(0xFFE5E7EB);
  static const Color gray300 = Color(0xFFD1D5DB);
  static const Color gray400 = Color(0xFF9CA3AF);
  static const Color gray500 = Color(0xFF6B7280);
  static const Color gray600 = Color(0xFF4B5563);
  static const Color gray700 = Color(0xFF374151);
  static const Color gray800 = Color(0xFF1F2937);
  static const Color gray900 = Color(0xFF111827);
  static const Color black = Color(0xFF000000);

  // ═══════════════════════════════════════════════════════════════════════════
  // LIGHT THEME COLORS - ألوان الوضع الفاتح الملونة
  // ═══════════════════════════════════════════════════════════════════════════

  static const Color lightBackground = Color(0xFFF8FAFC); // Soft blue-gray
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF1F5F9);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightDivider = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF1E293B);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightTextTertiary = Color(0xFF94A3B8);
  static const Color lightTextDisabled = Color(0xFFCBD5E1);

  // ═══════════════════════════════════════════════════════════════════════════
  // DARK THEME COLORS - ألوان الوضع الداكن
  // ═══════════════════════════════════════════════════════════════════════════

  static const Color darkBackground = Color(0xFF111827);
  static const Color darkSurface = Color(0xFF1F2937);
  static const Color darkSurfaceVariant = Color(0xFF374151);
  static const Color darkBorder = Color(0xFF374151);
  static const Color darkDivider = Color(0xFF374151);
  static const Color darkTextPrimary = Color(0xFFF9FAFB);
  static const Color darkTextSecondary = Color(0xFF9CA3AF);
  static const Color darkTextTertiary = Color(0xFF6B7280);
  static const Color darkTextDisabled = Color(0xFF4B5563);

  // ═══════════════════════════════════════════════════════════════════════════
  // SIDEBAR COLORS - ألوان القائمة الجانبية
  // ═══════════════════════════════════════════════════════════════════════════

  static const Color sidebarLight = Color(0xFFFFFFFF);
  static const Color sidebarDark = Color(0xFF1F2937);
  static const Color sidebarActiveLight = Color(0xFFDBEAFE);
  static const Color sidebarActiveDark = Color(0xFF1E3A5F);
  static const Color sidebarHoverLight = Color(0xFFF3F4F6);
  static const Color sidebarHoverDark = Color(0xFF374151);

  // ═══════════════════════════════════════════════════════════════════════════
  // CHART COLORS - ألوان الرسوم البيانية
  // ═══════════════════════════════════════════════════════════════════════════

  static const List<Color> chartColors = [
    Color(0xFF2563EB), // Blue
    Color(0xFF7C3AED), // Purple
    Color(0xFF10B981), // Green
    Color(0xFFF59E0B), // Amber
    Color(0xFFEF4444), // Red
    Color(0xFF0EA5E9), // Cyan
    Color(0xFFEC4899), // Pink
    Color(0xFF8B5CF6), // Violet
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // STATUS COLORS - ألوان الحالات
  // ═══════════════════════════════════════════════════════════════════════════

  /// حالة نشط
  static const Color statusActive = success;

  /// حالة معلق
  static const Color statusPending = warning;

  /// حالة غير نشط
  static const Color statusInactive = gray400;

  /// حالة محظور
  static const Color statusBlocked = error;

  // ═══════════════════════════════════════════════════════════════════════════
  // ALIASES - للتوافق
  // ═══════════════════════════════════════════════════════════════════════════

  static const Color textSecondary = lightTextSecondary;

  // ═══════════════════════════════════════════════════════════════════════════
  // PREMIUM GRADIENTS - التدرجات اللونية الهادئة ✨
  // ═══════════════════════════════════════════════════════════════════════════

  /// Primary Gradient - أزرق هادئ
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF5B8DEF), Color(0xFF8BA4E9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Success Gradient - أخضر هادئ
  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF4ECDC4), Color(0xFF6DD5C7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Warning Gradient - برتقالي هادئ (peach)
  static const LinearGradient warningGradient = LinearGradient(
    colors: [Color(0xFFFFB366), Color(0xFFFFCC80)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Info Gradient - سماوي هادئ
  static const LinearGradient infoGradient = LinearGradient(
    colors: [Color(0xFF5BC0DE), Color(0xFF7ED4E6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Sidebar Gradient - أزرق داكن هادئ
  static const LinearGradient sidebarGradient = LinearGradient(
    colors: [Color(0xFF2C3E50), Color(0xFF34495E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Pink Gradient - وردي هادئ (rose)
  static const LinearGradient pinkGradient = LinearGradient(
    colors: [Color(0xFFE8A0BF), Color(0xFFF0B8D0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Orange Gradient - برتقالي هادئ (coral)
  static const LinearGradient orangeGradient = LinearGradient(
    colors: [Color(0xFFFF8A65), Color(0xFFFFAB91)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Purple Gradient - بنفسجي هادئ (lavender)
  static const LinearGradient purpleGradient = LinearGradient(
    colors: [Color(0xFF9B8AB8), Color(0xFFB4A7D6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Card Gradient Light - تدرج البطاقات
  static const LinearGradient cardGradientLight = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Accent Gradient - تيركواز هادئ
  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF5FB3B3), Color(0xFF7DC8C8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );


  // ═══════════════════════════════════════════════════════════════════════════
  // SHADOWS - الظلال الاحترافية
  // ═══════════════════════════════════════════════════════════════════════════

  /// ظل خفيف
  static List<BoxShadow> get shadowSm => [
    BoxShadow(
      color: const Color(0xFF000000).withValues(alpha: 0.05),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  /// ظل متوسط
  static List<BoxShadow> get shadowMd => [
    BoxShadow(
      color: const Color(0xFF000000).withValues(alpha: 0.08),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  /// ظل كبير
  static List<BoxShadow> get shadowLg => [
    BoxShadow(
      color: const Color(0xFF000000).withValues(alpha: 0.12),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  /// ظل ملون للأزرار
  static List<BoxShadow> get primaryShadow => [
    BoxShadow(
      color: primary.withValues(alpha: 0.35),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  /// ظل ملون للنجاح
  static List<BoxShadow> get successShadow => [
    BoxShadow(
      color: success.withValues(alpha: 0.35),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];
}


