import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/offline/network_monitor.dart';
import '../../../core/constants/app_spacing.dart';

/// شريط تنبيه Offline
/// يظهر في أعلى الشاشة عند فقدان الاتصال
class OfflineBanner extends StatelessWidget {
  final Widget child;

  const OfflineBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkMonitor>(
      builder: (context, network, _) {
        return Column(
          children: [
            // شريط التنبيه
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              height: network.isOnline ? 0 : 44,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: network.isOnline ? 0 : 1,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.orange.shade600,
                        Colors.orange.shade700,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // أيقونة
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.wifi_off_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      
                      // النص
                      const Text(
                        'أنت غير متصل بالإنترنت - تُعرض البيانات المخزنة',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      
                      const Spacer(),
                      
                      // زر إعادة المحاولة
                      TextButton.icon(
                        onPressed: () => network.checkConnection(),
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        label: const Text(
                          'إعادة المحاولة',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          backgroundColor: Colors.white.withValues(alpha: 0.15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // المحتوى الرئيسي
            Expanded(child: child),
          ],
        );
      },
    );
  }
}

/// مؤشر "بيانات مخزنة"
/// يُستخدم لإظهار أن البيانات من Cache
class CachedDataIndicator extends StatelessWidget {
  final DateTime? cacheTime;
  final VoidCallback? onRefresh;

  const CachedDataIndicator({
    super.key,
    this.cacheTime,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isDark 
            ? Colors.blue.shade900.withValues(alpha: 0.3)
            : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 16,
            color: Colors.blue.shade600,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            cacheTime != null
                ? 'آخر تحديث: ${_formatTime(cacheTime!)}'
                : 'بيانات مخزنة',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue.shade700,
            ),
          ),
          if (onRefresh != null) ...[
            const SizedBox(width: AppSpacing.sm),
            InkWell(
              onTap: onRefresh,
              child: Icon(
                Icons.refresh_rounded,
                size: 16,
                color: Colors.blue.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inMinutes < 1) {
      return 'الآن';
    } else if (diff.inMinutes < 60) {
      return 'منذ ${diff.inMinutes} دقيقة';
    } else if (diff.inHours < 24) {
      return 'منذ ${diff.inHours} ساعة';
    } else {
      return 'منذ ${diff.inDays} يوم';
    }
  }
}


