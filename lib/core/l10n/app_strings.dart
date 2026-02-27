import 'package:flutter/material.dart';

/// فئة سلاسل التطبيق للترجمة
class AppStrings {
  final Locale locale;

  AppStrings(this.locale);

  static AppStrings of(BuildContext context) {
    return Localizations.of<AppStrings>(context, AppStrings) ??
        AppStrings(const Locale('ar'));
  }

  bool get isArabic => locale.languageCode == 'ar';

  // ═══════════════════════════════════════════════════════════════════════════
  // App General
  // ═══════════════════════════════════════════════════════════════════════════
  String get appName =>
      isArabic ? 'EdSentre - إدارة السنتر' : 'EdSentre - Center Management';
  String get save => isArabic ? 'حفظ' : 'Save';
  String get cancel => isArabic ? 'إلغاء' : 'Cancel';
  String get delete => isArabic ? 'حذف' : 'Delete';
  String get edit => isArabic ? 'تعديل' : 'Edit';
  String get add => isArabic ? 'إضافة' : 'Add';
  String get close => isArabic ? 'إغلاق' : 'Close';
  String get search => isArabic ? 'بحث...' : 'Search...';
  String get all => isArabic ? 'الكل' : 'All';
  String get viewAll => isArabic ? 'عرض الكل' : 'View All';
  String get retry => isArabic ? 'إعادة المحاولة' : 'Retry';
  String get loading => isArabic ? 'جاري التحميل...' : 'Loading...';
  String get noData => isArabic ? 'لا توجد بيانات' : 'No data';
  String get error => isArabic ? 'خطأ' : 'Error';
  String get errorOccurred =>
      isArabic ? 'حدث خطأ غير متوقع' : 'An unexpected error occurred';
  String get success => isArabic ? 'نجاح' : 'Success';
  String get saveSuccess => isArabic ? 'تم الحفظ بنجاح' : 'Saved successfully';
  String get export => isArabic ? 'تصدير' : 'Export';
  String get download => isArabic ? 'تحميل' : 'Download';
  String get number => isArabic ? 'رقم' : 'No.';

  // ═══════════════════════════════════════════════════════════════════════════
  // Navigation / Sidebar
  // ═══════════════════════════════════════════════════════════════════════════
  String get dashboard => isArabic ? 'الرئيسية' : 'Dashboard';
  String get students => isArabic ? 'الطلاب' : 'Students';
  String get teachers => isArabic ? 'المعلمين' : 'Teachers';
  String get subjects => isArabic ? 'المواد' : 'Subjects';
  String get rooms => isArabic ? 'القاعات' : 'Rooms';
  String get schedule => isArabic ? 'الجداول' : 'Schedule';
  String get payments => isArabic ? 'المدفوعات' : 'Payments';
  String get reports => isArabic ? 'التقارير' : 'Reports';
  String get notifications => isArabic ? 'الإشعارات' : 'Notifications';
  String get settings => isArabic ? 'الإعدادات' : 'Settings';
  String get attendance => isArabic ? 'الحضور' : 'Attendance';
  String get testSearch => isArabic ? 'اختبار البحث' : 'Test Search';
  String get studentsDemo => isArabic ? 'عرض توضيحي للطلاب' : 'Students Demo';

  // ═══════════════════════════════════════════════════════════════════════════
  // Authentication
  // ═══════════════════════════════════════════════════════════════════════════
  String get login => isArabic ? 'تسجيل الدخول' : 'Login';
  String get logout => isArabic ? 'تسجيل الخروج' : 'Logout';
  String get password => isArabic ? 'كلمة المرور' : 'Password';
  String get forgotPassword =>
      isArabic ? 'نسيت كلمة المرور؟' : 'Forgot Password?';
  String get rememberMe => isArabic ? 'تذكرني' : 'Remember Me';
  String get loginFailed => isArabic ? 'فشل تسجيل الدخول' : 'Login Failed';
  String get invalidCredentials => isArabic
      ? 'البريد الإلكتروني أو كلمة المرور غير صحيحة'
      : 'Invalid email or password';
  String get resetPassword =>
      isArabic ? 'إعادة تعيين كلمة المرور' : 'Reset Password';
  String get sendResetLink =>
      isArabic ? 'إرسال رابط إعادة التعيين' : 'Send Reset Link';
  String get resetLinkSent =>
      isArabic ? 'تم إرسال رابط إعادة التعيين' : 'Reset link sent';

  // ═══════════════════════════════════════════════════════════════════════════════════
  // Attendance
  // ═══════════════════════════════════════════════════════════════════════════
  String get takeAttendance => isArabic ? 'تسجيل الحضور' : 'Take Attendance';
  String get selectDate => isArabic ? 'اختر التاريخ' : 'Select Date';
  String get selectSession => isArabic ? 'اختر الحصة' : 'Select Session';
  String get present => isArabic ? 'حاضر' : 'Present';
  String get absent => isArabic ? 'غائب' : 'Absent';
  String get late => isArabic ? 'متأخر' : 'Late';
  String get excused => isArabic ? 'بعذر' : 'Excused';
  String get noAttendanceRecords =>
      isArabic ? 'لا توجد سجلات حضور' : 'No attendance records';
  String get noSessionsToday =>
      isArabic ? 'لا توجد حصص اليوم' : 'No sessions today';
  String get markAllPresent => isArabic ? 'حضور الكل' : 'Mark All Present';
  String get markAllAbsent => isArabic ? 'غياب الكل' : 'Mark All Absent';
  String get saveAttendance => isArabic ? 'حفظ الحضور' : 'Save Attendance';
  String get attendanceSaved => isArabic ? 'تم حفظ الحضور' : 'Attendance saved';
  String get saving => isArabic ? 'جاري الحفظ...' : 'Saving...';

  // ═══════════════════════════════════════════════════════════════════════════
  // Dashboard
  // ═══════════════════════════════════════════════════════════════════════════
  String get welcome => isArabic ? 'مرحباً' : 'Welcome';
  String get totalStudents => isArabic ? 'إجمالي الطلاب' : 'Total Students';
  String get activeStudents => isArabic ? 'الطلاب النشطين' : 'Active Students';
  String get totalTeachers => isArabic ? 'إجمالي المعلمين' : 'Total Teachers';
  String get todayRevenue => isArabic ? 'إيرادات اليوم' : 'Today Revenue';
  String get monthlyRevenue =>
      isArabic ? 'الإيرادات الشهرية' : 'Monthly Revenue';
  String get monthlyExpenses =>
      isArabic ? 'المصروفات الشهرية' : 'Monthly Expenses';
  String get netProfit => isArabic ? 'صافي الربح' : 'Net Profit';
  String get overduePayments =>
      isArabic ? 'مدفوعات متأخرة' : 'Overdue Payments';
  String get needsFollowUp => isArabic ? 'تحتاج متابعة' : 'Needs Follow-up';

  String get todaySessions => isArabic ? 'حصص اليوم' : 'Today Sessions';
  String get completedSessions => isArabic ? 'مكتملة' : 'Completed';
  String get attendanceRate => isArabic ? 'نسبة الحضور' : 'Attendance Rate';
  String get todaySchedule => isArabic ? 'جدول اليوم' : 'Today Schedule';
  String get recentNotifications =>
      isArabic ? 'آخر الإشعارات' : 'Recent Notifications';
  String get addNewStudent => isArabic ? 'إضافة طالب جديد' : 'Add New Student';
  String get weeklyAttendance =>
      isArabic ? 'الحضور الأسبوعي' : 'Weekly Attendance';
  String get studentDistribution =>
      isArabic ? 'توزيع الطلاب' : 'Student Distribution';
  String get monthlyRevenueChart =>
      isArabic ? 'الإيرادات الشهرية' : 'Monthly Revenue';

  // ═══════════════════════════════════════════════════════════════════════════
  // Students
  // ═══════════════════════════════════════════════════════════════════════════
  String get studentManagement =>
      isArabic ? 'إدارة الطلاب' : 'Student Management';
  String get addStudent => isArabic ? 'إضافة طالب' : 'Add Student';
  String get editStudent => isArabic ? 'تعديل بيانات الطالب' : 'Edit Student';
  String get deleteStudent => isArabic ? 'حذف الطالب' : 'Delete Student';
  String get studentName => isArabic ? 'اسم الطالب' : 'Student Name';
  String get phone => isArabic ? 'رقم الهاتف' : 'Phone';
  String get email => isArabic ? 'البريد الإلكتروني' : 'Email';
  String get address => isArabic ? 'العنوان' : 'Address';
  String get stage => isArabic ? 'المرحلة' : 'Stage';
  String get status => isArabic ? 'الحالة' : 'Status';
  String get lastAttendance => isArabic ? 'آخر حضور' : 'Last Attendance';
  String get actions => isArabic ? 'إجراءات' : 'Actions';
  String get active => isArabic ? 'نشط' : 'Active';
  String get suspended => isArabic ? 'معلق' : 'Suspended';
  String get overdue => isArabic ? 'متأخر' : 'Overdue';
  String get inactive => isArabic ? 'غير نشط' : 'Inactive';
  String get noStudents => isArabic ? 'لا يوجد طلاب' : 'No students';
  String get searchByNameOrPhone =>
      isArabic ? 'بحث بالاسم أو رقم الهاتف...' : 'Search by name or phone...';
  String get confirmDeleteStudent => isArabic
      ? 'هل أنت متأكد من حذف الطالب'
      : 'Are you sure you want to delete student';
  String get studentDeleted => isArabic ? 'تم حذف الطالب' : 'Student deleted';
  String get studentUpdated =>
      isArabic ? 'تم تحديث بيانات الطالب' : 'Student updated';
  String get registrationDate =>
      isArabic ? 'تاريخ التسجيل' : 'Registration Date';

  // ═══════════════════════════════════════════════════════════════════════════
  // Groups
  // ═══════════════════════════════════════════════════════════════════════════
  String get groups => isArabic ? 'المجموعات' : 'Groups';
  String get groupManagement => isArabic ? 'إدارة المجموعات' : 'Group Management';
  String get addGroup => isArabic ? 'إضافة مجموعة' : 'Add Group';
  String get editGroup => isArabic ? 'تعديل المجموعة' : 'Edit Group';
  String get deleteGroup => isArabic ? 'حذف المجموعة' : 'Delete Group';
  String get groupName => isArabic ? 'اسم المجموعة' : 'Group Name';
  String get noGroups => isArabic ? 'لا توجد مجموعات' : 'No groups';
  String get maxStudents => isArabic ? 'الحد الأقصى للطلاب' : 'Max Students';
  String get currentStudents => isArabic ? 'الطلاب الحاليين' : 'Current Students';

  // ═══════════════════════════════════════════════════════════════════════════
  // Teachers
  // ═══════════════════════════════════════════════════════════════════════════
  String get teacherManagement =>
      isArabic ? 'إدارة المعلمين' : 'Teacher Management';
  String get addTeacher => isArabic ? 'إضافة معلم' : 'Add Teacher';
  String get editTeacher => isArabic ? 'تعديل بيانات المعلم' : 'Edit Teacher';
  String get teacherName => isArabic ? 'اسم المعلم' : 'Teacher Name';
  String get specialty => isArabic ? 'التخصص' : 'Specialty';
  String get salary => isArabic ? 'الراتب' : 'Salary';
  String get salaryType => isArabic ? 'نوع الراتب' : 'Salary Type';
  String get fixedSalary => isArabic ? 'راتب ثابت' : 'Fixed Salary';
  String get percentage => isArabic ? 'نسبة مئوية' : 'Percentage';
  String get perSession => isArabic ? 'لكل حصة' : 'Per Session';
  String get rating => isArabic ? 'التقييم' : 'Rating';
  String get noTeachers => isArabic ? 'لا يوجد معلمون' : 'No teachers';
  String get viewSchedule => isArabic ? 'عرض الجدول' : 'View Schedule';
  String get teacherSchedule => isArabic ? 'جدول المعلم' : 'Teacher Schedule';
  String get noSessionsForTeacher =>
      isArabic ? 'لا توجد حصص لهذا المعلم' : 'No sessions for this teacher';
  String get canLinkSubjectsLater => isArabic
      ? 'يمكنك ربط المعلم بالمواد لاحقاً من صفحة المواد'
      : 'You can link subjects later from Subjects page';

  // ═══════════════════════════════════════════════════════════════════════════
  // Subjects
  // ═══════════════════════════════════════════════════════════════════════════
  String get subjectManagement =>
      isArabic ? 'إدارة المواد' : 'Subject Management';
  String get subjectsManagement => subjectManagement;
  String get addSubject => isArabic ? 'إضافة مادة' : 'Add Subject';
  String get subjectName => isArabic ? 'اسم المادة' : 'Subject Name';
  String get description => isArabic ? 'الوصف' : 'Description';
  String get monthlyFee => isArabic ? 'الرسوم الشهرية' : 'Monthly Fee';
  String get deleteSubject => isArabic ? 'حذف المادة' : 'Delete Subject';
  String get selectSubject => isArabic ? 'اختر مادة' : 'Select Subject';
  String get subjectAdded => isArabic ? 'تم إضافة المادة' : 'Subject Added';
  String get subjectDeleted => isArabic ? 'تم حذف المادة' : 'Subject Deleted';

  // Session
  String get cancelSession => isArabic ? 'إلغاء الحصة' : 'Cancel Session';
  String get restoreSession => isArabic ? 'استعادة الحصة' : 'Restore Session';
  String get confirmCancelSession => isArabic ? 'تأكيد إلغاء الحصة' : 'Confirm Cancel Session';
  String get confirmRestoreSession => isArabic ? 'تأكيد استعادة الحصة' : 'Confirm Restore Session';
  String get cancelSessionWarning => isArabic
      ? 'هل أنت متأكد أنك تريد إلغاء هذه الحصة؟ سيتم تغيير حالتها إلى "ملغاة" ولكن لن يتم حذفها من الجدول.'
      : 'Are you sure you want to cancel this session? Its status will be changed to "Cancelled" but it will not be removed from the schedule.';
  String get restoreSessionWarning => isArabic
      ? 'هل تريد إعادة تفعيل هذا الحصة؟'
      : 'Do you want to restore this session?';
  String get sessionCancelled => isArabic ? 'تم إلغاء الحصة' : 'Session Cancelled';
  String get sessionRestored => isArabic ? 'تم استعادة الحصة' : 'Session Restored';
  String get noSubjects => isArabic ? 'لا توجد مواد' : 'No subjects';
  String get subjectsManagementSubtitle => isArabic
      ? 'إدارة المواد الدراسية في السنتر'
      : 'Manage your center courses and subjects';

  // ═══════════════════════════════════════════════════════════════════════════
  // Rooms
  // ═══════════════════════════════════════════════════════════════════════════
  String get roomManagement => isArabic ? 'إدارة القاعات' : 'Room Management';
  String get roomsManagement => roomManagement;
  String get roomsManagementSubtitle => isArabic
      ? 'إدارة القاعات الدراسية والتجهيزات'
      : 'Manage classrooms and facilities';
  String get allRooms => isArabic ? 'كل القاعات' : 'All Rooms';
  String get addRoom => isArabic ? 'إضافة قاعة' : 'Add Room';
  String get roomName => isArabic ? 'اسم القاعة' : 'Room Name';
  String get roomNumber => isArabic ? 'رقم القاعة' : 'Room Number';
  String get capacity => isArabic ? 'السعة' : 'Capacity';
  String get equipment => isArabic ? 'التجهيزات' : 'Equipment';
  String get available => isArabic ? 'متاحة' : 'Available';
  String get occupied => isArabic ? 'مشغولة' : 'Occupied';
  String get maintenance => isArabic ? 'صيانة' : 'Maintenance';
  String get noRooms => isArabic ? 'لا توجد قاعات' : 'No rooms';
  String get statusUpdated => isArabic ? 'تم تحديث الحالة' : 'Status updated';
  List<String> get equipmentList => isArabic
      ? ['بروجيكتور', 'سبورة ذكية', 'تكييف', 'صوت', 'كاميرا']
      : ['Projector', 'Smart Board', 'AC', 'Sound System', 'Camera'];

  // ═══════════════════════════════════════════════════════════════════════════
  // Schedule
  // ═══════════════════════════════════════════════════════════════════════════
  String get sessionSchedule => isArabic ? 'جدول الحصص' : 'Session Schedule';
  String get addSession => isArabic ? 'إضافة حصة' : 'Add Session';
  String get day => isArabic ? 'اليوم' : 'Day';
  String get today => isArabic ? 'اليوم' : 'Today';
  String get time => isArabic ? 'الوقت' : 'Time';
  String get subject => isArabic ? 'المادة' : 'Subject';
  String get teacher => isArabic ? 'المعلم' : 'Teacher';
  String get room => isArabic ? 'القاعة' : 'Room';
  String get scheduled => isArabic ? 'مجدولة' : 'Scheduled';
  String get ongoing => isArabic ? 'جارية' : 'Ongoing';
  String get completed => isArabic ? 'مكتملة' : 'Completed';
  String get cancelled => isArabic ? 'ملغية' : 'Cancelled';
  String get sessionAdded =>
      isArabic ? 'تم إضافة الحصة بنجاح' : 'Session added successfully';
  String get sessionDeleted => isArabic ? 'تم حذف الحصة' : 'Session deleted';
  String get fillAllFields =>
      isArabic ? 'يرجى ملء جميع الحقول' : 'Please fill all fields';

  // Days of week
  String get saturday => isArabic ? 'السبت' : 'Saturday';
  String get sunday => isArabic ? 'الأحد' : 'Sunday';
  String get monday => isArabic ? 'الإثنين' : 'Monday';
  String get tuesday => isArabic ? 'الثلاثاء' : 'Tuesday';
  String get wednesday => isArabic ? 'الأربعاء' : 'Wednesday';
  String get thursday => isArabic ? 'الخميس' : 'Thursday';
  String get friday => isArabic ? 'الجمعة' : 'Friday';

  List<String> get daysList => isArabic
      ? [
          'السبت',
          'الأحد',
          'الإثنين',
          'الثلاثاء',
          'الأربعاء',
          'الخميس',
          'الجمعة',
        ]
      : ['Saturday', 'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday'];

  // ═══════════════════════════════════════════════════════════════════════════
  // Payments
  // ═══════════════════════════════════════════════════════════════════════════
  String get paymentManagement =>
      isArabic ? 'إدارة المدفوعات' : 'Payment Management';
  String get paymentsAndExpenses =>
      isArabic ? 'المدفوعات والمصروفات' : 'Payments & Expenses';
  String get paymentHistory => isArabic ? 'سجل المدفوعات' : 'Payment History';
  String get recordPayment => isArabic ? 'تسجيل دفعة' : 'Record Payment';
  String get recordNewPayment =>
      isArabic ? 'تسجيل دفعة جديدة' : 'Record New Payment';
  String get recordPaymentFor =>
      isArabic ? 'تسجيل دفعة لـ' : 'Record payment for';
  String get amount => isArabic ? 'المبلغ' : 'Amount';
  String get paidAmount => isArabic ? 'المدفوع' : 'Paid';
  String get remainingAmount =>
      isArabic ? 'المبلغ المتبقي' : 'Remaining Amount';
  String get remaining => isArabic ? 'متبقي' : 'Remaining';
  String get dueDate => isArabic ? 'تاريخ الاستحقاق' : 'Due Date';
  String get paidDate => isArabic ? 'تاريخ الدفع' : 'Paid Date';
  String get paymentMethod => isArabic ? 'طريقة الدفع' : 'Payment Method';
  String get cash => isArabic ? 'نقدي' : 'Cash';
  String get bankTransfer => isArabic ? 'تحويل بنكي' : 'Bank Transfer';
  String get vodafoneCash => isArabic ? 'فودافون كاش' : 'Vodafone Cash';
  String get instaPay => isArabic ? 'انستاباي' : 'InstaPay';
  String get paid => isArabic ? 'مدفوع' : 'Paid';
  String get pending => isArabic ? 'معلق' : 'Pending';
  String get partial => isArabic ? 'جزئي' : 'Partial';
  String get enterValidAmount =>
      isArabic ? 'يرجى إدخال مبلغ صالح' : 'Please enter a valid amount';
  String get paymentRecorded =>
      isArabic ? 'تم تسجيل الدفعة' : 'Payment recorded';
  String get receipt => isArabic ? 'إيصال' : 'Receipt';
  String get generatingReceipt =>
      isArabic ? 'جاري إنشاء الإيصال...' : 'Generating receipt...';
  String get student => isArabic ? 'الطالب' : 'Student';
  String get month => isArabic ? 'الشهر' : 'Month';
  String get noPayments => isArabic ? 'لا توجد مدفوعات' : 'No payments';
  String get selectStudent => isArabic ? 'اختر الطالب' : 'Select Student';
  String get selectMonth => isArabic ? 'اختر الشهر' : 'Select Month';
  String get recordExpense => isArabic ? 'تسجيل مصروف' : 'Record Expense';
  String get expenseTitle => isArabic ? 'بيان المصروف' : 'Expense Title';
  String get expenseCategory => isArabic ? 'فئة المصروف' : 'Expense Category';
  String get expenseRecorded => isArabic ? 'تم تسجيل المصروف' : 'Expense recorded';
  String get noExpenses => isArabic ? 'لا توجد مصروفات مسجلة' : 'No expenses recorded';
  String get rent => isArabic ? 'إيجار' : 'Rent';
  String get utilities => isArabic ? 'مرافق (كهرباء/مياه)' : 'Utilities';
  String get supplies => isArabic ? 'أدوات ومستلزمات' : 'Supplies';
  String get other => isArabic ? 'أخرى' : 'Other';
  String get date => isArabic ? 'التاريخ' : 'Date';
  String get expenses => isArabic ? 'المصروفات' : 'Expenses';

  // ═══════════════════════════════════════════════════════════════════════════
  // Reports
  // ═══════════════════════════════════════════════════════════════════════════
  String get reportManagement => isArabic ? 'التقارير' : 'Reports';
  String get reportsAndStatistics =>
      isArabic ? 'التقارير والإحصائيات' : 'Reports & Statistics';
  String get generateReport => isArabic ? 'إنشاء تقرير' : 'Generate Report';
  String get downloadReport => isArabic ? 'تحميل التقرير' : 'Download Report';
  String get downloadingReport =>
      isArabic ? 'جاري تحميل التقرير...' : 'Downloading report...';
  String get reportGenerated =>
      isArabic ? 'تم إنشاء التقرير' : 'Report generated';
  String get reportType => isArabic ? 'نوع التقرير' : 'Report Type';
  String get dateRange => isArabic ? 'الفترة الزمنية' : 'Date Range';
  String get timePeriod => isArabic ? 'الفترة الزمنية' : 'Time Period';
  String get selectPeriod => isArabic ? 'اختر الفترة' : 'Select Period';
  String get from => isArabic ? 'من' : 'From';
  String get to => isArabic ? 'إلى' : 'To';

  String get generalReport => isArabic ? 'تقرير عام' : 'General Report';
  String get generalReportDesc =>
      isArabic ? 'ملخص شامل للسنتر' : 'Comprehensive center summary';
  String get studentsReport => isArabic ? 'تقرير الطلاب' : 'Students Report';
  String get studentsReportDesc =>
      isArabic ? 'بيانات وإحصائيات الطلاب' : 'Students data and statistics';
  String get financialReport => isArabic ? 'تقرير المالية' : 'Financial Report';
  String get financialReportDesc =>
      isArabic ? 'الإيرادات والمصروفات' : 'Revenue and expenses';
  String get attendanceReport =>
      isArabic ? 'تقرير الحضور' : 'Attendance Report';
  String get attendanceReportDesc =>
      isArabic ? 'سجل حضور الطلاب' : 'Students attendance record';
  String get teachersReport => isArabic ? 'تقرير المعلمين' : 'Teachers Report';
  String get teachersReportDesc =>
      isArabic ? 'بيانات المعلمين والرواتب' : 'Teachers data and salaries';
  String get subjectsReport => isArabic ? 'تقرير المواد' : 'Subjects Report';
  String get subjectsReportDesc =>
      isArabic ? 'إحصائيات المواد الدراسية' : 'Subjects statistics';

  // ═══════════════════════════════════════════════════════════════════════════
  // Notifications
  // ═══════════════════════════════════════════════════════════════════════════
  String get notificationCenter =>
      isArabic ? 'مركز الإشعارات' : 'Notification Center';
  String get unreadNotifications =>
      isArabic ? 'إشعارات غير مقروءة' : 'unread notifications';
  String get markAsRead => isArabic ? 'تحديد كمقروء' : 'Mark as Read';
  String get markAllAsRead =>
      isArabic ? 'تحديد الكل كمقروء' : 'Mark All as Read';
  String get allNotificationsMarkedRead => isArabic
      ? 'تم تحديد جميع الإشعارات كمقروءة'
      : 'All notifications marked as read';
  String get clearAll => isArabic ? 'حذف الكل' : 'Clear All';
  String get deleteAll => clearAll;
  String get noNotifications =>
      isArabic ? 'لا توجد إشعارات' : 'No notifications';
  String get notificationDeleted =>
      isArabic ? 'تم حذف الإشعار' : 'Notification deleted';
  String get deleteAllNotifications =>
      isArabic ? 'حذف جميع الإشعارات' : 'Delete All Notifications';
  String get confirmDeleteAllNotifications => isArabic
      ? 'هل أنت متأكد من حذف جميع الإشعارات؟'
      : 'Are you sure you want to delete all notifications?';
  String get allNotificationsDeleted =>
      isArabic ? 'تم حذف جميع الإشعارات' : 'All notifications deleted';

  // ═══════════════════════════════════════════════════════════════════════════
  // Settings
  // ═══════════════════════════════════════════════════════════════════════════
  String get settingsTitle => isArabic ? 'الإعدادات' : 'Settings';
  String get centerInfo => isArabic ? 'معلومات السنتر' : 'Center Info';
  String get appearance => isArabic ? 'المظهر' : 'Appearance';
  String get backup => isArabic ? 'النسخ الاحتياطي' : 'Backup';
  String get users => isArabic ? 'المستخدمين' : 'Users';
  String get security => isArabic ? 'الأمان' : 'Security';
  String get centerName => isArabic ? 'اسم السنتر' : 'Center Name';
  String get licenseNumber => isArabic ? 'رقم الترخيص' : 'License Number';
  String get darkMode => isArabic ? 'الوضع الداكن' : 'Dark Mode';
  String get enableDarkMode =>
      isArabic ? 'تفعيل المظهر الداكن للتطبيق' : 'Enable dark mode for the app';
  String get language => isArabic ? 'اللغة' : 'Language';
  String get appLanguage =>
      isArabic ? 'لغة واجهة التطبيق' : 'App interface language';
  String get currency => isArabic ? 'ج.م' : 'EGP';
  String get defaultCurrency =>
      isArabic ? 'العملة الافتراضية' : 'Default currency';
  String get emailNotifications =>
      isArabic ? 'إشعارات البريد' : 'Email Notifications';
  String get smsNotifications => isArabic ? 'إشعارات SMS' : 'SMS Notifications';
  String get autoBackup => isArabic ? 'نسخ احتياطي تلقائي' : 'Auto Backup';
  String get createBackup =>
      isArabic ? 'إنشاء نسخة احتياطية الآن' : 'Create Backup Now';
  String get restoreBackup =>
      isArabic ? 'استعادة نسخة احتياطية' : 'Restore Backup';
  String get userManagement =>
      isArabic ? 'إدارة المستخدمين' : 'User Management';
  String get addUser => isArabic ? 'إضافة مستخدم' : 'Add User';
  String get changePassword =>
      isArabic ? 'تغيير كلمة المرور' : 'Change Password';
  String get twoFactorAuth =>
      isArabic ? 'تفعيل المصادقة الثنائية' : 'Enable Two-Factor Authentication';
  String get saveChanges => isArabic ? 'حفظ التغييرات' : 'Save Changes';
  String get settingsSaved =>
      isArabic ? 'تم حفظ الإعدادات بنجاح' : 'Settings saved successfully';
  String get darkModeEnabled =>
      isArabic ? 'تم تفعيل الوضع الداكن' : 'Dark mode enabled';
  String get lightModeEnabled =>
      isArabic ? 'تم تفعيل الوضع الفاتح' : 'Light mode enabled';
  String get languageChangedToArabic =>
      isArabic ? 'تم تغيير اللغة إلى العربية' : 'Language changed to Arabic';
  String get languageChangedToEnglish => isArabic
      ? 'تم تغيير اللغة إلى الإنجليزية'
      : 'Language changed to English';
  String get currencyChanged =>
      isArabic ? 'تم تغيير العملة' : 'Currency changed';
  String get arabic => isArabic ? 'العربية' : 'Arabic';
  String get english => isArabic ? 'English' : 'English';
  String get egp => isArabic ? 'جنيه مصري (EGP)' : 'Egyptian Pound (EGP)';
  String get sar => isArabic ? 'ريال سعودي (SAR)' : 'Saudi Riyal (SAR)';
  String get usd => isArabic ? 'دولار أمريكي (USD)' : 'US Dollar (USD)';
  String get comingSoon => isArabic
      ? 'سيتم إضافة هذه الميزة قريباً'
      : 'This feature will be added soon';
  String get creatingBackup =>
      isArabic ? 'جاري إنشاء نسخة احتياطية...' : 'Creating backup...';
  String get selectBackupFile => isArabic
      ? 'يرجى اختيار ملف النسخة الاحتياطية'
      : 'Please select backup file';
  String get passwordChangeWindow => isArabic
      ? 'سيتم فتح نافذة تغيير كلمة المرور'
      : 'Password change window will open';
  String get verificationCodeSent =>
      isArabic ? 'تم إرسال رمز التأكيد' : 'Verification code sent';

  // ═══════════════════════════════════════════════════════════════════════════
  // Profile & Messages
  // ═══════════════════════════════════════════════════════════════════════════
  String get profile => isArabic ? 'الملف الشخصي' : 'Profile';
  String get fullName => isArabic ? 'الاسم بالكامل' : 'Full Name';
  String get messages => isArabic ? 'الرسائل' : 'Messages';
  String get noMessages => isArabic ? 'لا توجد رسائل' : 'No messages';
  String get inboxEmpty => isArabic ? 'صندوق الوارد الخاص بك فارغ حالياً' : 'Your inbox is currently empty';

  // ═══════════════════════════════════════════════════════════════════════════
  // Validation Messages
  // ═══════════════════════════════════════════════════════════════════════════
  String get requiredField =>
      isArabic ? 'هذا الحقل مطلوب' : 'This field is required';
  String get invalidEmail =>
      isArabic ? 'بريد إلكتروني غير صالح' : 'Invalid email';
  String get invalidPhone =>
      isArabic ? 'رقم هاتف غير صالح' : 'Invalid phone number';
  String get fillRequiredFields => isArabic
      ? 'يرجى ملء جميع الحقول المطلوبة'
      : 'Please fill all required fields';
}

/// Localization delegate for AppStrings
class AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const AppStringsDelegate();

  @override
  bool isSupported(Locale locale) => ['ar', 'en'].contains(locale.languageCode);

  @override
  Future<AppStrings> load(Locale locale) async => AppStrings(locale);

  @override
  bool shouldReload(AppStringsDelegate old) => false;
}


