import 'package:flutter/material.dart';
import 'app_colors.dart';

/// EdSentre Shadow System
/// نظام الظلال والارتفاعات
class AppShadows {
  AppShadows._();

  // ═══════════════════════════════════════════════════════════════════════════
  // ELEVATION LEVELS - مستويات الارتفاع
  // ═══════════════════════════════════════════════════════════════════════════

  /// بدون ظل
  static const List<BoxShadow> none = [];

  /// ظل خفيف جداً - للحدود الناعمة
  static List<BoxShadow> get xs => [
        BoxShadow(
          color: AppColors.black.withValues(alpha: 0.04),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ];

  /// ظل صغير - للبطاقات العادية
  static List<BoxShadow> get sm => [
        BoxShadow(
          color: AppColors.black.withValues(alpha: 0.05),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: AppColors.black.withValues(alpha: 0.03),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ];

  /// ظل متوسط - للبطاقات المرفوعة
  static List<BoxShadow> get md => [
        BoxShadow(
          color: AppColors.black.withValues(alpha: 0.08),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: AppColors.black.withValues(alpha: 0.04),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];

  /// ظل كبير - للعناصر المنبثقة
  static List<BoxShadow> get lg => [
        BoxShadow(
          color: AppColors.black.withValues(alpha: 0.1),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: AppColors.black.withValues(alpha: 0.05),
          blurRadius: 6,
          offset: const Offset(0, 4),
        ),
      ];

  /// ظل كبير جداً - للنوافذ المنبثقة
  static List<BoxShadow> get xl => [
        BoxShadow(
          color: AppColors.black.withValues(alpha: 0.12),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
        BoxShadow(
          color: AppColors.black.withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ];

  /// ظل ضخم - للـ Modals
  static List<BoxShadow> get xxl => [
        BoxShadow(
          color: AppColors.black.withValues(alpha: 0.15),
          blurRadius: 32,
          offset: const Offset(0, 16),
        ),
        BoxShadow(
          color: AppColors.black.withValues(alpha: 0.08),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ];

  // ═══════════════════════════════════════════════════════════════════════════
  // COLORED SHADOWS - ظلال ملونة
  // ═══════════════════════════════════════════════════════════════════════════

  /// ظل أزرق للأزرار الرئيسية
  static List<BoxShadow> get primaryGlow => [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.3),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  /// ظل أخضر للنجاح
  static List<BoxShadow> get successGlow => [
        BoxShadow(
          color: AppColors.success.withValues(alpha: 0.3),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  /// ظل أحمر للخطأ
  static List<BoxShadow> get errorGlow => [
        BoxShadow(
          color: AppColors.error.withValues(alpha: 0.3),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  /// ظل برتقالي للتحذير
  static List<BoxShadow> get warningGlow => [
        BoxShadow(
          color: AppColors.warning.withValues(alpha: 0.3),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  // ═══════════════════════════════════════════════════════════════════════════
  // INNER SHADOWS - ظلال داخلية
  // ═══════════════════════════════════════════════════════════════════════════

  /// ظل داخلي خفيف
  static List<BoxShadow> get innerSm => [
        BoxShadow(
          color: AppColors.black.withValues(alpha: 0.06),
          blurRadius: 2,
          offset: const Offset(0, 1),
          blurStyle: BlurStyle.inner,
        ),
      ];

  /// ظل داخلي متوسط
  static List<BoxShadow> get innerMd => [
        BoxShadow(
          color: AppColors.black.withValues(alpha: 0.08),
          blurRadius: 4,
          offset: const Offset(0, 2),
          blurStyle: BlurStyle.inner,
        ),
      ];

  // ═══════════════════════════════════════════════════════════════════════════
  // DARK MODE SHADOWS - ظلال الوضع الداكن
  // ═══════════════════════════════════════════════════════════════════════════

  /// ظل صغير للوضع الداكن
  static List<BoxShadow> get darkSm => [
        BoxShadow(
          color: AppColors.black.withValues(alpha: 0.3),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];

  /// ظل متوسط للوضع الداكن
  static List<BoxShadow> get darkMd => [
        BoxShadow(
          color: AppColors.black.withValues(alpha: 0.4),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ];

  /// ظل كبير للوضع الداكن
  static List<BoxShadow> get darkLg => [
        BoxShadow(
          color: AppColors.black.withValues(alpha: 0.5),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ];
}


