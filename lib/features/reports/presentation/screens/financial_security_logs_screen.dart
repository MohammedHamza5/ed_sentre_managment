import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/reports_repository.dart';
import '../../../../core/providers/center_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/monitoring/app_logger.dart';
import 'package:timeago/timeago.dart' as timeago;

class FinancialSecurityLogsScreen extends StatefulWidget {
  const FinancialSecurityLogsScreen({super.key});

  @override
  State<FinancialSecurityLogsScreen> createState() =>
      _FinancialSecurityLogsScreenState();
}

class _FinancialSecurityLogsScreenState
    extends State<FinancialSecurityLogsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    AppLogger.ui('🛡️ [FinancialSecurityLogsScreen] Loading audit logs...');
    setState(() => _isLoading = true);
    final repo = context.read<ReportsRepository>();
    final centerId = context.read<CenterProvider>().centerId!;
    try {
      final logs = await repo.getRecentAuditLogs(centerId);
      if (mounted) {
        setState(() {
          _logs = logs;
          _isLoading = false;
        });
        AppLogger.success(
          '✅ [FinancialSecurityLogsScreen] Logs loaded',
          data: {'count': logs.length},
        );
      }
    } catch (e) {
      AppLogger.error(
        '❌ [FinancialSecurityLogsScreen] Load failed',
        error: e,
        source: ErrorSource.backend,
      );
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getActionIcon(String type) {
    if (type == 'INSERT') return '🟢';
    if (type == 'UPDATE') return '🟠';
    if (type == 'DELETE') return '🔴';
    return '⚪';
  }

  String _formatTableName(String table) {
    switch (table) {
      case 'course_prices':
        return 'أسعار المواد';
      case 'teacher_salary_tiers':
        return 'شرائح المعلمين';
      case 'teacher_bonuses':
        return 'مكافآت المعلمين';
      default:
        return table;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل الرقابة المالية 🛡️'),
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    size: 64,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 16),
                  const Text('النظام آمن. لا توجد تغييرات حساسة مؤخراً.'),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _logs.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final log = _logs[index];
                final action = log['action_type'];
                final table = _formatTableName(log['table_name']);
                final user = log['users'] != null
                    ? log['users']['full_name']
                    : 'غير معروف';
                final time = DateTime.parse(log['created_at']);

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.transparent,
                    child: Text(
                      _getActionIcon(action),
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  title: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      children: [
                        TextSpan(
                          text: '$user ',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(text: 'قام بـ '),
                        TextSpan(
                          text: action == 'DELETE'
                              ? 'حذف'
                              : (action == 'UPDATE' ? 'تعديل' : 'إضافة'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: action == 'DELETE'
                                ? Colors.red
                                : Colors.blue,
                          ),
                        ),
                        const TextSpan(text: ' في '),
                        TextSpan(
                          text: table,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  subtitle: Text(
                    timeago.format(time, locale: 'ar'),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('تفاصيل التغيير'),
                        content: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (log['old_data'] != null) ...[
                                const Text(
                                  'قبل التعديل:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                                Text(log['old_data'].toString()),
                                const SizedBox(height: 16),
                              ],
                              if (log['new_data'] != null) ...[
                                const Text(
                                  'بعد التعديل:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                Text(log['new_data'].toString()),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}


