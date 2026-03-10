/// Enhanced Attendance Screen - EdSentre
/// واجهة تسجيل الحضور الذكية
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../shared/models/models.dart';
import '../../groups/data/repositories/groups_repository.dart';
import '../../subjects/data/repositories/subjects_repository.dart';
import '../data/repositories/attendance_repository.dart';

class EnhancedAttendanceScreen extends StatefulWidget {
  const EnhancedAttendanceScreen({super.key});

  @override
  State<EnhancedAttendanceScreen> createState() =>
      _EnhancedAttendanceScreenState();
}

class _EnhancedAttendanceScreenState extends State<EnhancedAttendanceScreen> {
  // Filters
  String? _selectedCourseId;
  Group? _selectedGroup;
  DateTime _selectedDate = DateTime.now();

  // Data
  List<Map<String, dynamic>> _students = []; // Merged data from RPC
  List<Map<String, dynamic>> _courses = [];
  List<Group> _groups = [];

  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    try {
      final repository = context.read<SubjectsRepository>();
      final subjects = await repository.getSubjects();
      if (mounted) {
        setState(() {
          _courses = subjects.map((s) => {'id': s.id, 'name': s.name}).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading courses: $e');
    }
  }

  Future<void> _loadGroups(String courseId) async {
    try {
      // Clear current group selection
      setState(() {
        _selectedGroup = null;
        _students = [];
      });

      final repository = context.read<GroupsRepository>();
      final filtered = await repository.getGroups(courseId: courseId);

      if (mounted) setState(() => _groups = filtered);
    } catch (e) {
      debugPrint('Error loading groups: $e');
    }
  }

  Future<void> _loadAttendanceSheet() async {
    if (_selectedGroup == null) return;

    setState(() => _isLoading = true);
    try {
      final repository = context.read<AttendanceRepository>();
      final data = await repository.getGroupAttendanceSheet(
        _selectedGroup!.id,
        _selectedDate,
      );

      if (mounted) {
        setState(() {
          _students = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading sheet: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في تحميل القائمة: $e')));
      }
    }
  }

  // Actions
  void _toggleAttendance(int index, String status) {
    setState(() {
      _students[index]['attendance_status'] = status;
    });
  }

  void _markAll(String status) {
    setState(() {
      for (var s in _students) {
        s['attendance_status'] = status;
      }
    });
  }

  Future<void> _saveAttendance() async {
    if (_students.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      final repository = context.read<AttendanceRepository>();

      // Convert UI maps to models (simplified)
      final records = _students
          .where((s) => s['attendance_status'] != null)
          .map(
            (s) => AttendanceRecord(
              id: '', // New record
              studentId: s['student_id'],
              studentName: s['student_name'],
              sessionId: _selectedGroup!
                  .id, // We use sessionId to store group_id for now
              date: _selectedDate,
              status: AttendanceStatus.values.firstWhere(
                (e) => e.name == s['attendance_status'],
                orElse: () => AttendanceStatus.present,
              ),
            ),
          )
          .toList();

      await repository.addBulkAttendance(records);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم حفظ الحضور بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ فشل الحفظ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Stats
    final total = _students.length;
    final present = _students
        .where((s) => s['attendance_status'] == 'present')
        .length;
    final absent = _students
        .where((s) => s['attendance_status'] == 'absent')
        .length;
    final unknown = total - present - absent;

    return Scaffold(
      body: Column(
        children: [
          // 1. Header & Filters
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Title row
                  Row(
                    children: [
                      const Icon(Icons.fact_check_rounded, color: Colors.blue),
                      const SizedBox(width: 10),
                      Text(
                        'تسجيل الحضور',
                        style: GoogleFonts.cairo(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (_selectedGroup != null)
                        Text(
                          DateFormat('yyyy-MM-dd').format(_selectedDate),
                          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                        ),
                      IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                            initialDate: _selectedDate,
                          );
                          if (d != null) {
                            if (!mounted) return;
                            setState(() => _selectedDate = d);
                            _loadAttendanceSheet();
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Filters Row
                  Row(
                    children: [
                      // Course Filter
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedCourseId,
                          decoration: InputDecoration(
                            labelText: 'المادة',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          items: _courses
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c['id'] as String,
                                  child: Text(c['name']),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            setState(() => _selectedCourseId = v);
                            if (v != null) _loadGroups(v);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Group Filter
                      Expanded(
                        child: DropdownButtonFormField<Group>(
                          value: _selectedGroup,
                          decoration: InputDecoration(
                            labelText: 'المجموعة',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          items: _groups
                              .map(
                                (g) => DropdownMenuItem(
                                  value: g,
                                  child: Text(g.groupName),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            setState(() => _selectedGroup = v);
                            if (v != null) _loadAttendanceSheet();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 2. Stats Bar
          if (_selectedGroup != null)
            Container(
              color: Colors.blue.withValues(alpha: 0.05),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStat('الكل', '$total', Colors.black),
                  _buildStat('حضور', '$present', Colors.green),
                  _buildStat('غياب', '$absent', Colors.red),
                  _buildStat('غير مسجل', '$unknown', Colors.grey),
                ],
              ),
            ),

          // 3. Student List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _selectedGroup == null
                ? Center(
                    child: Text(
                      'اختر المجموعة لعرض الطلاب',
                      style: GoogleFonts.cairo(color: Colors.grey),
                    ),
                  )
                : _students.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.people_outline,
                          size: 48,
                          color: Colors.grey,
                        ),
                        Text(
                          'لا يوجد طلاب في هذه المجموعة',
                          style: GoogleFonts.cairo(),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _students.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final student = _students[index];
                      final status = student['attendance_status'];

                      return Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              // Avatar
                              const CircleAvatar(child: Icon(Icons.person)),
                              const SizedBox(width: 12),

                              // Name
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      student['student_name'] ?? 'Unknown',
                                      style: GoogleFonts.cairo(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      student['student_phone'] ?? '-',
                                      style: GoogleFonts.cairo(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Actions
                              // Present Checkbox
                              InkWell(
                                onTap: () =>
                                    _toggleAttendance(index, 'present'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: status == 'present'
                                        ? Colors.green.withValues(alpha: 0.1)
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: status == 'present'
                                          ? Colors.green
                                          : Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        size: 20,
                                        color: status == 'present'
                                            ? Colors.green
                                            : Colors.grey,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'حاضر',
                                        style: GoogleFonts.cairo(
                                          fontSize: 12,
                                          color: status == 'present'
                                              ? Colors.green
                                              : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Absent Checkbox
                              InkWell(
                                onTap: () => _toggleAttendance(index, 'absent'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: status == 'absent'
                                        ? Colors.red.withValues(alpha: 0.1)
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: status == 'absent'
                                          ? Colors.red
                                          : Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.cancel,
                                        size: 20,
                                        color: status == 'absent'
                                            ? Colors.red
                                            : Colors.grey,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'غائب',
                                        style: GoogleFonts.cairo(
                                          fontSize: 12,
                                          color: status == 'absent'
                                              ? Colors.red
                                              : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // 4. Bottom Actions
          if (_selectedGroup != null)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _markAll('present'),
                        child: const Text('حاضر للكل'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _isSaving ? null : _saveAttendance,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: const Text('حفظ الحضور'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.cairo(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
