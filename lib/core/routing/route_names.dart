/// EdSentre Route Names
/// أسماء المسارات
class RouteNames {
  RouteNames._();

  // ═══════════════════════════════════════════════════════════════════════════
  // MAIN ROUTES - المسارات الرئيسية
  // ═══════════════════════════════════════════════════════════════════════════

  /// الصفحة الرئيسية
  static const String dashboard = '/';

  /// المجموعات
  static const String groups = '/groups';

  /// تسجيل الدخول
  static const String login = '/login';

  /// البحث
  static const String search = '/search';

  // ═══════════════════════════════════════════════════════════════════════════
  // STUDENTS - الطلاب
  // ═══════════════════════════════════════════════════════════════════════════

  /// إدارة الطلاب
  static const String students = '/students';

  /// إضافة طالب جديد
  static const String addStudent = '/students/add';

  /// تفاصيل الطالب
  static const String studentDetails = '/students/:id';

  /// كشف حساب الطالب
  static const String studentAccountStatement =
      '/students/account-statement/:id';

  // ═══════════════════════════════════════════════════════════════════════════
  // TEACHERS - المعلمين
  // ═══════════════════════════════════════════════════════════════════════════

  /// إدارة المعلمين
  static const String teachers = '/teachers';

  /// إضافة معلم جديد
  static const String addTeacher = '/teachers/add';

  /// تفاصيل المعلم
  static const String teacherDetails = '/teachers/:id';

  // ═══════════════════════════════════════════════════════════════════════════
  // PARENTS - أولياء الأمور
  // ═══════════════════════════════════════════════════════════════════════════

  /// إدارة أولياء الأمور
  static const String parents = '/parents';

  /// إضافة ولي أمر
  static const String addParent = '/parents/add';

  /// تفاصيل ولي الأمر
  static const String parentDetails = '/parents/:id';

  // ═══════════════════════════════════════════════════════════════════════════
  // SCHEDULE - الجداول
  // ═══════════════════════════════════════════════════════════════════════════

  /// إدارة الجداول
  static const String schedule = '/schedule';

  /// إضافة حصة
  static const String addSession = '/schedule/add';

  // ═══════════════════════════════════════════════════════════════════════════
  // ATTENDANCE - الحضور
  // ═══════════════════════════════════════════════════════════════════════════

  /// سجل الحضور
  static const String attendance = '/attendance';

  /// تسجيل الحضور
  static const String takeAttendance = '/attendance/take';

  // ═══════════════════════════════════════════════════════════════════════════
  // SUBJECTS - المواد
  // ═══════════════════════════════════════════════════════════════════════════

  /// إدارة المواد
  static const String subjects = '/subjects';

  /// إضافة مادة
  static const String addSubject = '/subjects/add';

  // ═══════════════════════════════════════════════════════════════════════════
  // ROOMS - القاعات
  // ═══════════════════════════════════════════════════════════════════════════

  /// إدارة القاعات
  static const String rooms = '/rooms';

  /// إضافة قاعة
  static const String addRoom = '/rooms/add';

  // ═══════════════════════════════════════════════════════════════════════════
  // PAYMENTS - المدفوعات
  // ═══════════════════════════════════════════════════════════════════════════

  /// المدفوعات
  static const String payments = '/payments';

  /// تسجيل دفعة
  static const String recordPayment = '/payments/record';

  /// المصروفات
  static const String expenses = '/expenses';

  /// التقارير المالية
  static const String financialReports = '/financial-reports';

  // ═══════════════════════════════════════════════════════════════════════════
  // REPORTS - التقارير
  // ═══════════════════════════════════════════════════════════════════════════

  /// التقارير والإحصائيات
  static const String reports = '/reports';

  /// تقرير الطلاب
  static const String studentsReport = '/reports/students';

  /// لوحة الذكاء المالي
  static const String financialInsights = '/financial-insights';

  // ═══════════════════════════════════════════════════════════════════════════
  // NOTIFICATIONS - الإشعارات
  // ═══════════════════════════════════════════════════════════════════════════

  /// الإشعارات
  static const String notifications = '/notifications';

  // ═══════════════════════════════════════════════════════════════════════════
  // SETTINGS - الإعدادات
  // ═══════════════════════════════════════════════════════════════════════════

  /// الإعدادات
  static const String settings = '/settings';
  // ═══════════════════════════════════════════════════════════════════════════
  // SUPPORT - الدعم الفني
  // ═══════════════════════════════════════════════════════════════════════════

  /// الدعم الفني
  static const String support = '/support';

  /// محادثة الدعم
  static const String supportChat = '/support/:id';

  // ═══════════════════════════════════════════════════════════════════════════
  // LIBRARY - المكتبة
  // ═══════════════════════════════════════════════════════════════════════════

  /// مكتبة مذكرات السنتر
  static const String library = '/library';
}
