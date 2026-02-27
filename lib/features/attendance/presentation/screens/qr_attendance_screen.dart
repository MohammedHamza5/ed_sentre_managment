/// QR Attendance Screen - شاشة الحضور بـ QR
/// For displaying QR code during attendance session
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import 'package:provider/provider.dart';
import '../../data/repositories/attendance_repository.dart';
import 'take_attendance_screen.dart';

class QRAttendanceScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final int durationMinutes;

  const QRAttendanceScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    this.durationMinutes = 90,
  });

  @override
  State<QRAttendanceScreen> createState() => _QRAttendanceScreenState();
}

class _QRAttendanceScreenState extends State<QRAttendanceScreen> {
  Map<String, dynamic>? _session;
  Map<String, dynamic>? _status;
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;
  Timer? _countdownTimer;
  Duration _remainingTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startSession();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _startSession() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final session = await context
          .read<AttendanceRepository>()
          .startAttendanceSession(
            groupId: widget.groupId,
            durationMinutes: widget.durationMinutes,
          );

      setState(() {
        _session = session;
        _isLoading = false;
      });

      // Calculate remaining time
      _updateRemainingTime();

      // Start countdown timer
      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {
            _updateRemainingTime();
          });
        }
      });

      // Refresh status every 5 seconds
      _refreshTimer?.cancel();
      _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _refreshStatus();
      });

      // Initial status fetch
      await _refreshStatus();
    } catch (e) {
      final errorMessage = e.toString();
      setState(() {
        _error = errorMessage.replaceAll('Exception:', '').trim();
        _isLoading = false;
      });
    }
  }

  void _updateRemainingTime() {
    if (_session == null) return;

    try {
      final closesAtStr = _session!['closes_at']?.toString();
      if (closesAtStr != null) {
        final closesAt = DateTime.tryParse(closesAtStr);
        if (closesAt != null) {
          // Adjust for timezone if needed, usually Supabase returns UTC or Offset
          final now = DateTime.now(); // Local time
          // Parse as UTC if 'Z' is present, then convert to local for diff
          final closesAtLocal = closesAt.isUtc ? closesAt.toLocal() : closesAt;

          final diff = closesAtLocal.difference(now);
          if (diff.isNegative) {
            _remainingTime = Duration.zero;
          } else {
            _remainingTime = diff;
          }
        }
      } else {
        // Fallback or use API returned remaining seconds if available
        if (_status != null && _status!['time_remaining_seconds'] != null) {
          final seconds = (_status!['time_remaining_seconds'] as num).toInt();
          _remainingTime = Duration(seconds: seconds);
        }
      }
    } catch (_) {
      // ignore
    }
  }

  // FORCE DIALOG REMOVED AS IT IS NOT SUPPORTED BY DB RPC ANYMORE

  Future<void> _refreshStatus() async {
    if (_session == null) return;

    try {
      final status = await context
          .read<AttendanceRepository>()
          .getAttendanceSessionStatus(_session!['session_id']);
      if (mounted) {
        setState(() => _status = status);
        // Sync timer with server time remaining if available
        if (status['time_remaining_seconds'] != null) {
          // Optional: re-sync calculation
        }
      }
    } catch (e) {
      debugPrint('Error refreshing status: $e');
    }
  }

  Future<void> _endSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إنهاء الحضور'),
        content: const Text('هل تريد إنهاء جلسة الحضور وتسجيل الغائبين؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('إنهاء وتسجيل الغائبين'),
          ),
        ],
      ),
    );

    if (confirmed == true && _session != null) {
      try {
        await context.read<AttendanceRepository>().endAttendanceSession(
          _session!['session_id'],
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إنهاء الجلسة بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      appBar: AppBar(
        title: Text('حضور ${widget.groupName}'),
        centerTitle: true,
        actions: [
          if (_session != null)
            TextButton.icon(
              onPressed: _endSession,
              icon: const Icon(Icons.stop_circle_outlined, color: Colors.red),
              label: const Text('إنهاء', style: TextStyle(color: Colors.red)),
            ),
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'تحضير يدوي',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TakeAttendanceScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildErrorWidget()
          : _buildContent(isDark),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.timer_off_outlined, size: 64, color: Colors.orange),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _error ?? 'حدث خطأ',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('عودة'),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => _startSession(),
                icon: const Icon(Icons.refresh),
                label: const Text('تحديث'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    return Row(
      children: [
        // QR Code Side
        Expanded(flex: 2, child: _buildQRSide(isDark)),

        // Divider
        Container(
          width: 1,
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),

        // Status Side
        Expanded(flex: 1, child: _buildStatusSide(isDark)),
      ],
    );
  }

  Widget _buildQRSide(bool isDark) {
    final token = _session?['session_token'] ?? '';
    final opensAt = DateTime.tryParse(_session?['opens_at'] ?? '');
    final closesAt = DateTime.tryParse(_session?['closes_at'] ?? '');
    final onTimeUntil = DateTime.tryParse(_session?['on_time_until'] ?? '');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Title
          Text(
            'امسح للحضور',
            style: GoogleFonts.cairo(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // Time details chip
          if (onTimeUntil != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Text(
                '✅ حضور منتظم حتى ${DateFormat('hh:mm a').format(onTimeUntil)}',
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          // QR Code
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: QrImageView(
              data: token,
              version: QrVersions.auto,
              size: 300,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: AppColors.primary,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Countdown Timer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: _remainingTime.inMinutes < 5
                  ? Colors.red.withValues(alpha: 0.1)
                  : AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_outlined,
                  color: _remainingTime.inMinutes < 5
                      ? Colors.red
                      : AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDuration(_remainingTime),
                  style: GoogleFonts.robotoMono(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _remainingTime.inMinutes < 5
                        ? Colors.red
                        : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Expires at info
          if (closesAt != null)
            Text(
              'يغلق الباب في ${DateFormat('hh:mm a').format(closesAt)}',
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusSide(bool isDark) {
    final totalStudents = (_status?['total_students'] as num?)?.toInt() ?? 0;
    final presentCount = (_status?['present_count'] as num?)?.toInt() ?? 0;
    final lateCount = (_status?['late_count'] as num?)?.toInt() ?? 0;
    final absentCount =
        (_status?['absent_count'] as num?)?.toInt() ??
        0; // Updated logic in SQL
    final attendanceRate =
        (_status?['attendance_rate'] as num?)?.toDouble() ?? 0.0;
    final presentStudents = (_status?['present_students'] as List?) ?? [];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      color: isDark ? AppColors.darkSurface : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'إحصائيات الحضور',
            style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Stats Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'الإجمالي',
                  totalStudents,
                  Colors.blue,
                  isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  'حاضر',
                  presentCount,
                  Colors.green,
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'متأخر',
                  lateCount,
                  Colors.orange,
                  isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard('غائب', absentCount, Colors.red, isDark),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // Attendance Rate
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurfaceVariant
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Column(
              children: [
                Text(
                  'نسبة الحضور',
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${attendanceRate.toStringAsFixed(1)}%',
                  style: GoogleFonts.cairo(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: attendanceRate >= 75
                        ? Colors.green
                        : attendanceRate >= 50
                        ? Colors.orange
                        : Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: attendanceRate / 100,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation(
                    attendanceRate >= 75
                        ? Colors.green
                        : attendanceRate >= 50
                        ? Colors.orange
                        : Colors.red,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Present Students List
          Text(
            'الحاضرون (${presentStudents.length})',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: presentStudents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 48,
                          color: isDark
                              ? Colors.grey.shade600
                              : Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'في انتظار الطلاب...',
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: presentStudents.length,
                    itemBuilder: (context, index) {
                      final student =
                          presentStudents[index] as Map<String, dynamic>;
                      final checkInTime = DateTime.tryParse(
                        student['check_in_time'] ?? '',
                      );
                      final status = student['status'] ?? 'present';
                      final isLate = status == 'late';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isLate
                              ? Colors.orange.withValues(alpha: 0.2)
                              : Colors.green.withValues(alpha: 0.2),
                          child: Icon(
                            isLate ? Icons.access_time : Icons.check,
                            color: isLate ? Colors.orange : Colors.green,
                            size: 20,
                          ),
                        ),
                        title: Text(student['name'] ?? ''),
                        subtitle: checkInTime != null
                            ? Text(
                                '${isLate ? "تأخر" : "حضر"} ${DateFormat('hh:mm a').format(checkInTime)}',
                                style: const TextStyle(fontSize: 12),
                              )
                            : null,
                        dense: true,
                        trailing: isLate
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.orange.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: const Text(
                                  'متأخر',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 10,
                                  ),
                                ),
                              )
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            value.toString(),
            style: GoogleFonts.cairo(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}


