import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// EdSentre Typography System
/// نظام الخطوط مع دعم كامل للعربية باستخدام خط Cairo
class AppTypography {
  AppTypography._();

  // ═══════════════════════════════════════════════════════════════════════════
  // FONT FAMILY - عائلة الخطوط
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// خط Cairo للعربية والإنجليزية
  static String get fontFamily => GoogleFonts.cairo().fontFamily!;

  // ═══════════════════════════════════════════════════════════════════════════
  // FONT WEIGHTS - أوزان الخطوط
  // ═══════════════════════════════════════════════════════════════════════════
  
  static const FontWeight light = FontWeight.w300;
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight extraBold = FontWeight.w800;

  // ═══════════════════════════════════════════════════════════════════════════
  // FONT SIZES - أحجام الخطوط
  // ═══════════════════════════════════════════════════════════════════════════
  
  static const double displayLarge = 32.0;
  static const double displayMedium = 28.0;
  static const double displaySmall = 24.0;
  
  static const double headlineLarge = 24.0;
  static const double headlineMedium = 20.0;
  static const double headlineSmall = 18.0;
  
  static const double titleLarge = 18.0;
  static const double titleMedium = 16.0;
  static const double titleSmall = 14.0;
  
  static const double bodyLarge = 16.0;
  static const double bodyMedium = 14.0;
  static const double bodySmall = 12.0;
  
  static const double labelLarge = 14.0;
  static const double labelMedium = 12.0;
  static const double labelSmall = 11.0;

  // ═══════════════════════════════════════════════════════════════════════════
  // LINE HEIGHTS - ارتفاعات الأسطر
  // ═══════════════════════════════════════════════════════════════════════════
  
  static const double lineHeightTight = 1.2;
  static const double lineHeightNormal = 1.5;
  static const double lineHeightRelaxed = 1.75;

  // ═══════════════════════════════════════════════════════════════════════════
  // TEXT STYLES - أنماط النصوص
  // ═══════════════════════════════════════════════════════════════════════════

  /// عنوان كبير جداً - للصفحات الرئيسية
  static TextStyle get displayLargeStyle => GoogleFonts.cairo(
        fontSize: displayLarge,
        fontWeight: bold,
        height: lineHeightTight,
      );

  /// عنوان كبير - لعناوين الأقسام الرئيسية
  static TextStyle get displayMediumStyle => GoogleFonts.cairo(
        fontSize: displayMedium,
        fontWeight: bold,
        height: lineHeightTight,
      );

  /// عنوان الصفحة
  static TextStyle get headlineLargeStyle => GoogleFonts.cairo(
        fontSize: headlineLarge,
        fontWeight: semiBold,
        height: lineHeightTight,
      );

  /// عنوان القسم
  static TextStyle get headlineMediumStyle => GoogleFonts.cairo(
        fontSize: headlineMedium,
        fontWeight: semiBold,
        height: lineHeightTight,
      );

  /// عنوان فرعي
  static TextStyle get headlineSmallStyle => GoogleFonts.cairo(
        fontSize: headlineSmall,
        fontWeight: semiBold,
        height: lineHeightTight,
      );

  /// عنوان البطاقة
  static TextStyle get titleLargeStyle => GoogleFonts.cairo(
        fontSize: titleLarge,
        fontWeight: medium,
        height: lineHeightNormal,
      );

  /// عنوان صغير
  static TextStyle get titleMediumStyle => GoogleFonts.cairo(
        fontSize: titleMedium,
        fontWeight: medium,
        height: lineHeightNormal,
      );

  /// عنوان أصغر
  static TextStyle get titleSmallStyle => GoogleFonts.cairo(
        fontSize: titleSmall,
        fontWeight: medium,
        height: lineHeightNormal,
      );

  /// النص الأساسي الكبير
  static TextStyle get bodyLargeStyle => GoogleFonts.cairo(
        fontSize: bodyLarge,
        fontWeight: regular,
        height: lineHeightNormal,
      );

  /// النص الأساسي
  static TextStyle get bodyMediumStyle => GoogleFonts.cairo(
        fontSize: bodyMedium,
        fontWeight: regular,
        height: lineHeightNormal,
      );

  /// النص الصغير
  static TextStyle get bodySmallStyle => GoogleFonts.cairo(
        fontSize: bodySmall,
        fontWeight: regular,
        height: lineHeightNormal,
      );

  /// تسمية الأزرار
  static TextStyle get labelLargeStyle => GoogleFonts.cairo(
        fontSize: labelLarge,
        fontWeight: medium,
        height: lineHeightTight,
      );

  /// تسمية متوسطة
  static TextStyle get labelMediumStyle => GoogleFonts.cairo(
        fontSize: labelMedium,
        fontWeight: medium,
        height: lineHeightTight,
      );

  static TextStyle get labelSmallStyle => GoogleFonts.cairo(
        fontSize: labelSmall,
        fontWeight: regular,
        height: lineHeightTight,
      );

  // ═══════════════════════════════════════════════════════════════════════════
  // ALIASES - للتوافق مع الأنماط القديمة
  // ═══════════════════════════════════════════════════════════════════════════
  
  static TextStyle get h1 => displayLargeStyle;
  static TextStyle get h2 => displayMediumStyle;
  static TextStyle get h3 => headlineLargeStyle;  
  static TextStyle get body1 => bodyLargeStyle;
  static TextStyle get body2 => bodyMediumStyle;
  static TextStyle get caption => bodySmallStyle;


  // ═══════════════════════════════════════════════════════════════════════════
  // TEXT THEME - ثيم النصوص للـ Material
  // ═══════════════════════════════════════════════════════════════════════════
  
  static TextTheme get textTheme => TextTheme(
        displayLarge: displayLargeStyle,
        displayMedium: displayMediumStyle,
        displaySmall: GoogleFonts.cairo(
          fontSize: displaySmall,
          fontWeight: bold,
          height: lineHeightTight,
        ),
        headlineLarge: headlineLargeStyle,
        headlineMedium: headlineMediumStyle,
        headlineSmall: headlineSmallStyle,
        titleLarge: titleLargeStyle,
        titleMedium: titleMediumStyle,
        titleSmall: titleSmallStyle,
        bodyLarge: bodyLargeStyle,
        bodyMedium: bodyMediumStyle,
        bodySmall: bodySmallStyle,
        labelLarge: labelLargeStyle,
        labelMedium: labelMediumStyle,
        labelSmall: labelSmallStyle,
      );
}


