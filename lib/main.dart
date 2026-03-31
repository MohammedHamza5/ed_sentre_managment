import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/l10n/app_strings.dart';
import 'core/monitoring/system_health_monitor.dart';
import 'core/offline/network_monitor.dart';
import 'core/offline/local_cache_service.dart';
import 'core/providers/center_provider.dart';
import 'core/providers/settings_provider.dart';
import 'core/routing/app_router.dart';
import 'core/supabase/supabase_client.dart';
import 'core/theme/dark_theme.dart';
import 'core/theme/light_theme.dart';
import 'core/services/permission_service.dart';
import 'core/services/notification_service.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/teachers/bloc/teachers_bloc.dart';
import 'features/teachers/data/repositories/teachers_repository.dart';
import 'features/students/data/repositories/students_repository.dart';
import 'features/subjects/data/repositories/subjects_repository.dart';
import 'features/groups/data/repositories/groups_repository.dart';
import 'features/attendance/data/repositories/attendance_repository.dart';
import 'features/schedule/data/repositories/schedule_repository.dart';
import 'features/rooms/data/repositories/rooms_repository.dart';
import 'features/payments/data/repositories/payment_repository.dart';
import 'features/payments/data/repositories/expenses_repository.dart';
import 'features/dashboard/data/repositories/dashboard_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseClientManager.initialize();

  // بدء مراقبة الصحة (كل 5 دقائق)
  SystemHealthMonitor.startMonitoring();
  SystemHealthMonitor.printComprehensiveReport();

  // تهيئة خدمات Offline
  await LocalCacheService().initialize();
  NetworkMonitor().startMonitoring();

  // تهيئة خدمة الإشعارات
  await NotificationService().initialize();

  // Run app
  runApp(const EdSentreApp());
}

/// تطبيق EdSentre لإدارة السنتر التعليمي
/// ✅ يدعم Offline-First مع Cache محلي
class EdSentreApp extends StatelessWidget {
  const EdSentreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Settings Provider
        ChangeNotifierProvider(create: (_) => SettingsProvider()),

        // Center Provider
        ChangeNotifierProvider(create: (_) => CenterProvider()..initialize()),

        // ✅ Permission Service - الصلاحيات
        ChangeNotifierProvider(create: (_) => PermissionService()),

        // ✅ Network Monitor - مراقبة الاتصال بالإنترنت
        ChangeNotifierProvider(create: (_) => NetworkMonitor()),

        // ✅ Feature Repositories
        Provider<StudentsRepository>(create: (_) => StudentsRepository()),
        Provider<TeachersRepository>(create: (_) => TeachersRepository()),
        Provider<SubjectsRepository>(create: (_) => SubjectsRepository()),
        Provider<GroupsRepository>(create: (_) => GroupsRepository()),
        Provider<AttendanceRepository>(create: (_) => AttendanceRepository()),
        Provider<ScheduleRepository>(create: (_) => ScheduleRepository()),
        Provider<RoomsRepository>(create: (_) => RoomsRepository()),
        Provider<PaymentRepository>(create: (_) => PaymentRepository()),
        Provider<ExpensesRepository>(create: (_) => ExpensesRepository()),
        Provider<DashboardRepository>(create: (_) => DashboardRepository()),

        // Auth Bloc
        BlocProvider<AuthBloc>(
          create: (_) => AuthBloc()..add(AuthCheckRequested()),
        ),

        // ✅ Teachers Bloc - Global Scope
        // Now listens to CenterProvider internally
        BlocProvider<TeachersBloc>(
          create: (context) => TeachersBloc(
            teachersRepository: context.read<TeachersRepository>(),
            subjectsRepository: context.read<SubjectsRepository>(),
            centerProvider: context.read<CenterProvider>(),
          ), // No initial event needed if it listens to CenterProvider, but good to have lazy load or init if center is already there
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return ScreenUtilInit(
            designSize: const Size(1440, 900),
            minTextAdapt: true,
            splitScreenMode: true,
            builder: (context, child) {
              return MaterialApp.router(
                title: 'EdSentre - Center Management',
                debugShowCheckedModeBanner: false,

                // Language support
                locale: settings.locale,
                supportedLocales: const [Locale('ar'), Locale('en')],

                // Localization delegates
                localizationsDelegates: const [
                  AppStringsDelegate(),
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],

                // Themes
                theme: LightTheme.theme,
                darkTheme: DarkTheme.theme,
                themeMode: settings.themeMode,

                // Router
                routerConfig: AppRouter.router,
              );
            },
          );
        },
      ),
    );
  }
}


