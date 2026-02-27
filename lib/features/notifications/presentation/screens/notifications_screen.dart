import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../data/repositories/notifications_repository.dart';
import '../../../../core/providers/center_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _repository = NotificationsRepository();
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    try {
      final data = await _repository.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = data;
          _isLoading = false;
        });
        
        // Sync Reader Count
        final unreadCount = data.where((n) => n['is_read'] == false).length;
        context.read<CenterProvider>().updateUnreadCount(unreadCount);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markAsRead(String id) async {
    try {
      await _repository.markNotificationRead(id);
      setState(() {
        final index = _notifications.indexWhere((n) => n['id'] == id);
        if (index != -1) {
          _notifications[index]['is_read'] = true;
        }
      });
      // Update Provider
      if (mounted) {
        final currentCount = context.read<CenterProvider>().unreadNotificationsCount;
        if (currentCount > 0) {
          context.read<CenterProvider>().updateUnreadCount(currentCount - 1);
        }
      }
    } catch (_) {}
  }

  Future<void> _markAllAsRead() async {
    try {
      await _repository.markAllNotificationsRead();
      setState(() {
        for (var n in _notifications) {
          n['is_read'] = true;
        }
      });
      // Update Provider
      if (mounted) {
         context.read<CenterProvider>().updateUnreadCount(0);
      }
    } catch (_) {}
  }

  void _handleAction(Map<String, dynamic> notification) {
    if (notification['is_read'] == false) {
      _markAsRead(notification['id']);
    }

    final data = notification['data'] ?? {};
    final route = data['route'] as String?;
    
    if (route != null && route.isNotEmpty) {
      context.push(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text('الإشعارات', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'تحديد الكل كمقروء',
            onPressed: _markAllAsRead,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? _buildEmptyState(isDark)
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notification = _notifications[index];
                    return _buildNotificationCard(notification, isDark);
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
            Icons.notifications_off_outlined,
            size: 64,
            color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد إشعارات جديدة',
            style: GoogleFonts.cairo(
              fontSize: 18,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'سنخبرك فور حدوث أي شيء مهم',
            style: TextStyle(
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification, bool isDark) {
    final isRead = notification['is_read'] == true;
    final type = notification['type'] ?? 'info';
    final timeAgo = notification['time_ago'] ?? '';
    final priority = notification['priority'] ?? 'normal';

    Color dataColor;
    IconData icon;

    switch (type) {
      case 'warning':
      case 'risk_alert':
        dataColor = Colors.orange;
        icon = Icons.warning_amber_rounded;
        break;
      case 'error':
      case 'debt_alert':
        dataColor = Colors.red;
        icon = Icons.error_outline;
        break;
      case 'success':
      case 'revenue_milestone':
        dataColor = Colors.green;
        icon = Icons.verified_user_outlined;
        break;
      case 'payment':
        dataColor = Colors.blue;
        icon = Icons.payments_outlined;
        break;
      default:
        dataColor = Colors.blue;
        icon = Icons.info_outline;
    }

    if (priority == 'critical') {
      dataColor = Colors.red.shade700;
      icon = Icons.gpp_maybe_outlined;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      color: isRead 
          ? (isDark ? AppColors.darkSurface : Colors.white)
          : (isDark ? AppColors.darkSurfaceVariant : Colors.blue.shade50),
      elevation: isRead ? 1 : 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        side: isRead ? BorderSide.none : BorderSide(color: dataColor.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        onTap: () => _handleAction(notification),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: dataColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: dataColor, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification['title'] ?? '',
                            style: GoogleFonts.cairo(
                              fontSize: 16,
                              fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: dataColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification['body'] ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Footer (Time + Action Hint)
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          timeAgo,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                        const Spacer(),
                        if (notification['data']?['route'] != null)
                          Text(
                            'اضغط للتفاصيل',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: dataColor,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


