/// Group Details Screen - EdSentre
/// شاشة تفاصيل المجموعة مع الطلاب
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/models/models.dart';
// import '../../../shared/data/supabase_repository.dart'; // Removed
import '../../attendance/presentation/screens/qr_attendance_screen.dart';
import '../../attendance/presentation/screens/take_attendance_screen.dart';
import '../data/repositories/groups_repository.dart';
import '../../rooms/data/repositories/rooms_repository.dart'; // Added
import 'widgets/smart_enrollment_dialog.dart';
import '../../attendance/presentation/screens/smart_attendance_screen.dart';
import '../../attendance/data/repositories/attendance_repository.dart';

class GroupDetailsScreen extends StatefulWidget {
  final Group group;

  const GroupDetailsScreen({super.key, required this.group});

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Group _group; // Group state
  List<StudentGroupEnrollment> _enrollments = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _group = widget.group; // Init with widget group
    _tabController = TabController(length: 3, vsync: this);
    _loadGroupData();
  }

  Future<void> _loadGroupData() async {
    setState(() => _isLoading = true);

    try {
      final groupsRepository = context.read<GroupsRepository>();

      // 1. Fetch fresh Group data (including sessions)
      final freshGroup = await groupsRepository.getGroup(widget.group.id);

      // 2. Fetch Enrollments
      final enrollments = await groupsRepository.getGroupEnrollments(
        widget.group.id,
      );

      // 3. Update State
      if (mounted) {
        setState(() {
          _group =
              freshGroup; // Update the main group object with fresh sessions
          _enrollments = enrollments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // If fetch fails, we still rely on widget.group as fallback,
        // but show error for awareness.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تحديث بيانات المجموعة: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [_buildAppBar()],
        body: Column(
          children: [
            // Tabs
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  bottom: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                labelStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: 'الطلاب', icon: Icon(Icons.people_rounded)),
                  Tab(text: 'الجدول', icon: Icon(Icons.schedule_rounded)),
                  Tab(text: 'الإحصائيات', icon: Icon(Icons.analytics_rounded)),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildStudentsTab(),
                  _buildScheduleTab(),
                  _buildStatisticsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showEnrollStudentDialog,
        icon: const Icon(Icons.person_add_rounded),
        label: Text(
          'تسجيل طالب',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar.large(
      pinned: true,
      expandedHeight: 200.h,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          widget.group.groupName,
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.purple.shade400, Colors.purple.shade700],
                ),
              ),
            ),

            // Overlay Info
            Positioned(
              bottom: 60.h,
              left: 20.w,
              right: 20.w,
              child: Row(
                children: [
                  _buildHeaderChip(
                    Icons.people_rounded,
                    '${widget.group.currentStudents}/${widget.group.maxStudents}',
                  ),
                  SizedBox(width: 8.w),
                  if (widget.group.teacherName != null)
                    _buildHeaderChip(
                      Icons.person_rounded,
                      widget.group.teacherName!,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_rounded),
          onPressed: _editGroup,
          tooltip: 'تعديل',
        ),
        IconButton(
          icon: const Icon(Icons.more_vert_rounded),
          onPressed: _showOptions,
        ),
      ],
    );
  }

  Widget _buildHeaderChip(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16.sp, color: Colors.white),
          SizedBox(width: 6.w),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_enrollments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80.sp,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 16.h),
            Text(
              'لا يوجد طلاب في هذه المجموعة',
              style: GoogleFonts.cairo(
                fontSize: 18.sp,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 24.h),
            FilledButton.icon(
              onPressed: _showEnrollStudentDialog,
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('إضافة طالب'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: _enrollments.length,
      itemBuilder: (context, index) {
        final enrollment = _enrollments[index];
        return _buildStudentCard(enrollment);
      },
    );
  }

  Widget _buildStudentCard(StudentGroupEnrollment enrollment) {
    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(16.w),
        leading: CircleAvatar(
          radius: 24.r,
          backgroundColor: Colors.purple.shade100,
          child: Text(
            enrollment.studentName?.substring(0, 1) ?? 'ط',
            style: TextStyle(
              color: Colors.purple.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          enrollment.studentName ?? 'طالب',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'تاريخ التسجيل: ${enrollment.enrollmentDate}',
          style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'transfer',
              child: Row(
                children: [
                  Icon(Icons.swap_horiz_rounded, size: 20.sp),
                  SizedBox(width: 12.w),
                  Text('نقل لمجموعة أخرى'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'withdraw',
              child: Row(
                children: [
                  Icon(
                    Icons.exit_to_app_rounded,
                    size: 20.sp,
                    color: Colors.orange,
                  ),
                  SizedBox(width: 12.w),
                  Text(
                    'سحب من المجموعة',
                    style: TextStyle(color: Colors.orange),
                  ),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'transfer') _transferStudent(enrollment);
            if (value == 'withdraw') _withdrawStudent(enrollment);
          },
        ),
      ),
    );
  }

  Widget _buildScheduleTab() {
    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        // Session Management
        Card(
          elevation: 2,
          color: Colors.purple.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
            side: BorderSide(color: Colors.purple.shade100),
          ),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.timer_outlined, color: Colors.purple.shade700),
                    SizedBox(width: 8.w),
                    Text(
                      'إدارة الحصة',
                      style: GoogleFonts.cairo(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade900,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _startSmartAttendance(),
                        icon: const Icon(Icons.qr_code_2),
                        label: const Text('بدء الحضور الذكي'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // Navigate to TakeAttendanceScreen
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TakeAttendanceScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.list_alt),
                        label: const Text('تحضير يدوي'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.purple,
                          side: const BorderSide(color: Colors.purple),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 16.h),

        // Primary Schedule
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.event_rounded,
                          color: Colors.purple.shade400,
                        ),
                        SizedBox(width: 12.w),
                        Text(
                          'مواعيد المجموعة',
                          style: GoogleFonts.cairo(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: _showAddSessionDialog,
                      icon: const Icon(Icons.add_circle, color: Colors.purple),
                      tooltip: 'إضافة ميعاد',
                    ),
                  ],
                ),
                SizedBox(height: 20.h),

                if (_group.sessions.isNotEmpty)
                  ..._group.sessions.map((s) => _buildSessionItem(s))
                else if (_group.dayOfWeek != null) ...[
                  _buildScheduleRow(
                    'اليوم',
                    _group.dayName,
                    Icons.calendar_today_rounded,
                  ),
                  if (_group.startTime != null && _group.endTime != null)
                    _buildScheduleRow(
                      'الوقت',
                      '${_formatTime(_group.startTime)} - ${_formatTime(_group.endTime)}',
                      Icons.access_time_rounded,
                    ),
                ] else
                  Center(
                    child: Text(
                      'لا توجد مواعيد محددة',
                      style: GoogleFonts.cairo(color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSessionItem(ScheduleSession session) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          _buildScheduleRow(
            'اليوم',
            _dayNameFromInt(session.dayOfWeek),
            Icons.calendar_today_rounded,
          ),
          SizedBox(height: 8.h),
          _buildScheduleRow(
            'الوقت',
            '${_formatTime(session.startTime)} - ${_formatTime(session.endTime)}',
            Icons.access_time_rounded,
          ),
          if (session.roomName.isNotEmpty) ...[
            SizedBox(height: 8.h),
            _buildScheduleRow(
              'القاعة',
              session.roomName,
              Icons.meeting_room_rounded,
            ),
          ],
        ],
      ),
    );
  }

  String _dayNameFromInt(int day) {
    const days = [
      'السبت',
      'الأحد',
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
    ];
    if (day >= 0 && day < days.length) return days[day];
    return 'Unknown';
  }

  String _formatTime(String? time) {
    if (time == null || time.isEmpty) return '';
    try {
      final parts = time.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final period = hour >= 12 ? 'م' : 'ص';
      final h = hour > 12
          ? hour - 12
          : hour == 0
          ? 12
          : hour;
      return '$h:${minute.toString().padLeft(2, '0')} $period';
    } catch (_) {
      return time;
    }
  }

  Future<void> _showAddSessionDialog() async {
    int selectedDay = 0;
    TimeOfDay selectedTime = const TimeOfDay(hour: 12, minute: 0);
    String? selectedRoomId;
    int selectedDuration = 60;
    String? selectedRoomName;

    // Load rooms
    List<Room> rooms = [];
    try {
      rooms = await context.read<RoomsRepository>().getRooms();
    } catch (_) {}

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('إضافة ميعاد جديد'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Day Selection
                  DropdownButtonFormField<int>(
                    value: selectedDay,
                    decoration: const InputDecoration(
                      labelText: 'اليوم',
                      prefixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('السبت')),
                      DropdownMenuItem(value: 1, child: Text('الأحد')),
                      DropdownMenuItem(value: 2, child: Text('الإثنين')),
                      DropdownMenuItem(value: 3, child: Text('الثلاثاء')),
                      DropdownMenuItem(value: 4, child: Text('الأربعاء')),
                      DropdownMenuItem(value: 5, child: Text('الخميس')),
                      DropdownMenuItem(value: 6, child: Text('الجمعة')),
                    ],
                    onChanged: (v) => setState(() => selectedDay = v!),
                  ),
                  const SizedBox(height: 16),

                  // Time Selection
                  InkWell(
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (time != null) {
                        setState(() => selectedTime = time);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'وقت البدء',
                        prefixIcon: Icon(Icons.access_time),
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        selectedTime.format(context),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Room Selection
                  DropdownButtonFormField<String>(
                    value: selectedRoomId,
                    decoration: const InputDecoration(
                      labelText: 'القاعة',
                      prefixIcon: Icon(Icons.meeting_room),
                      border: OutlineInputBorder(),
                    ),
                    items: rooms
                        .map(
                          (r) => DropdownMenuItem(
                            value: r.id,
                            child: Text(r.name),
                            onTap: () => selectedRoomName = r.name,
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => selectedRoomId = v),
                  ),
                  const SizedBox(height: 16),

                  // Duration Selection
                  DropdownButtonFormField<int>(
                    value: selectedDuration,
                    decoration: const InputDecoration(
                      labelText: 'المدة (دقيقة)',
                      prefixIcon: Icon(Icons.timer),
                      border: OutlineInputBorder(),
                    ),
                    items: [30, 45, 60, 90, 120]
                        .map(
                          (d) => DropdownMenuItem(
                            value: d,
                            child: Text('$d دقيقة'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => selectedDuration = v!),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  _addNewSession(
                    selectedDay,
                    selectedTime,
                    selectedRoomId,
                    selectedRoomName,
                    selectedDuration,
                  );
                },
                child: const Text('إضافة'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addNewSession(
    int day,
    TimeOfDay time,
    String? roomId,
    String? roomName,
    int duration,
  ) async {
    setState(() => _isLoading = true);

    try {
      final hour = time.hour.toString().padLeft(2, '0');
      final minute = time.minute.toString().padLeft(2, '0');
      final startTime = '$hour:$minute';

      // Calculate end time
      final startMinutes = time.hour * 60 + time.minute;
      final endMinutes = startMinutes + duration;
      final endHour = (endMinutes ~/ 60) % 24;
      final endMinute = endMinutes % 60;
      final endTime =
          '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';

      final newSession = ScheduleSession(
        id: const Uuid().v4(),
        subjectId: _group.courseId,
        subjectName: _group.courseName ?? '',
        teacherId: _group.teacherId ?? '',
        teacherName: _group.teacherName ?? '',
        roomId: roomId ?? '',
        roomName: roomName ?? '',
        dayOfWeek: day,
        startTime: startTime,
        endTime: endTime,
        status: SessionStatus.scheduled,
        groupName: _group.groupName,
      );

      final updatedSessions = List<ScheduleSession>.from(_group.sessions)
        ..add(newSession);

      final updatedGroup = _group.copyWith(sessions: updatedSessions);

      await context.read<GroupsRepository>().updateGroup(updatedGroup);

      if (mounted) {
        setState(() {
          _group = updatedGroup;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إضافة الميعاد بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل إضافة الميعاد: $e')));
      }
    }
  }

  Widget _buildScheduleRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Row(
        children: [
          Icon(icon, size: 20.sp, color: Colors.grey.shade600),
          SizedBox(width: 12.w),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.bold,
              fontSize: 16.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsTab() {
    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        // Capacity Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الطاقة الاستيعابية',
                  style: GoogleFonts.cairo(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16.h),

                LinearProgressIndicator(
                  value: widget.group.occupancyRate / 100,
                  backgroundColor: Colors.grey.shade200,
                  color: widget.group.isFull ? Colors.red : Colors.green,
                  minHeight: 10.h,
                  borderRadius: BorderRadius.circular(5.r),
                ),

                SizedBox(height: 12.h),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatItem(
                      'الحالي',
                      '${widget.group.currentStudents}',
                      Colors.blue,
                    ),
                    _buildStatItem(
                      'الأقصى',
                      '${widget.group.maxStudents}',
                      Colors.purple,
                    ),
                    _buildStatItem(
                      'المتاح',
                      '${widget.group.availableSlots}',
                      Colors.green,
                    ),
                    _buildStatItem(
                      'النسبة',
                      '${widget.group.occupancyRate.toStringAsFixed(0)}%',
                      Colors.orange,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        SizedBox(height: 16.h),

        // Revenue Card
        if (widget.group.monthlyFee != null)
          Card(
            child: Padding(
              padding: EdgeInsets.all(20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الإيرادات المتوقعة',
                    style: GoogleFonts.cairo(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16.h),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildRevenueItem(
                        'شهرياً',
                        '${widget.group.monthlyFee! * widget.group.currentStudents} ج',
                        Icons.calendar_month_rounded,
                      ),
                      _buildRevenueItem(
                        'لكل طالب',
                        '${widget.group.monthlyFee} ج',
                        Icons.person_rounded,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24.sp,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildRevenueItem(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16.sp, color: Colors.green.shade700),
            SizedBox(width: 6.w),
            Text(
              label,
              style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
            ),
          ],
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: GoogleFonts.cairo(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade700,
          ),
        ),
      ],
    );
  }

  Future<void> _showEnrollStudentDialog() async {
    await showDialog(
      context: context,
      builder: (context) => SmartEnrollmentDialog(
        group: widget.group,
        onEnrollmentComplete: () {
          _loadGroupData(); // Refresh the students list
        },
      ),
    );
  }

  void _editGroup() {
    // TODO: Show edit dialog
  }

  void _showOptions() {
    // TODO: Show more options
  }

  Future<void> _transferStudent(StudentGroupEnrollment enrollment) async {
    final repository = context.read<GroupsRepository>();
    // Fetch other groups
    final groups = await repository.getGroups();
    final otherGroups = groups
        .where(
          (g) => g.id != widget.group.id && g.courseId == widget.group.courseId,
        )
        .toList();

    if (!mounted) return;

    if (otherGroups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد مجموعات أخرى لنفس المادة')),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('نقل الطالب'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('نقل الطالب ${enrollment.studentName} إلى مجموعة:'),
              const SizedBox(height: 10),
              ...otherGroups.map(
                (group) => ListTile(
                  title: Text(group.groupName),
                  subtitle: Text('${group.dayName} ${group.startTime ?? ""}'),
                  onTap: () async {
                    try {
                      await repository.transferStudentToGroup(
                        studentId: enrollment.studentId,
                        fromGroupId: widget.group.id,
                        toGroupId: group.id,
                      );
                      if (mounted) {
                        Navigator.pop(context);
                        _loadGroupData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم نقل الطالب بنجاح'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('فشل النقل: $e')));
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _withdrawStudent(StudentGroupEnrollment enrollment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد السحب'),
        content: Text(
          'هل أنت متأكد من سحب الطالب ${enrollment.studentName} من المجموعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('سحب'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        final repository = context.read<GroupsRepository>();
        await repository.withdrawStudentFromGroup(
          studentId: enrollment.studentId,
          groupId: widget.group.id,
          reason: 'سحب يدوي من قبل المسؤول',
        );
        _loadGroupData(); // Refresh list
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم سحب الطالب بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل سحب الطالب: $e')));
      }
    }
  }

  Future<void> _startSmartAttendance() async {
    setState(() => _isLoading = true);

    try {
      // Default: Open now, close in 90 mins
      final opensAt = DateTime.now();
      final closesAt = opensAt.add(const Duration(minutes: 90));
      final onTimeUntil = opensAt.add(const Duration(minutes: 15));

      final session = await context
          .read<AttendanceRepository>()
          .createSmartSession(
            groupId: widget.group.id,
            opensAt: opensAt,
            closesAt: closesAt,
            onTimeUntil: onTimeUntil,
          );

      if (!mounted) return;

      setState(() => _isLoading = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SmartAttendanceScreen(
            groupId: widget.group.id,
            groupName: widget.group.groupName,
            sessionId: session['id'],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل بدء الحضور الذكي: $e')));
      }
    }
  }
}

class _EnrollStudentDialog extends StatefulWidget {
  final List<Map<String, dynamic>> students;
  final Function(String) onEnroll;

  const _EnrollStudentDialog({required this.students, required this.onEnroll});

  @override
  State<_EnrollStudentDialog> createState() => _EnrollStudentDialogState();
}

class _EnrollStudentDialogState extends State<_EnrollStudentDialog> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredStudents = widget.students.where((s) {
      final name = s['full_name']?.toString().toLowerCase() ?? '';
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    return AlertDialog(
      title: const Text('تسجيل طالب'),
      content: SizedBox(
        width: 400,
        height: 500,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'بحث عن طالب',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: filteredStudents.isEmpty
                  ? const Center(child: Text('لا يوجد طلاب متاحين'))
                  : ListView.builder(
                      itemCount: filteredStudents.length,
                      itemBuilder: (context, index) {
                        final student = filteredStudents[index];
                        return ListTile(
                          title: Text(student['full_name'] ?? 'طالب'),
                          subtitle: Text(
                            'ID: ${student['id'].toString().substring(0, 8)}...',
                          ),
                          trailing: const Icon(Icons.add_circle_outline),
                          onTap: () => widget.onEnroll(student['id']),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إغلاق'),
        ),
      ],
    );
  }
}
