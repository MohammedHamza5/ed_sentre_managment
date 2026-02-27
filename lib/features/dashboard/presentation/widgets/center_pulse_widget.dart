import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import 'package:google_fonts/google_fonts.dart';

class CenterPulseWidget extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool isDark;

  const CenterPulseWidget({
    super.key,
    required this.data,
    required this.isDark,
  });

  @override
  State<CenterPulseWidget> createState() => _CenterPulseWidgetState();
}

class _CenterPulseWidgetState extends State<CenterPulseWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  int get _score => widget.data['score'] as int? ?? 0;
  bool get _isNewCenter => widget.data['is_new_center'] as bool? ?? false;
  String get _message => widget.data['message'] as String? ?? '';
  String get _status => widget.data['status'] as String? ?? 'healthy';
  Map<String, dynamic>? get _checklist =>
      widget.data['checklist'] as Map<String, dynamic>?;
  int get _setupProgress => widget.data['setup_progress'] as int? ?? 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0,
      end: _score.toDouble(),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void didUpdateWidget(CenterPulseWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldScore = oldWidget.data['score'] as int? ?? 0;
    if (oldScore != _score) {
      _animation =
          Tween<double>(
            begin: oldScore.toDouble(),
            end: _score.toDouble(),
          ).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
          );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getScoreColor(double value) {
    if (_isNewCenter) {
      // For new centers, show progress colors
      if (value >= 80) return Colors.greenAccent;
      if (value >= 40) return Colors.blueAccent;
      return Colors.orangeAccent;
    }
    if (value >= 80) return Colors.greenAccent;
    if (value >= 60) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  String _getScoreLabel(int score) {
    if (_isNewCenter) {
      switch (_status) {
        case 'setup_required':
          return 'ابدأ الإعداد 🆕';
        case 'setting_up':
          return 'جارٍ الإعداد 🔧';
        case 'almost_ready':
          return 'اقتربت! ⭐';
        case 'ready':
          return 'جاهز 🚀';
        default:
          return 'جديد';
      }
    }
    if (score >= 90) return 'ممتاز 🚀';
    if (score >= 80) return 'جيد جداً ✨';
    if (score >= 60) return 'متوسط ⚠️';
    return 'يحتاج تحسين 🚨';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg.w),
      decoration: BoxDecoration(
        color: widget.isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _isNewCenter ? 'تقدم الإعداد 🔧' : 'نبض السنتر ❤️',
            style: GoogleFonts.cairo(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: widget.isDark ? Colors.white : Colors.black87,
            ),
          ),
          SizedBox(height: AppSpacing.lg.h),
          SizedBox(
            height: 160.w,
            width: 160.w,
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return CustomPaint(
                  painter: _PulsePainter(
                    score: _animation.value,
                    color: _getScoreColor(_animation.value),
                    isDark: widget.isDark,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_animation.value.toInt()}%',
                          style: GoogleFonts.outfit(
                            fontSize: 38.sp,
                            fontWeight: FontWeight.bold,
                            color: _getScoreColor(_animation.value),
                          ),
                        ),
                        Text(
                          _getScoreLabel(_animation.value.toInt()),
                          style: GoogleFonts.cairo(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: widget.isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Message
          if (_message.isNotEmpty) ...[
            SizedBox(height: AppSpacing.sm.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: _getScoreColor(
                  _score.toDouble(),
                ).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                _message,
                style: GoogleFonts.cairo(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? Colors.white70 : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],

          // Checklist for new centers
          if (_isNewCenter && _checklist != null) ...[
            SizedBox(height: AppSpacing.md.h),
            _buildChecklist(),
          ],

          // Footer text
          if (!_isNewCenter) ...[
            SizedBox(height: AppSpacing.md.h),
            Text(
              'يعتمد على التحصيل والربحية والنمو',
              style: TextStyle(
                fontSize: 10.sp,
                color: widget.isDark
                    ? Colors.grey.shade500
                    : Colors.grey.shade400,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChecklist() {
    final items = [
      {'key': 'has_teachers', 'label': 'معلمون', 'icon': Icons.school},
      {'key': 'has_courses', 'label': 'مواد', 'icon': Icons.book},
      {'key': 'has_groups', 'label': 'مجموعات', 'icon': Icons.groups},
      {'key': 'has_students', 'label': 'طلاب', 'icon': Icons.person},
      {'key': 'has_invoices', 'label': 'فواتير', 'icon': Icons.receipt},
    ];

    return Wrap(
      spacing: 8.w,
      runSpacing: 6.h,
      alignment: WrapAlignment.center,
      children: items.map((item) {
        final isDone = _checklist?[item['key']] == true;
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: isDone
                ? Colors.green.withValues(alpha: 0.2)
                : (widget.isDark ? Colors.grey.shade800 : Colors.grey.shade200),
            borderRadius: BorderRadius.circular(12.r),
            border: isDone ? Border.all(color: Colors.green, width: 1) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isDone ? Icons.check_circle : (item['icon'] as IconData),
                size: 14.sp,
                color: isDone ? Colors.green : Colors.grey,
              ),
              SizedBox(width: 4.w),
              Text(
                item['label'] as String,
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
                  color: isDone
                      ? Colors.green
                      : (widget.isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600),
                  decoration: isDone ? TextDecoration.lineThrough : null,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _PulsePainter extends CustomPainter {
  final double score;
  final Color color;
  final bool isDark;

  _PulsePainter({
    required this.score,
    required this.color,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2) - 10;
    final strokeWidth = 12.0.w;

    // Background Arc
    final bgPaint = Paint()
      ..color = isDark ? Colors.grey.shade800 : Colors.grey.shade200
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi * 0.75,
      pi * 1.5,
      false,
      bgPaint,
    );

    // Score Arc
    final scorePaint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2);

    final sweepAngle = (pi * 1.5) * (score / 100);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi * 0.75,
      sweepAngle,
      false,
      scorePaint,
    );
  }

  @override
  bool shouldRepaint(_PulsePainter oldDelegate) =>
      oldDelegate.score != score || oldDelegate.isDark != isDark;
}
