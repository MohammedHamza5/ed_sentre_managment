import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/reports_repository.dart';
import '../../../../core/providers/center_provider.dart';
import '../../../../core/utils/form_validators.dart';
import '../../../../core/monitoring/app_logger.dart';

class StudentProfitabilityScreen extends StatefulWidget {
  const StudentProfitabilityScreen({super.key});

  @override
  State<StudentProfitabilityScreen> createState() =>
      _StudentProfitabilityScreenState();
}

class _StudentProfitabilityScreenState
    extends State<StudentProfitabilityScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _data = [];

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    AppLogger.ui('📊 [StudentProfitabilityScreen] Loading report...');
    setState(() => _isLoading = true);
    final repo = context.read<ReportsRepository>();
    final centerId = context.read<CenterProvider>().centerId!;
    try {
      final report = await repo.getStudentProfitabilityReport(centerId);
      if (mounted) {
        setState(() {
          _data = report;
          _isLoading = false;
        });
        AppLogger.success(
          '✅ [StudentProfitabilityScreen] Report loaded',
          data: {'count': report.length},
        );
      }
    } catch (e) {
      AppLogger.error(
        '❌ [StudentProfitabilityScreen] Load failed',
        error: e,
        source: ErrorSource.backend,
      );
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'star':
        return Colors.green;
      case 'good':
        return Colors.blue;
      case 'drain':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'star':
        return Icons.star_rounded;
      case 'good':
        return Icons.thumb_up_rounded;
      case 'drain':
        return Icons.warning_rounded;
      default:
        return Icons.remove_red_eye_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تقرير ربحية الطلاب 💰')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _data.isEmpty
          ? const Center(child: Text('لا توجد بيانات كافية للتحليل'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _data.length,
              itemBuilder: (context, index) {
                final item = _data[index];
                final reliability = (item['payment_reliability'] as num)
                    .toDouble();
                final status = item['status'] ?? 'monitor';

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      color: _getStatusColor(status).withValues(alpha: 0.5),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getStatusColor(status).withValues(alpha: 0.1),
                      child: Icon(
                        _getStatusIcon(status),
                        color: _getStatusColor(status),
                      ),
                    ),
                    title: Text(item['student_name'] ?? 'Unknown'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'دفع: ${FormUtils.formatCurrency((item['total_paid'] as num).toDouble())} / ${FormUtils.formatCurrency((item['total_invoiced'] as num).toDouble())}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: reliability / 100,
                          backgroundColor: Colors.grey[200],
                          color: _getStatusColor(status),
                          minHeight: 4,
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${reliability.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(status),
                          ),
                        ),
                        Text(
                          '${item['active_courses_count']} كورسات نشطة',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}


