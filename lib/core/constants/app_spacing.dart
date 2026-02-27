/// EdSentre Spacing System
/// نظام المسافات والأبعاد
class AppSpacing {
  AppSpacing._();

  // ═══════════════════════════════════════════════════════════════════════════
  // BASE SPACING - المسافات الأساسية (مضاعفات 4)
  // ═══════════════════════════════════════════════════════════════════════════
  
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
  static const double huge = 40.0;
  static const double massive = 48.0;
  static const double giant = 64.0;

  // ═══════════════════════════════════════════════════════════════════════════
  // PADDING - الحشو الداخلي
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// حشو البطاقات
  static const double cardPadding = lg;
  
  /// حشو الصفحة
  static const double pagePadding = xxl;
  
  /// حشو الأزرار
  static const double buttonPaddingHorizontal = lg;
  static const double buttonPaddingVertical = md;
  
  /// حشو حقول الإدخال
  static const double inputPaddingHorizontal = md;
  static const double inputPaddingVertical = md;
  
  /// حشو القائمة الجانبية
  static const double sidebarPadding = lg;
  
  /// حشو عناصر القائمة
  static const double menuItemPadding = md;

  // ═══════════════════════════════════════════════════════════════════════════
  // GAPS - الفراغات بين العناصر
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// فراغ صغير جداً
  static const double gapXs = xs;
  
  /// فراغ صغير
  static const double gapSm = sm;
  
  /// فراغ متوسط
  static const double gapMd = md;
  
  /// فراغ كبير
  static const double gapLg = lg;
  
  /// فراغ كبير جداً
  static const double gapXl = xxl;
  
  /// فراغ بين أقسام الصفحة
  static const double sectionGap = xxxl;

  // ═══════════════════════════════════════════════════════════════════════════
  // BORDER RADIUS - انحناءات الحواف
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// بدون انحناء
  static const double radiusNone = 0.0;
  
  /// انحناء صغير
  static const double radiusSm = 4.0;
  
  /// انحناء متوسط
  static const double radiusMd = 8.0;
  
  /// انحناء كبير
  static const double radiusLg = 12.0;
  
  /// انحناء كبير جداً
  static const double radiusXl = 16.0;
  
  /// انحناء دائري
  static const double radiusXxl = 24.0;
  
  /// دائري كامل
  static const double radiusFull = 999.0;

  // ═══════════════════════════════════════════════════════════════════════════
  // SIZES - الأحجام الثابتة
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// عرض القائمة الجانبية المفتوحة
  static const double sidebarExpandedWidth = 240.0;
  
  /// عرض القائمة الجانبية المصغرة
  static const double sidebarCollapsedWidth = 72.0;
  
  /// ارتفاع شريط الأدوات
  static const double appBarHeight = 64.0;
  
  /// ارتفاع الأزرار
  static const double buttonHeight = 44.0;
  
  /// ارتفاع الأزرار الصغيرة
  static const double buttonHeightSm = 36.0;
  
  /// ارتفاع الأزرار الكبيرة
  static const double buttonHeightLg = 52.0;
  
  /// ارتفاع حقول الإدخال
  static const double inputHeight = 48.0;
  
  /// حجم الأيقونات الصغيرة
  static const double iconSizeSm = 16.0;
  
  /// حجم الأيقونات المتوسطة
  static const double iconSizeMd = 20.0;
  
  /// حجم الأيقونات الكبيرة
  static const double iconSizeLg = 24.0;
  
  /// حجم الأيقونات الكبيرة جداً
  static const double iconSizeXl = 32.0;
  
  /// حجم الصورة الرمزية الصغيرة
  static const double avatarSm = 32.0;
  
  /// حجم الصورة الرمزية المتوسطة
  static const double avatarMd = 40.0;
  
  /// حجم الصورة الرمزية الكبيرة
  static const double avatarLg = 56.0;
  
  /// حجم الصورة الرمزية الكبيرة جداً
  static const double avatarXl = 80.0;

  // ═══════════════════════════════════════════════════════════════════════════
  // GRID - شبكة التخطيط
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// فراغ الشبكة
  static const double gridSpacing = lg;
  
  /// عدد أعمدة الموبايل
  static const int gridColumnsMobile = 1;
  
  /// عدد أعمدة التابلت
  static const int gridColumnsTablet = 2;
  
  /// عدد أعمدة الديسكتوب
  static const int gridColumnsDesktop = 3;
  
  /// عدد أعمدة الشاشات الكبيرة
  static const int gridColumnsLarge = 4;
}


