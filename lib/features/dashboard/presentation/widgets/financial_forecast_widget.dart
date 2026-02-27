import 'package:flutter/material.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/form_validators.dart';
import 'package:google_fonts/google_fonts.dart';

class FinancialForecastWidget extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isDark;

  const FinancialForecastWidget({
    super.key,
    required this.data,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // Smart data extraction with new RPC format
    final hasData = data['has_data'] as bool? ?? false;
    final message = data['message'] as String? ?? '';
    final tips = (data['tips'] as List?)?.cast<String>() ?? [];
    final status = data['status'] as String? ?? 'no_data';

    // Financial metrics
    final currentRevenue = (data['current_revenue'] as num?)?.toDouble() ?? 0.0;
    final projectedRevenue =
        (data['projected_revenue'] as num?)?.toDouble() ?? 0.0;
    final lastMonthRevenue =
        (data['last_month_revenue'] as num?)?.toDouble() ?? 0.0;
    final pendingInvoices =
        (data['pending_invoices'] as num?)?.toDouble() ?? 0.0;
    final growthPercent = (data['growth_percent'] as num?)?.toDouble() ?? 0.0;
    final daysPassed = data['days_passed'] as int? ?? 0;
    final daysTotal = data['days_total'] as int? ?? 30;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1F2937), const Color(0xFF111827)]
              : [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(
          color: isDark
              ? Colors.green.withValues(alpha: 0.2)
              : Colors.green.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'التنبؤ المالي 💰',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.green.shade900,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getStatusLabel(status),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(status),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Show message (always)
          if (message.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                message,
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : _getStatusColor(status),
                ),
                textAlign: TextAlign.center,
              ),
            ),

          if (!hasData) ...[
            // 🆕 NEW CENTER: Show onboarding tips
            const SizedBox(height: AppSpacing.md),
            ...tips.map(
              (tip) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 16,
                      color: Colors.amber.shade600,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tip,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.grey.shade300
                              : Colors.green.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // 📈 ESTABLISHED CENTER: Show financial metrics
            const SizedBox(height: AppSpacing.lg),

            // Main Projection
            Text(
              'الدخل المتوقع لنهاية الشهر',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade400 : Colors.green.shade700,
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  FormUtils.formatCurrency(projectedRevenue),
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.green.shade900,
                  ),
                ),
                if (growthPercent != 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: growthPercent > 0
                          ? Colors.green.withValues(alpha: 0.2)
                          : Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${growthPercent > 0 ? '+' : ''}${growthPercent.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: growthPercent > 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: daysTotal > 0
                    ? (daysPassed / daysTotal).clamp(0.0, 1.0)
                    : 0,
                backgroundColor: isDark ? Colors.black26 : Colors.white,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getStatusColor(status),
                ),
                minHeight: 8,
              ),
            ),

            const SizedBox(height: 8),

            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatChip(
                  'الحالي',
                  FormUtils.formatCurrency(currentRevenue),
                  isDark,
                ),
                _buildStatChip(
                  'المتأخرات',
                  FormUtils.formatCurrency(pendingInvoices),
                  isDark,
                  isWarning: pendingInvoices > 0,
                ),
                Text(
                  'يوم $daysPassed/$daysTotal',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? Colors.grey.shade400
                        : Colors.green.shade700,
                  ),
                ),
              ],
            ),

            // Last month comparison
            if (lastMonthRevenue > 0) ...[
              const SizedBox(height: 8),
              Text(
                'الشهر الماضي: ${FormUtils.formatCurrency(lastMonthRevenue)}',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildStatChip(
    String label,
    String value,
    bool isDark, {
    bool isWarning = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isWarning
                ? Colors.orange
                : (isDark ? Colors.grey.shade300 : Colors.green.shade800),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'surging':
        return Colors.green.shade700;
      case 'growing':
        return Colors.green;
      case 'stable':
        return Colors.blue;
      case 'declining':
        return Colors.orange;
      case 'critical':
        return Colors.red;
      case 'no_data':
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'surging':
        return '🚀 نمو استثنائي';
      case 'growing':
        return '📈 نمو إيجابي';
      case 'stable':
        return '⚖️ مستقر';
      case 'declining':
        return '⚠️ انخفاض';
      case 'critical':
        return '🔴 تحذير';
      case 'no_data':
      default:
        return '🆕 جديد';
    }
  }
}
