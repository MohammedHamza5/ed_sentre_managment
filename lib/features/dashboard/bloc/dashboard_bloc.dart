import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../shared/models/models.dart';
import '../data/repositories/dashboard_repository.dart';
import '../../../core/monitoring/app_logger.dart';

// ═══════════════════════════════════════════════════════════════════════════
// EVENTS - أحداث لوحة التحكم
// ═══════════════════════════════════════════════════════════════════════════

abstract class DashboardEvent extends Equatable {
  const DashboardEvent();

  @override
  List<Object?> get props => [];
}

class LoadDashboard extends DashboardEvent {}

class RefreshDashboard extends DashboardEvent {}

// ═══════════════════════════════════════════════════════════════════════════
// STATE - حالة لوحة التحكم
// ═══════════════════════════════════════════════════════════════════════════

enum DashboardStatus { initial, loading, success, failure }

class DashboardState extends Equatable {
  final DashboardStatus status;
  final DashboardStats? stats;
  final List<ScheduleSession> todaySessions;
  final List<AppNotification> recentNotifications;
  final List<Payment> overduePayments;
  final List<Map<String, dynamic>> weeklyAttendance;
  final List<Map<String, dynamic>> monthlyRevenue;
  final List<Map<String, dynamic>> studentDistribution;
  final List<Room> rooms;
  final String? errorMessage;

  final Map<String, dynamic> centerPulse;
  final Map<String, dynamic> financialForecast;

  const DashboardState({
    this.status = DashboardStatus.initial,
    this.stats,
    this.todaySessions = const [],
    this.recentNotifications = const [],
    this.overduePayments = const [],
    this.weeklyAttendance = const [],
    this.monthlyRevenue = const [],
    this.studentDistribution = const [],
    this.rooms = const [],
    this.centerPulse = const {},
    this.financialForecast = const {},
    this.errorMessage,
  });

  DashboardState copyWith({
    DashboardStatus? status,
    DashboardStats? stats,
    List<ScheduleSession>? todaySessions,
    List<AppNotification>? recentNotifications,
    List<Payment>? overduePayments,
    List<Map<String, dynamic>>? weeklyAttendance,
    List<Map<String, dynamic>>? monthlyRevenue,
    List<Map<String, dynamic>>? studentDistribution,
    List<Room>? rooms,
    Map<String, dynamic>? centerPulse,
    Map<String, dynamic>? financialForecast,
    String? errorMessage,
  }) {
    return DashboardState(
      status: status ?? this.status,
      stats: stats ?? this.stats,
      todaySessions: todaySessions ?? this.todaySessions,
      recentNotifications: recentNotifications ?? this.recentNotifications,
      overduePayments: overduePayments ?? this.overduePayments,
      weeklyAttendance: weeklyAttendance ?? this.weeklyAttendance,
      monthlyRevenue: monthlyRevenue ?? this.monthlyRevenue,
      studentDistribution: studentDistribution ?? this.studentDistribution,
      rooms: rooms ?? this.rooms,
      centerPulse: centerPulse ?? this.centerPulse,
      financialForecast: financialForecast ?? this.financialForecast,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    stats,
    todaySessions,
    recentNotifications,
    overduePayments,
    weeklyAttendance,
    monthlyRevenue,
    studentDistribution,
    rooms,
    centerPulse,
    financialForecast,
  ];
}

// ═══════════════════════════════════════════════════════════════════════════
// BLOC - Dashboard Bloc
// ═══════════════════════════════════════════════════════════════════════════

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final DashboardRepository _repo;
  final String centerId;

  DashboardBloc(this._repo, this.centerId) : super(const DashboardState()) {
    on<LoadDashboard>(_onLoadDashboard);
    on<RefreshDashboard>(_onRefreshDashboard);
  }

  Future<void> _onLoadDashboard(
    LoadDashboard event,
    Emitter<DashboardState> emit,
  ) async {
    emit(state.copyWith(status: DashboardStatus.loading));

    try {
      final stopwatch = Stopwatch()..start();
      AppLogger.performance(
        '🚀 [DashboardBloc] Loading Dashboard with Monolithic RPC...',
      );

      // 🚀 EXTREME PERFORMANCE: جلب كل شيء في طلب واحد فقط! - (updated)
      // بدلاً من 20+ طلب متوازي، طلب RPC واحد يرجع كل البيانات جاهزة

      final dashboardData = await _repo.getDashboardSummary(centerId: centerId);

      if (dashboardData.isEmpty) {
        AppLogger.warning(
          '⚠️ [DashboardBloc] Empty response from RPC or not Supabase Repo',
        );
        // Fallback or retry - for now just succeed with empty values to avoid blocking user
      }

      AppLogger.performance(
        '📦 [DashboardBloc] RPC Response received',
        data: {'duration_ms': stopwatch.elapsedMilliseconds},
      );

      // 1. Parsing Stats
      final stats = DashboardStats(
        totalStudents: dashboardData['student_count'] ?? 0,
        activeStudents: dashboardData['active_students'] ?? 0,

        totalTeachers: dashboardData['teacher_count'] ?? 0,
        totalStudentsChange: 0.0,
        totalTeachersChange: 0.0,

        totalSubjects: dashboardData['course_count'] ?? 0,

        todayRevenue:
            (dashboardData['today_revenue'] as num?)?.toDouble() ?? 0.0,
        todayRevenueChange: 0.0,
        monthlyRevenue:
            (dashboardData['monthly_revenue_total'] as num?)?.toDouble() ?? 0.0,

        todaySessions: dashboardData['today_sessions_count'] ?? 0,
        completedSessions: dashboardData['completed_sessions'] ?? 0,

        attendanceRate:
            (dashboardData['attendance_rate'] as num?)?.toDouble() ?? 0.0,
        attendanceRateChange: 0.0,

        totalGroups: dashboardData['group_count'] ?? 0,
        activeGroups: dashboardData['group_count'] ?? 0,
        fullGroups: dashboardData['full_groups'] ?? 0,

        nextSessionTime: dashboardData['next_session_time'] as String?,
        nextSessionName: dashboardData['next_session_name'] as String?,
      );

      // 2. Parsing Lists (Direct Mapping from JSON)

      // Today Sessions
      final todaySessionsList =
          (dashboardData['today_sessions_list'] as List? ?? [])
              .map(
                (json) => ScheduleSession(
                  id: json['id'] ?? '',
                  subjectId: json['subjectId'] ?? '',
                  subjectName: json['subjectName'] ?? '',
                  teacherId: json['teacherId'] ?? '',
                  teacherName: json['teacherName'] ?? '',
                  roomId: json['roomId'] ?? '',
                  roomName: json['roomName'] ?? 'غير محدد',
                  startTime: json['startTime'] ?? '',
                  endTime: json['endTime'] ?? '',
                  groupName: json['groupName'],
                  status: _parseSessionStatus(json['status']),
                  dayOfWeek: DateTime.now().weekday % 7 + 1, // Approximate
                ),
              )
              .toList();

      // Overdue Payments
      final overduePaymentsList =
          (dashboardData['overdue_invoices_list'] as List? ?? []).map((json) {
            return Payment(
              id: json['id'] ?? '',
              studentId: json['studentId'] ?? '',
              studentName: json['studentName'] ?? '',
              amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
              paidAmount: 0,
              status: PaymentStatus.overdue,
              dueDate: DateTime.tryParse(json['dueDate'] ?? ''),
              month: DateTime.now().month.toString(),
              // Default
              method: PaymentMethod.cash,
            );
          }).toList();

      // Charts
      final weeklyAttendance = List<Map<String, dynamic>>.from(
        dashboardData['weekly_attendance_chart'] ?? [],
      );
      final monthlyRevenueData = List<Map<String, dynamic>>.from(
        dashboardData['monthly_revenue_chart'] ?? [],
      );
      // Calculate Percentages for Student Distribution
      var rawDistribution = List<Map<String, dynamic>>.from(
        dashboardData['student_distribution'] ?? [],
      );

      final totalDistributionCount = rawDistribution.fold<int>(
        0,
        (sum, item) => sum + (item['count'] as int? ?? 0),
      );

      final studentDistribution = rawDistribution.map((item) {
        final count = item['count'] as int? ?? 0;
        final percentage = totalDistributionCount == 0
            ? 0.0
            : (count / totalDistributionCount) * 100;
        return {...item, 'percentage': percentage};
      }).toList();

      emit(
        state.copyWith(
          status: DashboardStatus.success,
          stats: stats,
          todaySessions: todaySessionsList,
          recentNotifications: [],
          overduePayments: overduePaymentsList,
          weeklyAttendance: weeklyAttendance,
          monthlyRevenue: monthlyRevenueData,
          studentDistribution: studentDistribution,
          centerPulse: dashboardData['center_pulse'] ?? {'score': 0},
          financialForecast: dashboardData['financial_forecast'] ?? {},
        ),
      );
      stopwatch.stop();
      AppLogger.success(
        '✅ [DashboardBloc] Dashboard Loaded Successfully',
        data: {
          'total_ms': stopwatch.elapsedMilliseconds,
          'sessions_count': todaySessionsList.length,
          'overdue_count': overduePaymentsList.length,
          'pulse_score': dashboardData['center_pulse']?['score'] ?? 0,
        },
      );
    } catch (e, stack) {
      AppLogger.error(
        '❌ [DashboardBloc] Dashboard Load Failed',
        error: e,
        stackTrace: stack,
        source: ErrorSource.backend,
      );
      emit(
        state.copyWith(
          status: DashboardStatus.failure,
          errorMessage: 'خطأ في تحميل البيانات: $e',
        ),
      );
    }
  }

  SessionStatus _parseSessionStatus(String? status) {
    switch (status) {
      case 'scheduled':
        return SessionStatus.scheduled;
      case 'completed':
        return SessionStatus.completed;
      case 'cancelled':
        return SessionStatus.cancelled;
      default:
        return SessionStatus.scheduled;
    }
  }

  Future<void> _onRefreshDashboard(
    RefreshDashboard event,
    Emitter<DashboardState> emit,
  ) async {
    // We want to force refresh the data from the remote source.
    // We should modify _onLoadDashboard to accept a forceRefresh parameter
    // or just pass forceRefresh directly to the repo here.
    emit(state.copyWith(status: DashboardStatus.loading));

    try {
      final stopwatch = Stopwatch()..start();
      AppLogger.performance('🚀 [DashboardBloc] Force Refreshing Dashboard...');

      final dashboardData = await _repo.getDashboardSummary(
        centerId: centerId,
        forceRefresh: true,
      );

      if (dashboardData.isEmpty) {
        AppLogger.warning('⚠️ [DashboardBloc] Empty response on refresh');
      }

      // 1. Parsing Stats
      final stats = DashboardStats(
        totalStudents: dashboardData['student_count'] ?? 0,
        activeStudents: dashboardData['active_students'] ?? 0,
        totalTeachers: dashboardData['teacher_count'] ?? 0,
        totalStudentsChange: 0.0,
        totalTeachersChange: 0.0,
        totalSubjects: dashboardData['course_count'] ?? 0,
        todayRevenue:
            (dashboardData['today_revenue'] as num?)?.toDouble() ?? 0.0,
        todayRevenueChange: 0.0,
        monthlyRevenue:
            (dashboardData['monthly_revenue_total'] as num?)?.toDouble() ?? 0.0,
        todaySessions: dashboardData['today_sessions_count'] ?? 0,
        completedSessions: dashboardData['completed_sessions'] ?? 0,
        attendanceRate:
            (dashboardData['attendance_rate'] as num?)?.toDouble() ?? 0.0,
        attendanceRateChange: 0.0,
        totalGroups: dashboardData['group_count'] ?? 0,
        activeGroups: dashboardData['group_count'] ?? 0,
        fullGroups: dashboardData['full_groups'] ?? 0,
        nextSessionTime: dashboardData['next_session_time'] as String?,
        nextSessionName: dashboardData['next_session_name'] as String?,
      );

      // 2. Parsing Lists (Direct Mapping from JSON)
      final todaySessionsList =
          (dashboardData['today_sessions_list'] as List? ?? [])
              .map(
                (json) => ScheduleSession(
                  id: json['id'] ?? '',
                  subjectId: json['subjectId'] ?? '',
                  subjectName: json['subjectName'] ?? '',
                  teacherId: json['teacherId'] ?? '',
                  teacherName: json['teacherName'] ?? '',
                  roomId: json['roomId'] ?? '',
                  roomName: json['roomName'] ?? 'غير محدد',
                  startTime: json['startTime'] ?? '',
                  endTime: json['endTime'] ?? '',
                  groupName: json['groupName'],
                  status: _parseSessionStatus(json['status']),
                  dayOfWeek: DateTime.now().weekday % 7 + 1,
                ),
              )
              .toList();

      final overduePaymentsList =
          (dashboardData['overdue_invoices_list'] as List? ?? []).map((json) {
            return Payment(
              id: json['id'] ?? '',
              studentId: json['studentId'] ?? '',
              studentName: json['studentName'] ?? '',
              amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
              paidAmount: 0,
              status: PaymentStatus.overdue,
              dueDate: DateTime.tryParse(json['dueDate'] ?? ''),
              month: DateTime.now().month.toString(),
              method: PaymentMethod.cash,
            );
          }).toList();

      final weeklyAttendance = List<Map<String, dynamic>>.from(
        dashboardData['weekly_attendance_chart'] ?? [],
      );
      final monthlyRevenueData = List<Map<String, dynamic>>.from(
        dashboardData['monthly_revenue_chart'] ?? [],
      );

      var rawDistribution = List<Map<String, dynamic>>.from(
        dashboardData['student_distribution'] ?? [],
      );

      final totalDistributionCount = rawDistribution.fold<int>(
        0,
        (sum, item) => sum + (item['count'] as int? ?? 0),
      );

      final studentDistribution = rawDistribution.map((item) {
        final count = item['count'] as int? ?? 0;
        final percentage = totalDistributionCount == 0
            ? 0.0
            : (count / totalDistributionCount) * 100;
        return {...item, 'percentage': percentage};
      }).toList();

      emit(
        state.copyWith(
          status: DashboardStatus.success,
          stats: stats,
          todaySessions: todaySessionsList,
          recentNotifications: [],
          overduePayments: overduePaymentsList,
          weeklyAttendance: weeklyAttendance,
          monthlyRevenue: monthlyRevenueData,
          studentDistribution: studentDistribution,
          centerPulse: dashboardData['center_pulse'] ?? {'score': 0},
          financialForecast: dashboardData['financial_forecast'] ?? {},
        ),
      );
      stopwatch.stop();
      AppLogger.success(
        '✅ [DashboardBloc] Refresh Loaded Successfully',
        data: {
          'total_ms': stopwatch.elapsedMilliseconds,
          'sessions_count': todaySessionsList.length,
          'overdue_count': overduePaymentsList.length,
        },
      );
    } catch (e, stack) {
      AppLogger.error(
        '❌ [DashboardBloc] Refresh Failed',
        error: e,
        stackTrace: stack,
        source: ErrorSource.backend,
      );
      emit(
        state.copyWith(
          status: DashboardStatus.failure,
          errorMessage: 'خطأ في تحديث البيانات: $e',
        ),
      );
    }
  }
}
