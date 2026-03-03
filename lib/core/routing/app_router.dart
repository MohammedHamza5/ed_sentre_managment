import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'route_names.dart';
import '../../shared/widgets/layout/app_shell.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/students/presentation/screens/students_screen.dart';
import '../../features/students/presentation/screens/add_student_screen.dart';
import '../../features/students/presentation/screens/student_details_screen.dart';
import '../../features/teachers/presentation/screens/teachers_screen.dart';
import '../../features/teachers/presentation/screens/add_teacher_screen.dart';
import '../../features/schedule/presentation/screens/schedule_screen.dart';
import '../../features/subjects/presentation/screens/subjects_screen.dart';
import '../../features/rooms/presentation/screens/rooms_screen.dart';
import '../../features/payments/presentation/screens/payments_screen.dart';
import '../../features/reports/presentation/screens/reports_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/users_page.dart';
import '../../features/attendance/presentation/screens/attendance_screen.dart';
import '../../features/attendance/presentation/screens/take_attendance_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../core/supabase/supabase_client.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/messages/presentation/screens/messages_screen.dart';
import '../../features/groups/presentation/groups_management_screen.dart';
import '../../features/payments/presentation/screens/record_payment_screen.dart';
import '../../features/reports/presentation/students_report_screen.dart';
import '../../features/students/presentation/screens/student_account_statement_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/support/presentation/screens/support_tickets_screen.dart';
import '../../features/support/presentation/screens/ticket_chat_screen.dart';
import '../../features/reports/presentation/screens/smart_financial_dashboard_screen.dart';
import '../../features/students/presentation/screens/smart_invoice_screen.dart';
import '../../features/settings/presentation/screens/course_prices_screen.dart';
import '../../features/library/presentation/center_library_screen.dart';

import '../../shared/models/models.dart';

/// EdSentre App Router
/// نظام التوجيه الرئيسي
class AppRouter {
  AppRouter._();

  static final GlobalKey<NavigatorState> _rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');
  static final GlobalKey<NavigatorState> _shellNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'shell');
  static final _authRefreshNotifier = _AuthRefreshNotifier();

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: RouteNames.login,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: _authRefreshNotifier,
    redirect: (context, state) {
      // تطبيع المسارات: قص الشرطة المائلة الأخيرة لأي مسار (عدا "/")
      final path = state.uri.path;
      if (path != '/' && path.endsWith('/')) {
        return path.substring(0, path.length - 1);
      }
      // React to live auth changes rather than a cached flag
      final isAuthenticated = SupabaseClientManager.currentUser != null;
      final isLoginRoute = state.matchedLocation == RouteNames.login;
      final isSignupRoute = state.matchedLocation == '/signup';

      if (!isAuthenticated && !isLoginRoute && !isSignupRoute) {
        return RouteNames.login;
      }

      if (isAuthenticated && isLoginRoute) {
        return RouteNames.dashboard;
      }

      return null;
    },
    routes: [
      // Login Route - صفحة تسجيل الدخول
      GoRoute(
        path: RouteNames.login,
        name: 'login',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: LoginScreen()),
      ),

      // Shell Route - يحتوي على الـ Sidebar
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          // Dashboard - الصفحة الرئيسية
          GoRoute(
            path: RouteNames.dashboard,
            name: 'dashboard',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: DashboardScreen()),
          ),

          // Legacy alias: /dashboard -> "/"
          GoRoute(
            path: '/dashboard',
            redirect: (context, state) => RouteNames.dashboard,
          ),

          // 👇 REMOVE this whole block ─ it causes the assertion
          /*
          GoRoute(
            path: '/dashboard/',
            redirect: (context, state) => RouteNames.dashboard,
          ),
          */

          // Students - الطلاب
          GoRoute(
            path: RouteNames.students,
            name: 'students',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: StudentsScreen()),
          ),

          // Students Sub-routes (Flattened)
          GoRoute(
            path: '${RouteNames.students}/add',
            name: 'addStudent',
            pageBuilder: (context, state) {
              final student = state.extra as Student?;
              return NoTransitionPage(
                child: AddStudentScreen(student: student),
              );
            },
          ),
          GoRoute(
            path: '${RouteNames.students}/account-statement/:id',
            name: 'studentAccountStatement',
            pageBuilder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              final name = extra?['name'] as String? ?? 'الطالب';
              return NoTransitionPage(
                child: StudentAccountStatementScreen(
                  studentId: state.pathParameters['id']!,
                  studentName: name,
                ),
              );
            },
          ),
          GoRoute(
            path: '${RouteNames.students}/smart-invoice/:studentId',
            name: 'smartInvoice',
            pageBuilder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return NoTransitionPage(
                child: SmartInvoiceScreen(
                  studentId: state.pathParameters['studentId']!,
                  studentName: extra?['studentName'] ?? 'الطالب',
                ),
              );
            },
          ),
          GoRoute(
            path: '${RouteNames.students}/:id',
            name: 'studentDetails',
            pageBuilder: (context, state) => NoTransitionPage(
              child: StudentDetailsScreen(
                studentId: state.pathParameters['id']!,
              ),
            ),
          ),

          // Teachers - المعلمين
          GoRoute(
            path: RouteNames.teachers,
            name: 'teachers',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: TeachersScreen()),
            routes: [
              GoRoute(
                path: 'add',
                name: 'addTeacher',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: AddTeacherScreen()),
              ),
            ],
          ),

          // Groups - المجموعات
          GoRoute(
            path: RouteNames.groups,
            name: 'groups',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: GroupsManagementScreen()),
          ),

          // Schedule - الجداول
          GoRoute(
            path: RouteNames.schedule,
            name: 'schedule',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ScheduleScreen()),
          ),

          // Attendance - الحضور
          GoRoute(
            path: RouteNames.attendance,
            name: 'attendance',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: AttendanceScreen()),
            routes: [
              GoRoute(
                path: 'take',
                name: 'takeAttendance',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: TakeAttendanceScreen()),
              ),
            ],
          ),

          // Subjects - المواد
          GoRoute(
            path: RouteNames.subjects,
            name: 'subjects',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SubjectsScreen()),
          ),

          // Rooms - القاعات
          GoRoute(
            path: RouteNames.rooms,
            name: 'rooms',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: RoomsScreen()),
          ),

          // Payments - المدفوعات
          GoRoute(
            path: RouteNames.payments,
            name: 'payments',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: PaymentsScreen()),
            routes: [
              GoRoute(
                path: 'record',
                name: 'recordPayment',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: RecordPaymentScreen()),
              ),
            ],
          ),

          // Reports - التقارير
          GoRoute(
            path: RouteNames.reports,
            name: 'reports',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ReportsScreen()),
            routes: [
              GoRoute(
                path: 'students',
                name: 'studentsReport',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: StudentsReportScreen()),
              ),
              GoRoute(
                path: 'analytics',
                name: 'analytics',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: SmartFinancialDashboardScreen(),
                ),
              ),
            ],
          ),

          // Financial Insights - الذكاء المالي
          GoRoute(
            path: RouteNames.financialInsights,
            name: 'financialInsights',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SmartFinancialDashboardScreen()),
          ),

          // Notifications - الإشعارات
          GoRoute(
            path: RouteNames.notifications,
            name: 'notifications',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: NotificationsScreen()),
          ),

          // Settings - الإعدادات
          // Settings - الإعدادات
          GoRoute(
            path: RouteNames.settings,
            name: 'settings',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SettingsScreen()),
            routes: [
              GoRoute(
                path: 'users',
                name: 'settingsUsers',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: UsersPage()),
              ),
              GoRoute(
                path: 'course-prices',
                name: 'coursePrices',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: CoursePricesScreen()),
              ),
            ],
          ),

          // Profile - الملف الشخصي
          GoRoute(
            path: '/profile',
            name: 'profile',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ProfileScreen()),
          ),

          // Messages - الرسائل
          GoRoute(
            path: '/messages',
            name: 'messages',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: MessagesScreen()),
          ),

          // Support - الدعم الفني
          GoRoute(
            path: RouteNames.support,
            name: 'support',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SupportTicketsScreen()),
            routes: [
              GoRoute(
                path: ':id',
                name: 'supportChat',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: TicketChatScreen(
                    ticketId: state.pathParameters['id']!,
                  ),
                ),
              ),
            ],
          ),

          // Library - المكتبة
          GoRoute(
            path: RouteNames.library,
            name: 'library',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: CenterLibraryScreen()),
          ),

          // Search - البحث
          GoRoute(
            path: RouteNames.search,
            name: 'search',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SearchScreen()),
          ),
        ],
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'الصفحة غير موجودة',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              state.uri.toString(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(RouteNames.dashboard),
              child: const Text('العودة للرئيسية'),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Notifier that refreshes GoRouter when Supabase auth state changes
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier() {
    _subscription = SupabaseClientManager.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
