import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../shared/models/models.dart';
import '../../attendance/data/repositories/attendance_repository.dart';
import '../../groups/data/repositories/groups_repository.dart';
import '../../payments/data/repositories/payment_repository.dart';
import '../../rooms/data/repositories/rooms_repository.dart';
import '../../students/data/repositories/students_repository.dart';
import '../../subjects/data/repositories/subjects_repository.dart';
import '../../teachers/data/repositories/teachers_repository.dart';

// ═══════════════════════════════════════════════════════════════════════════
// EVENTS - أحداث التقارير
// ═══════════════════════════════════════════════════════════════════════════

abstract class ReportsEvent extends Equatable {
  const ReportsEvent();

  @override
  List<Object?> get props => [];
}

class LoadReportData extends ReportsEvent {}

class GenerateReport extends ReportsEvent {
  final String reportType;
  final DateTime startDate;
  final DateTime endDate;

  const GenerateReport({
    required this.reportType,
    required this.startDate,
    required this.endDate,
  });

  @override
  List<Object?> get props => [reportType, startDate, endDate];
}

// ═══════════════════════════════════════════════════════════════════════════
// STATE - حالة التقارير
// ═══════════════════════════════════════════════════════════════════════════

enum ReportsStatus { initial, loading, generating, success, failure }

class ReportData extends Equatable {
  final String type;
  final String title;
  final DateTime generatedAt;
  final Map<String, dynamic> data;

  const ReportData({
    required this.type,
    required this.title,
    required this.generatedAt,
    required this.data,
  });

  @override
  List<Object?> get props => [type, title, generatedAt, data];
}

class ReportsState extends Equatable {
  final ReportsStatus status;
  final ReportData? currentReport;
  final int totalStudents;
  final int totalTeachers;
  final int totalSubjects;
  final double totalRevenue;
  final double attendanceRate;
  final String? errorMessage;

  // Weekly attendance data (day -> present count)
  final List<Map<String, dynamic>> weeklyAttendance;
  // Groups performance data
  final List<Map<String, dynamic>> groupsPerformance;

  // ═══════════════════════════════════════════════════════════════════════════
  // NEW: Smart Financial Dashboard Fields
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// الإيراد المتوقع (الطلاب × أسعار المواد)
  final double expectedRevenue;
  
  /// الإيراد الفعلي المحصل هذا الشهر
  final double actualRevenue;
  
  /// نسبة التحصيل (الفعلي / المتوقع × 100)
  final double collectionRate;
  
  /// المبلغ المتأخر (الفرق بين المتوقع والمحصل)
  final double overdueAmount;
  
  /// أفضل المعلمين تحصيلاً [{id, name, revenue, studentsCount}]
  final List<Map<String, dynamic>> topTeachersByRevenue;
  
  /// أفضل المواد ربحية [{id, name, revenue, studentsCount}]
  final List<Map<String, dynamic>> topCoursesByRevenue;
  
  /// بيانات الإيرادات الشهرية للـ 6 أشهر الأخيرة
  final List<Map<String, dynamic>> monthlyRevenueTrend;

  const ReportsState({
    this.status = ReportsStatus.initial,
    this.currentReport,
    this.totalStudents = 0,
    this.totalTeachers = 0,
    this.totalSubjects = 0,
    this.totalRevenue = 0,
    this.attendanceRate = 0,
    this.errorMessage,
    this.weeklyAttendance = const [],
    this.groupsPerformance = const [],
    // New Financial Fields
    this.expectedRevenue = 0,
    this.actualRevenue = 0,
    this.collectionRate = 0,
    this.overdueAmount = 0,
    this.topTeachersByRevenue = const [],
    this.topCoursesByRevenue = const [],
    this.monthlyRevenueTrend = const [],
  });

  ReportsState copyWith({
    ReportsStatus? status,
    ReportData? currentReport,
    int? totalStudents,
    int? totalTeachers,
    int? totalSubjects,
    double? totalRevenue,
    double? attendanceRate,
    String? errorMessage,
    List<Map<String, dynamic>>? weeklyAttendance,
    List<Map<String, dynamic>>? groupsPerformance,
    // New Financial Fields
    double? expectedRevenue,
    double? actualRevenue,
    double? collectionRate,
    double? overdueAmount,
    List<Map<String, dynamic>>? topTeachersByRevenue,
    List<Map<String, dynamic>>? topCoursesByRevenue,
    List<Map<String, dynamic>>? monthlyRevenueTrend,
  }) {
    return ReportsState(
      status: status ?? this.status,
      currentReport: currentReport ?? this.currentReport,
      totalStudents: totalStudents ?? this.totalStudents,
      totalTeachers: totalTeachers ?? this.totalTeachers,
      totalSubjects: totalSubjects ?? this.totalSubjects,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      attendanceRate: attendanceRate ?? this.attendanceRate,
      errorMessage: errorMessage ?? this.errorMessage,
      weeklyAttendance: weeklyAttendance ?? this.weeklyAttendance,
      groupsPerformance: groupsPerformance ?? this.groupsPerformance,
      // New Financial Fields
      expectedRevenue: expectedRevenue ?? this.expectedRevenue,
      actualRevenue: actualRevenue ?? this.actualRevenue,
      collectionRate: collectionRate ?? this.collectionRate,
      overdueAmount: overdueAmount ?? this.overdueAmount,
      topTeachersByRevenue: topTeachersByRevenue ?? this.topTeachersByRevenue,
      topCoursesByRevenue: topCoursesByRevenue ?? this.topCoursesByRevenue,
      monthlyRevenueTrend: monthlyRevenueTrend ?? this.monthlyRevenueTrend,
    );
  }

  @override
  List<Object?> get props => [
    status,
    currentReport,
    totalStudents,
    totalTeachers,
    totalSubjects,
    totalRevenue,
    attendanceRate,
    weeklyAttendance,
    groupsPerformance,
    expectedRevenue,
    actualRevenue,
    collectionRate,
    overdueAmount,
    topTeachersByRevenue,
    topCoursesByRevenue,
    monthlyRevenueTrend,
  ];
}

// ═══════════════════════════════════════════════════════════════════════════
// BLOC - Reports Bloc
// ═══════════════════════════════════════════════════════════════════════════

class ReportsBloc extends Bloc<ReportsEvent, ReportsState> {
  final StudentsRepository _studentsRepo;
  final TeachersRepository _teachersRepo;
  final SubjectsRepository _subjectsRepo;
  final PaymentRepository _paymentsRepo;
  final AttendanceRepository _attendanceRepo;
  final GroupsRepository _groupsRepo;
  final RoomsRepository _roomsRepo;
  final String centerId;

  ReportsBloc({
    required StudentsRepository studentsRepo,
    required TeachersRepository teachersRepo,
    required SubjectsRepository subjectsRepo,
    required PaymentRepository paymentsRepo,
    required AttendanceRepository attendanceRepo,
    required GroupsRepository groupsRepo,
    required RoomsRepository roomsRepo,
    required this.centerId,
  }) : _studentsRepo = studentsRepo,
       _teachersRepo = teachersRepo,
       _subjectsRepo = subjectsRepo,
       _paymentsRepo = paymentsRepo,
       _attendanceRepo = attendanceRepo,
       _groupsRepo = groupsRepo,
       _roomsRepo = roomsRepo,
       super(const ReportsState()) {
    on<LoadReportData>(_onLoadReportData);
    on<GenerateReport>(_onGenerateReport);
  }

  Future<void> _onLoadReportData(
    LoadReportData event,
    Emitter<ReportsState> emit,
  ) async {
    emit(state.copyWith(status: ReportsStatus.loading));

    try {
      // ═══════════════════════════════════════════════════════════════════════
      // 1. BASIC DATA FETCH
      // ═══════════════════════════════════════════════════════════════════════
      debugPrint('═══════════════════════════════════════════════════════════════');
      debugPrint('💰 [ReportsBloc] بدء تحميل البيانات المالية...');
      debugPrint('═══════════════════════════════════════════════════════════════');
      
      final students = await _studentsRepo.getStudents();
      debugPrint('👨‍🎓 [ReportsBloc] الطلاب: ${students.length}');
      
      final teachers = await _teachersRepo.getTeachers();
      debugPrint('👨‍🏫 [ReportsBloc] المعلمون: ${teachers.length}');
      
      final subjects = await _subjectsRepo.getSubjects();
      debugPrint('📚 [ReportsBloc] المواد: ${subjects.length}');
      for (final s in subjects) {
        debugPrint('   📖 ${s.name}: الرسوم=${s.monthlyFee}, الطلاب=${s.studentCount}');
      }
      
      final payments = await _paymentsRepo.getPayments();
      debugPrint('💳 [ReportsBloc] المدفوعات: ${payments.length}');
      
      final groups = await _groupsRepo.getGroups();
      debugPrint('👥 [ReportsBloc] المجموعات: ${groups.length}');
      for (final g in groups) {
        debugPrint('   📦 ${g.groupName}: الرسوم=${g.monthlyFee ?? 0}, الطلاب=${g.currentStudents}, المعلم=${g.teacherId ?? "لا يوجد"}');
      }
      
      final attendanceStats = await _attendanceRepo.getAttendanceStats();
      debugPrint('📊 [ReportsBloc] إحصائيات الحضور: $attendanceStats');

      final attendanceRate =
          (attendanceStats['rate'] as num?)?.toDouble() ?? 0.0;

      // Get additional analytics data
      final weeklyData = await _getWeeklyAttendance();
      final groupsData = await _getGroupsPerformance();

      // ═══════════════════════════════════════════════════════════════════════
      // 2. SMART FINANCIAL CALCULATIONS (Using course_prices via RPC)
      // ═══════════════════════════════════════════════════════════════════════
      debugPrint('');
      debugPrint('═══════════════════════════════════════════════════════════════');
      debugPrint('💹 [ReportsBloc] جلب تقرير الإيرادات الذكي من RPC...');
      debugPrint('═══════════════════════════════════════════════════════════════');
      
      // استخدام RPC الذكي الذي يحسب من course_prices
      final now = DateTime.now();
      final revenueReport = await _paymentsRepo.getCenterRevenueReport(
        month: now.month,
        year: now.year,
      );
      
      // استخراج البيانات من RPC
      double expectedRevenue = (revenueReport['expected_revenue'] as num?)?.toDouble() ?? 0;
      double actualRevenue = (revenueReport['actual_revenue'] as num?)?.toDouble() ?? 0;
      double collectionRate = (revenueReport['collection_rate'] as num?)?.toDouble() ?? 0;
      double overdueAmount = (revenueReport['overdue_amount'] as num?)?.toDouble() ?? 0;
      
      // بناء maps للمواد من بيانات RPC
      final subjectsMap = <String, Subject>{};
      for (final s in subjects) {
        subjectsMap[s.id] = s;
      }
      
      final courseRevenueMap = <String, double>{};
      final courseStudentsMap = <String, int>{};
      
      // استخراج بيانات المجموعات من RPC
      final rpcGroupsData = revenueReport['groups'] as List<dynamic>? ?? [];
      for (final g in rpcGroupsData) {
        final groupMap = g as Map<String, dynamic>;
        final courseName = groupMap['course_name'] as String?;
        final revenue = (groupMap['expected_revenue'] as num?)?.toDouble() ?? 0;
        final studentCount = (groupMap['student_count'] as int?) ?? 0;
        
        // ربط بالمادة عن طريق الاسم
        final courseEntry = subjects.where((s) => s.name == courseName).firstOrNull;
        if (courseEntry != null) {
          courseRevenueMap[courseEntry.id] = (courseRevenueMap[courseEntry.id] ?? 0) + revenue;
          courseStudentsMap[courseEntry.id] = (courseStudentsMap[courseEntry.id] ?? 0) + studentCount;
        }
      }
      
      debugPrint('');
      debugPrint('═══════════════════════════════════════════════════════════════');
      debugPrint('📈 [ReportsBloc] === ملخص الأداء المالي (من RPC الذكي) ===');
      debugPrint('   📊 الإيراد المتوقع: $expectedRevenue جنيه');
      debugPrint('   💵 الإيراد الفعلي: $actualRevenue جنيه');
      debugPrint('   📉 نسبة التحصيل: ${collectionRate.toStringAsFixed(1)}%');
      debugPrint('   ⚠️ المبلغ المتأخر: $overdueAmount جنيه');
      debugPrint('═══════════════════════════════════════════════════════════════');
      debugPrint('');
      
      final topCourses = courseRevenueMap.entries.map((e) {
        final course = subjectsMap[e.key];
        return {
          'id': e.key,
          'name': course?.name ?? 'غير معروف',
          'revenue': e.value,
          'studentsCount': courseStudentsMap[e.key] ?? 0,
          'color': '#667EEA', // Default color since Subject has no color field
        };
      }).toList();
      topCourses.sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));
      
      // --- 2.5: Top Teachers by Revenue ---
      // حساب إيرادات المعلمين من المجموعات (الرسوم الشهرية × عدد الطلاب)
      final teacherRevenueMap = <String, double>{};
      final teacherStudentsMap = <String, int>{};
      
      for (final group in groups) {
        final teacherId = group.teacherId;
        if (teacherId != null && teacherId.isNotEmpty) {
          final groupRevenue = (group.monthlyFee ?? 0.0) * group.currentStudents;
          teacherRevenueMap[teacherId] = (teacherRevenueMap[teacherId] ?? 0) + groupRevenue;
          teacherStudentsMap[teacherId] = (teacherStudentsMap[teacherId] ?? 0) + group.currentStudents;
        }
      }
      final topTeachers = teacherRevenueMap.entries.map((e) {
        final teacher = teachers.firstWhere(
          (t) => t.id == e.key, 
          orElse: () => Teacher(
            id: e.key, 
            name: 'غير معروف', 
            phone: '', 
            subjectIds: const [], 
            salaryType: SalaryType.fixed, 
            salaryAmount: 0,
            isActive: true,
            createdAt: DateTime.now(),
          ),
        );
        return {
          'id': e.key,
          'name': teacher.name,
          'revenue': e.value,
          'studentsCount': teacherStudentsMap[e.key] ?? 0,
        };
      }).toList();
      topTeachers.sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));
      
      // --- 2.6: Monthly Revenue Trend (Last 6 Months) ---
      final monthlyTrend = <Map<String, dynamic>>[];
      for (int i = 5; i >= 0; i--) {
        final month = DateTime(now.year, now.month - i, 1);
        final monthEnd = DateTime(month.year, month.month + 1, 0);
        final monthPayments = payments.where((p) {
          final paidDate = p.paidDate;
          return paidDate != null && 
                 paidDate.isAfter(month.subtract(const Duration(days: 1))) &&
                 paidDate.isBefore(monthEnd.add(const Duration(days: 1)));
        }).toList();
        
        final monthRevenue = monthPayments.fold<double>(0, (sum, p) => sum + p.paidAmount);
        monthlyTrend.add({
          'month': '${month.month}/${month.year}',
          'monthName': _getMonthName(month.month),
          'revenue': monthRevenue,
        });
      }

      // ═══════════════════════════════════════════════════════════════════════
      // 3. EMIT FINAL STATE
      // ═══════════════════════════════════════════════════════════════════════
      emit(
        state.copyWith(
          status: ReportsStatus.success,
          totalStudents: students.length,
          totalTeachers: teachers.length,
          totalSubjects: subjects.length,
          totalRevenue: actualRevenue,
          attendanceRate: attendanceRate,
          weeklyAttendance: weeklyData,
          groupsPerformance: groupsData,
          // New Financial Fields
          expectedRevenue: expectedRevenue,
          actualRevenue: actualRevenue,
          collectionRate: collectionRate,
          overdueAmount: overdueAmount,
          topTeachersByRevenue: topTeachers.take(5).toList(),
          topCoursesByRevenue: topCourses.take(5).toList(),
          monthlyRevenueTrend: monthlyTrend,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: ReportsStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }
  
  String _getMonthName(int month) {
    const months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 
                    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    return months[month - 1];
  }

  /// Get weekly attendance from the last 7 days
  Future<List<Map<String, dynamic>>> _getWeeklyAttendance() async {
    try {
      final now = DateTime.now();
      final weekDays = [
        'السبت',
        'الأحد',
        'الإثنين',
        'الثلاثاء',
        'الأربعاء',
        'الخميس',
        'الجمعة',
      ];
      final result = <Map<String, dynamic>>[];

      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final dayName = weekDays[date.weekday % 7];

        // Use date parameter (the only one available)
        final stats = await _attendanceRepo.getAttendanceStats(date: date);

        final total = (stats['total'] as num?)?.toInt() ?? 0;
        final present = (stats['present'] as num?)?.toInt() ?? 0;
        final rate = total > 0 ? (present / total * 100) : 0.0;

        result.add({
          'day': dayName,
          'date': date.toIso8601String().split('T')[0],
          'rate': rate,
          'present': present,
          'total': total,
        });
      }

      return result;
    } catch (e) {
      return [];
    }
  }

  /// Get groups performance (enrollment rate)
  Future<List<Map<String, dynamic>>> _getGroupsPerformance() async {
    try {
      final groups = await _groupsRepo.getGroups();
      final result = <Map<String, dynamic>>[];

      for (final group in groups.take(5)) {
        // Use correct field names from Group model
        final enrolled = group.currentStudents;
        final capacity = group.maxStudents;
        final rate = capacity > 0 ? (enrolled / capacity * 100) : 0.0;

        result.add({
          'name': group.groupName,
          'enrolled': enrolled,
          'capacity': capacity,
          'rate': rate,
        });
      }

      // Sort by rate descending
      result.sort(
        (a, b) => (b['rate'] as double).compareTo(a['rate'] as double),
      );

      return result;
    } catch (e) {
      return [];
    }
  }

  Future<void> _onGenerateReport(
    GenerateReport event,
    Emitter<ReportsState> emit,
  ) async {
    emit(state.copyWith(status: ReportsStatus.generating));

    try {
      final Map<String, dynamic> reportData = {};

      switch (event.reportType) {
        case 'general':
          reportData.addAll(
            await _generateGeneralReport(event.startDate, event.endDate),
          );
          break;
        case 'students':
          reportData.addAll(
            await _generateStudentsReport(event.startDate, event.endDate),
          );
          break;
        case 'payments':
          reportData.addAll(
            await _generatePaymentsReport(event.startDate, event.endDate),
          );
          break;
        case 'attendance':
          reportData.addAll(
            await _generateAttendanceReport(event.startDate, event.endDate),
          );
          break;
        case 'teachers':
          reportData.addAll(
            await _generateTeachersReport(event.startDate, event.endDate),
          );
          break;
        case 'subjects':
          reportData.addAll(
            await _generateSubjectsReport(event.startDate, event.endDate),
          );
          break;
      }

      final report = ReportData(
        type: event.reportType,
        title: _getReportTitle(event.reportType),
        generatedAt: DateTime.now(),
        data: reportData,
      );

      emit(
        state.copyWith(status: ReportsStatus.success, currentReport: report),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: ReportsStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  String _getReportTitle(String type) => switch (type) {
    'general' => 'تقرير عام',
    'students' => 'تقرير الطلاب',
    'payments' => 'تقرير المالية',
    'attendance' => 'تقرير الحضور',
    'teachers' => 'تقرير المعلمين',
    'subjects' => 'تقرير المواد',
    _ => 'تقرير',
  };

  Future<Map<String, dynamic>> _generateGeneralReport(
    DateTime start,
    DateTime end,
  ) async {
    final students = await _studentsRepo.getStudents();
    final teachers = await _teachersRepo.getTeachers();
    final subjects = await _subjectsRepo.getSubjects();
    final rooms = await _roomsRepo.getRooms();
    final payments = await _paymentsRepo.getPayments();
    final attendanceStats = await _attendanceRepo.getAttendanceStats();

    final activeStudents = students
        .where((s) => s.status == StudentStatus.active)
        .length;
    final totalRevenue = payments.fold<double>(
      0,
      (sum, p) => sum + p.paidAmount,
    );

    return {
      'summary': {
        'totalStudents': students.length,
        'activeStudents': activeStudents,
        'totalTeachers': teachers.length,
        'totalSubjects': subjects.length,
        'totalRooms': rooms.length,
        'totalRevenue': totalRevenue,
        'attendanceRate': attendanceStats['rate'] ?? 0,
      },
      'period': {
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
      },
    };
  }

  Future<Map<String, dynamic>> _generateStudentsReport(
    DateTime start,
    DateTime end,
  ) async {
    final students = await _studentsRepo.getStudents();

    final byStatus = <String, int>{};
    final byStage = <String, int>{};

    for (final s in students) {
      byStatus[s.status.name] = (byStatus[s.status.name] ?? 0) + 1;
      byStage[s.stage] = (byStage[s.stage] ?? 0) + 1;
    }

    return {
      'total': students.length,
      'byStatus': byStatus,
      'byStage': byStage,
      'students': students
          .map(
            (s) => {
              'id': s.id,
              'name': s.name,
              'phone': s.phone,
              'stage': s.stage,
              'status': s.status.name,
            },
          )
          .toList(),
    };
  }

  Future<Map<String, dynamic>> _generatePaymentsReport(
    DateTime start,
    DateTime end,
  ) async {
    final payments = await _paymentsRepo.getPayments();

    final filteredPayments = payments.where((p) {
      final date = p.paidDate ?? p.dueDate;
      if (date == null) return false;
      return date.isAfter(start) &&
          date.isBefore(end.add(const Duration(days: 1)));
    }).toList();

    final totalAmount = filteredPayments.fold<double>(
      0,
      (sum, p) => sum + p.paidAmount,
    );
    final byMethod = <String, double>{};
    final byType = <String, double>{}; // NEW: Breakdown by items revenue

    // Fetch full payment details to get items
    // Since we only have access to Payment objects here,
    // we would ideally need to fetch items.
    // For now, we will assume simple payments or rely on future improvements.
    // However, we can track counts if we had item types directly on payment.
    // But Payments table doesn't have item_type, only payment_items.

    // Simplification: Aggregation by Method
    for (final p in filteredPayments) {
      byMethod[p.method.name] = (byMethod[p.method.name] ?? 0) + p.paidAmount;
    }

    return {
      'totalPayments': filteredPayments.length,
      'totalAmount': totalAmount,
      'byMethod': byMethod,
      'byType':
          byType, // Placeholder for now until repository supports getItems
      'payments': filteredPayments
          .map(
            (p) => {
              'id': p.id,
              'studentName': p.studentName,
              'amount': p.paidAmount,
              'method': p.method.name,
              'date': p.paidDate?.toIso8601String(),
            },
          )
          .toList(),
    };
  }

  Future<Map<String, dynamic>> _generateAttendanceReport(
    DateTime start,
    DateTime end,
  ) async {
    final attendance = await _attendanceRepo.getAttendanceRange(start, end);

    final filteredAttendance = attendance.where((a) {
      return a.date.isAfter(start) &&
          a.date.isBefore(end.add(const Duration(days: 1)));
    }).toList();

    final present = filteredAttendance
        .where((a) => a.status == AttendanceStatus.present)
        .length;
    final absent = filteredAttendance
        .where((a) => a.status == AttendanceStatus.absent)
        .length;
    final late = filteredAttendance
        .where((a) => a.status == AttendanceStatus.late)
        .length;
    final excused = filteredAttendance
        .where((a) => a.status == AttendanceStatus.excused)
        .length;
    final total = filteredAttendance.length;

    return {
      'total': total,
      'present': present,
      'absent': absent,
      'late': late,
      'excused': excused,
      'rate': total > 0 ? (present + late) / total * 100 : 0,
      'records': filteredAttendance
          .map(
            (a) => {
              'studentName': a.studentName,
              'date': a.date.toIso8601String(),
              'status': a.status.name,
              'checkIn': a.checkInTime?.toIso8601String(),
            },
          )
          .toList(),
    };
  }

  Future<Map<String, dynamic>> _generateTeachersReport(
    DateTime start,
    DateTime end,
  ) async {
    final teachers = await _teachersRepo.getTeachers();

    final bySalaryType = <String, int>{};
    double totalSalaries = 0;

    for (final t in teachers) {
      bySalaryType[t.salaryType.name] =
          (bySalaryType[t.salaryType.name] ?? 0) + 1;
      totalSalaries += t.salaryAmount;
    }

    return {
      'total': teachers.length,
      'totalSalaries': totalSalaries,
      'bySalaryType': bySalaryType,
      'teachers': teachers
          .map(
            (t) => {
              'id': t.id,
              'name': t.name,
              'phone': t.phone,
              'salaryAmount': t.salaryAmount,
              'salaryType': t.salaryType.name,
            },
          )
          .toList(),
    };
  }

  Future<Map<String, dynamic>> _generateSubjectsReport(
    DateTime start,
    DateTime end,
  ) async {
    final subjects = await _subjectsRepo.getSubjects();

    double totalMonthlyFees = 0;
    for (final s in subjects) {
      totalMonthlyFees += s.monthlyFee;
    }

    return {
      'total': subjects.length,
      'totalMonthlyFees': totalMonthlyFees,
      'subjects': subjects
          .map(
            (s) => {
              'id': s.id,
              'name': s.name,
              'description': s.description,
              'monthlyFee': s.monthlyFee,
              'teachersCount': s.teacherIds.length,
            },
          )
          .toList(),
    };
  }
}


