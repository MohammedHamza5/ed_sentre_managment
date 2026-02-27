import 'package:flutter/material.dart';

/// EdSentre Extensions
/// إضافات مفيدة للـ Flutter
extension ContextExtensions on BuildContext {
  /// الحصول على ThemeData
  ThemeData get theme => Theme.of(this);

  /// الحصول على ColorScheme
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// الحصول على TextTheme
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// هل الوضع الداكن مفعل؟
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  /// عرض الشاشة
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// ارتفاع الشاشة
  double get screenHeight => MediaQuery.sizeOf(this).height;

  /// حجم الشاشة
  Size get screenSize => MediaQuery.sizeOf(this);

  /// هل الشاشة موبايل؟
  bool get isMobile => screenWidth < 600;

  /// هل الشاشة تابلت؟
  bool get isTablet => screenWidth >= 600 && screenWidth < 1024;

  /// هل الشاشة ديسكتوب؟
  bool get isDesktop => screenWidth >= 1024;

  /// عرض SnackBar
  void showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? colorScheme.error : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// عرض Dialog
  Future<T?> showAppDialog<T>({
    required Widget child,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: this,
      barrierDismissible: barrierDismissible,
      builder: (context) => child,
    );
  }
}

extension StringExtensions on String {
  /// تحويل لـ Title Case
  String get toTitleCase {
    if (isEmpty) return this;
    return split(' ').map((word) {
      if (word.isEmpty) return word;
      return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
    }).join(' ');
  }

  /// هل النص فارغ أو null؟
  bool get isNullOrEmpty => isEmpty;

  /// هل النص ليس فارغاً؟
  bool get isNotNullOrEmpty => isNotEmpty;

  /// تقصير النص
  String truncate(int maxLength, {String suffix = '...'}) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength)}$suffix';
  }
}

extension NumExtensions on num {
  /// تحويل لـ SizedBox عرض
  SizedBox get horizontalSpace => SizedBox(width: toDouble());

  /// تحويل لـ SizedBox ارتفاع
  SizedBox get verticalSpace => SizedBox(height: toDouble());

  /// تحويل لـ EdgeInsets متساوي
  EdgeInsets get allPadding => EdgeInsets.all(toDouble());

  /// تحويل لـ EdgeInsets أفقي
  EdgeInsets get horizontalPadding => EdgeInsets.symmetric(horizontal: toDouble());

  /// تحويل لـ EdgeInsets عمودي
  EdgeInsets get verticalPadding => EdgeInsets.symmetric(vertical: toDouble());

  /// تحويل لـ Duration بالميلي ثانية
  Duration get milliseconds => Duration(milliseconds: toInt());

  /// تحويل لـ Duration بالثواني
  Duration get seconds => Duration(seconds: toInt());

  /// تنسيق كعملة
  String toCurrency({String symbol = 'ج.م'}) {
    return '${toStringAsFixed(0)} $symbol';
  }

  /// تنسيق كنسبة مئوية
  String toPercentage() {
    return '${toStringAsFixed(0)}%';
  }
}

extension DateTimeExtensions on DateTime {
  /// تنسيق التاريخ بالعربية
  String toArabicDate() {
    return '$day/$month/$year';
  }

  /// تنسيق الوقت
  String toTime() {
    final hour = this.hour.toString().padLeft(2, '0');
    final minute = this.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// تنسيق التاريخ والوقت
  String toFullDateTime() {
    return '${toArabicDate()} - ${toTime()}';
  }

  /// هل هو اليوم؟
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// هل هو الأمس؟
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year && 
           month == yesterday.month && 
           day == yesterday.day;
  }
}

extension ListExtensions<T> on List<T> {
  /// الحصول على عنصر آمن
  T? getOrNull(int index) {
    if (index < 0 || index >= length) return null;
    return this[index];
  }

  /// تقسيم القائمة إلى مجموعات
  List<List<T>> chunked(int size) {
    final chunks = <List<T>>[];
    for (var i = 0; i < length; i += size) {
      chunks.add(sublist(i, i + size > length ? length : i + size));
    }
    return chunks;
  }
}

extension WidgetExtensions on Widget {
  /// إضافة Padding
  Widget padded(EdgeInsets padding) {
    return Padding(padding: padding, child: this);
  }

  /// إضافة Padding متساوي
  Widget paddedAll(double value) {
    return Padding(padding: EdgeInsets.all(value), child: this);
  }

  /// إضافة Padding أفقي
  Widget paddedHorizontal(double value) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: value),
      child: this,
    );
  }

  /// إضافة Padding عمودي
  Widget paddedVertical(double value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: value),
      child: this,
    );
  }

  /// تمركز
  Widget centered() {
    return Center(child: this);
  }

  /// إضافة Expanded
  Widget expanded({int flex = 1}) {
    return Expanded(flex: flex, child: this);
  }

  /// إضافة Flexible
  Widget flexible({int flex = 1}) {
    return Flexible(flex: flex, child: this);
  }

  /// إخفاء بشرط
  Widget visible(bool isVisible) {
    return Visibility(visible: isVisible, child: this);
  }

  /// تطبيق Opacity
  Widget withOpacity(double opacity) {
    return Opacity(opacity: opacity, child: this);
  }
}


