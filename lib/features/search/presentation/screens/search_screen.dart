import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/providers/center_provider.dart';
import '../../../students/bloc/students_bloc.dart';
import '../../../teachers/bloc/teachers_bloc.dart';
import '../../../groups/bloc/groups_bloc.dart';
import '../../../students/data/repositories/students_repository.dart';
import '../../../teachers/data/repositories/teachers_repository.dart';
import '../../../groups/data/repositories/groups_repository.dart';
import '../../../subjects/data/repositories/subjects_repository.dart';
import '../../../students/presentation/widgets/students_list.dart';
import '../../../teachers/presentation/widgets/teachers_list.dart';
import '../../../groups/presentation/widgets/groups_list.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(BuildContext context, String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (query == _currentQuery) return;

      setState(() {
        _currentQuery = query;
      });

      // Dispatch search events
      context.read<StudentsBloc>().add(SearchStudents(query));
      context.read<TeachersBloc>().add(SearchTeachers(query));
      context.read<GroupsBloc>().add(SearchGroups(query));
    });
  }

  @override
  Widget build(BuildContext context) {
    final centerId = context.read<CenterProvider>().centerId;
    // Fallback if centerId is null (shouldn't happen in auth'd app but safe to check)
    if (centerId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) =>
              StudentsBloc(context.read<StudentsRepository>(), centerId)
                ..add(const LoadStudents()),
        ),
        BlocProvider(
          create: (context) => TeachersBloc(
            teachersRepository: context.read<TeachersRepository>(),
            subjectsRepository: context
                .read<
                  SubjectsRepository
                >(), // Not needed for search list probably, or check bloc
            centerProvider: context.read<CenterProvider>(),
          )..add(LoadTeachers()),
        ),
        BlocProvider(
          create: (context) => GroupsBloc(
            groupsRepository: context.read<GroupsRepository>(),
            centerId: centerId,
          )..add(LoadGroups()),
        ),
      ],
      child: Builder(
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final strings = AppStrings.of(context);

          return Scaffold(
            body: Column(
              children: [
                // Header with Search Bar
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurface
                        : AppColors.lightSurface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        onChanged: (value) => _onSearchChanged(context, value),
                        decoration: InputDecoration(
                          hintText: strings.search, // 'بحث...' or 'Search...'
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: isDark
                              ? AppColors.darkBackground
                              : AppColors.lightBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusLg,
                            ),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged(context, '');
                                  },
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TabBar(
                        controller: _tabController,
                        labelColor: AppColors.primary,
                        unselectedLabelColor: isDark
                            ? Colors.grey
                            : Colors.grey[600],
                        indicatorColor: AppColors.primary,
                        tabs: [
                          Tab(
                            text: strings.students,
                            icon: const Icon(Icons.school_outlined),
                          ),
                          Tab(
                            text: strings.teachers,
                            icon: const Icon(Icons.person_outline),
                          ),
                          Tab(
                            text: strings.groups,
                            icon: const Icon(Icons.groups_outlined),
                          ),
                        ],
                        onTap: (index) {
                          // Hide keyboard when switching tabs
                          FocusScope.of(context).unfocus();
                        },
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      StudentsList(isDark: isDark, strings: strings),
                      TeachersList(isDark: isDark, strings: strings),
                      GroupsList(isDark: isDark, strings: strings),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}


