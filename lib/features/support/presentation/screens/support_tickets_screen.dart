import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl; 
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/routing/route_names.dart';
import '../../data/repositories/support_repository.dart';
import '../dialogs/create_ticket_dialog.dart';

class SupportTicketsScreen extends StatefulWidget {
  const SupportTicketsScreen({super.key});

  @override
  State<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen> {
  final _repository = SupportRepository();
  bool _isLoading = true;
  List<Map<String, dynamic>> _tickets = [];

  @override
  void initState() {
    super.initState();
    _fetchTickets();
  }

  Future<void> _fetchTickets() async {
    setState(() => _isLoading = true);
    try {
      final tickets = await _repository.getCenterTickets();
      if (mounted) {
        setState(() {
          _tickets = tickets;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل في جلب التذاكر: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text('الدعم الفني', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateTicketDialog,
        icon: const Icon(Icons.add),
        label: const Text('تذكرة جديدة'),
        backgroundColor: AppColors.primary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tickets.isEmpty
              ? _buildEmptyState(isDark)
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: _tickets.length,
                  itemBuilder: (context, index) {
                    final ticket = _tickets[index];
                    return _buildTicketCard(ticket, isDark);
                  },
                ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.headset_mic_outlined,
            size: 64,
            color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد تذاكر دعم فني حالياً',
            style: GoogleFonts.cairo(
              fontSize: 18,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'واجهت مشكلة؟ افتح تذكرة جديدة وسنساعدك فوراً',
            style: TextStyle(
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket, bool isDark) {
    final status = ticket['status'] ?? 'open';
    final priority = ticket['priority'] ?? 'medium';
    final createdAt = DateTime.tryParse(ticket['created_at'] ?? '');

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      color: isDark ? AppColors.darkSurface : Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
      child: InkWell(
        onTap: () => context.push(
          RouteNames.supportChat.replaceFirst(':id', ticket['id']),
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      ticket['subject'] ?? 'بدون عنوان',
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildStatusChip(status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildPriorityChip(priority),
                  const SizedBox(width: 8),
                  if (createdAt != null)
                    Text(
                      intl.DateFormat('yyyy/MM/dd hh:mm a').format(createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;

    switch (status) {
      case 'open':
        color = Colors.blue;
        label = 'مفتوحة';
        break;
      case 'in_progress':
        color = Colors.orange;
        label = 'جاري العمل';
        break;
      case 'resolved':
        color = Colors.green;
        label = 'تم الحل';
        break;
      case 'closed':
        color = Colors.grey;
        label = 'مغلقة';
        break;
      default:
        color = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildPriorityChip(String priority) {
    Color color;
    String label;
    IconData icon;

    switch (priority) {
      case 'low':
        color = Colors.green;
        label = 'منخفضة';
        icon = Icons.low_priority;
        break;
      case 'medium':
        color = Colors.blue;
        label = 'متوسطة';
        icon = Icons.waves;
        break;
      case 'high':
        color = Colors.orange;
        label = 'عالية';
        icon = Icons.priority_high;
        break;
      case 'urgent':
        color = Colors.red;
        label = 'عاجلة';
        icon = Icons.error_outline;
        break;
      default:
        color = Colors.grey;
        label = priority;
        icon = Icons.help_outline;
    }

    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: color, fontSize: 12),
        ),
      ],
    );
  }

  Future<void> _showCreateTicketDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const CreateTicketDialog(),
    );

    if (result == true) {
      _fetchTickets();
    }
  }
}


