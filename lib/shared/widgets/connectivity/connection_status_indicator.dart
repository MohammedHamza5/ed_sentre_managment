import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/offline/network_monitor.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';

/// مؤشر حالة الاتصال بالإنترنت
/// يظهر شريط تنبيه عند فقدان الاتصال
/// ملاحظة: يُفضل استخدام OfflineBanner بدلاً من هذا
class ConnectionStatusIndicator extends StatelessWidget {
  final Widget child;

  const ConnectionStatusIndicator({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkMonitor>(
      builder: (context, network, _) {
        return Column(
          children: [
            // شريط التنبيه عند فقدان الاتصال
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: network.isOnline ? 0 : 36,
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
                        AppColors.warning.withValues(alpha: 0.9),
                        AppColors.warning,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.warning.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.wifi_off_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Text(
                        'لا يوجد اتصال بالإنترنت',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
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


