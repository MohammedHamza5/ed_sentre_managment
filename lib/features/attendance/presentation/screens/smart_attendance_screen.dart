import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../data/repositories/attendance_repository.dart';

class SmartAttendanceScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String sessionId;

  const SmartAttendanceScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.sessionId,
  });

  @override
  State<SmartAttendanceScreen> createState() => _SmartAttendanceScreenState();
}

class _SmartAttendanceScreenState extends State<SmartAttendanceScreen> {
  String? _qrData;
  Timer? _qrTimer;
  Timer? _statusTimer;
  Map<String, dynamic>? _sessionStatus;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshQr();
    _startTimers();
    _fetchStatus();
  }

  @override
  void dispose() {
    _qrTimer?.cancel();
    _statusTimer?.cancel();
    super.dispose();
  }

  void _startTimers() {
    // Refresh QR every 15 seconds (aligned with backend rotation)
    _qrTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _refreshQr();
    });

    // Refresh status every 5 seconds
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchStatus();
    });
  }

  Future<void> _refreshQr() async {
    try {
      final qr = await context.read<AttendanceRepository>().getSessionQr(
        widget.sessionId,
      );
      if (mounted) {
        setState(() => _qrData = qr);
      }
    } catch (e) {
      debugPrint('Error refreshing QR: $e');
    }
  }

  Future<void> _fetchStatus() async {
    try {
      final status = await context
          .read<AttendanceRepository>()
          .getAttendanceSessionStatus(widget.sessionId);
      if (mounted) {
        setState(() {
          _sessionStatus = status;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Calculate stats
    final presentCount = _sessionStatus?['present_count'] ?? 0;
    final totalStudents = _sessionStatus?['total_students'] ?? 0;
    final attendanceRate = _sessionStatus?['attendance_rate'] ?? 0.0;
    final students = _sessionStatus?['present_students'] as List? ?? [];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.grey[50],
      appBar: AppBar(
        title: Text('الحضور الذكي - ${widget.groupName}'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _refreshQr();
              _fetchStatus();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // Right Side: QR Code & Timer
                Expanded(
                  flex: 5,
                  child: Container(
                    padding: EdgeInsets.all(24.w),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildQrCard(isDark),
                        SizedBox(height: 32.h),
                        _buildTimeStatus(isDark),
                        SizedBox(height: 32.h),
                        _buildSessionControls(isDark),
                      ],
                    ),
                  ),
                ),

                // Vertical Divider
                Container(
                  width: 1,
                  color: isDark ? Colors.white10 : Colors.grey[300],
                ),

                // Left Side: Live Stats & List
                Expanded(
                  flex: 3,
                  child: Container(
                    color: isDark ? const Color(0xFF252525) : Colors.white,
                    padding: EdgeInsets.all(24.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatsHeader(
                          presentCount,
                          totalStudents,
                          attendanceRate,
                          isDark,
                        ),
                        SizedBox(height: 24.h),
                        const Divider(),
                        SizedBox(height: 16.h),
                        Text(
                          'سجل الحضور اللحظي',
                          style: GoogleFonts.cairo(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16.h),
                        Expanded(
                          child: ListView.builder(
                            itemCount: students.length,
                            itemBuilder: (context, index) {
                              final student = students[index];
                              return _buildStudentTile(student, isDark);
                            },
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

  Widget _buildQrCard(bool isDark) {
    return Container(
      padding: EdgeInsets.all(32.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          if (_qrData != null)
            QrImageView(
              data: _qrData!,
              version: QrVersions.auto,
              size: 300.w,
              backgroundColor: Colors.white,
            )
          else
            SizedBox(
              height: 300.w,
              width: 300.w,
              child: const Center(child: CircularProgressIndicator()),
            ),
          SizedBox(height: 16.h),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.security, color: Colors.green, size: 20),
              SizedBox(width: 8.w),
              Text(
                'رمز مشفر - يتغير كل 15 ثانية',
                style: GoogleFonts.cairo(
                  color: Colors.grey[600],
                  fontSize: 14.sp,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeStatus(bool isDark) {
    final remainingSeconds = _sessionStatus?['time_remaining_seconds'] ?? 0;
    final duration = Duration(seconds: remainingSeconds);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(50.r),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.blue.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, color: Colors.blue[400]),
          SizedBox(width: 12.w),
          Text(
            _formatDuration(duration),
            style: GoogleFonts.robotoMono(
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              color: Colors.blue[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader(int present, int total, dynamic rate, bool isDark) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStatItem('الحضور', present.toString(), Colors.green, isDark),
            _buildStatItem(
              'الغياب',
              (total - present).toString(),
              Colors.red,
              isDark,
            ),
            _buildStatItem('المجموع', total.toString(), Colors.blue, isDark),
          ],
        ),
        SizedBox(height: 24.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(8.r),
          child: LinearProgressIndicator(
            value: total > 0 ? present / total : 0,
            minHeight: 8.h,
            backgroundColor: isDark ? Colors.white10 : Colors.grey[100],
            valueColor: const AlwaysStoppedAnimation(Colors.green),
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          'نسبة الحضور: $rate%',
          style: TextStyle(color: Colors.grey[600], fontSize: 12.sp),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, Color color, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.cairo(
            fontSize: 24.sp,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 12.sp,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildStudentTile(Map<String, dynamic> student, bool isDark) {
    final status = student['status'];
    final time = student['check_in_time'];
    final isLate = status == 'late';

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16.r,
            backgroundColor: isLate
                ? Colors.orange.withOpacity(0.2)
                : Colors.green.withOpacity(0.2),
            child: Icon(
              isLate ? Icons.access_time : Icons.check,
              size: 16.sp,
              color: isLate ? Colors.orange : Colors.green,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student['name'] ?? 'مستخدم',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                  ),
                ),
                Text(
                  time != null
                      ? DateFormat('hh:mm:ss a').format(DateTime.parse(time))
                      : '-',
                  style: GoogleFonts.roboto(
                    fontSize: 12.sp,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          if (isLate)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Text(
                'متأخر',
                style: GoogleFonts.cairo(
                  fontSize: 10.sp,
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSessionControls(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: () {}, // Todo: Implement extend time
          icon: const Icon(Icons.add_alarm),
          label: const Text('تمديد الوقت'),
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
          ),
        ),
        SizedBox(width: 16.w),
        OutlinedButton.icon(
          onPressed: () async {
            await context.read<AttendanceRepository>().endAttendanceSession(
              widget.sessionId,
            );
            if (mounted) Navigator.pop(context);
          },
          icon: const Icon(Icons.stop_circle_outlined, color: Colors.red),
          label: const Text(
            'إنهاء الجلسة',
            style: TextStyle(color: Colors.red),
          ),
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
            side: const BorderSide(color: Colors.red),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }
}
