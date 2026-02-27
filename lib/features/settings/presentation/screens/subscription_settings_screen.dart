import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/providers/center_provider.dart';
import '../../data/repositories/settings_repository.dart';
import '../../../../shared/widgets/cards/stat_card.dart';

class SubscriptionSettingsScreen extends StatefulWidget {
  const SubscriptionSettingsScreen({super.key});

  @override
  State<SubscriptionSettingsScreen> createState() =>
      _SubscriptionSettingsScreenState();
}

class _SubscriptionSettingsScreenState
    extends State<SubscriptionSettingsScreen> {
  bool _isLoading = true;
  int _activeEnrollments = 0;
  int _aiQuestionsAnswered = 0;
  int _aiExamsGenerated = 0;

  @override
  void initState() {
    super.initState();
    _loadBillingData();
  }

  Future<void> _loadBillingData() async {
    try {
      final repository = SettingsRepository();
      final count = await repository.getBillableActiveEnrollmentsCount();
      final aiStats = await repository.getAiUsageStats();

      if (mounted) {
        setState(() {
          _activeEnrollments = count;
          _aiQuestionsAnswered = aiStats['questions'] ?? 0;
          _aiExamsGenerated = aiStats['exams'] ?? aiStats['reports'] ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final centerProvider = context.watch<CenterProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = AppStrings.of(context);

    // Business Logic with Real Data
    final int totalEnrollments = _activeEnrollments;
    final double upcomingBill =
        totalEnrollments * 10.0; // 10 EGP per course enrollment

    // AI Stats
    final int aiQuestionsAnswered = _aiQuestionsAnswered;
    final int aiExamsGenerated = _aiExamsGenerated;

    return _isLoading
        ? const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header (Manual AppBar since we are inside another page)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    strings.isArabic
                        ? 'إدارة الاشتراك والباقة'
                        : 'Subscription Plan',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadBillingData,
                    tooltip: strings.isArabic ? 'تحديث' : 'Refresh',
                  ),
                ],
              ),

              SizedBox(height: AppSpacing.md.h),

              // 1. Current Plan Banner 💎
              _buildPlanBanner(context, isDark, strings),

              SizedBox(height: AppSpacing.xxl.h),

              // 2. Value Delivered Grid (AI Stats) 🤖
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: strings.isArabic
                          ? 'استفسارات AI المجابة'
                          : 'AI Questions Answered',
                      value: '$aiQuestionsAnswered',
                      icon: Icons.psychology_rounded,
                      iconColor: Colors.purple,
                      subtitle: strings.isArabic
                          ? 'وفرت ساعات من وقت المعلمين'
                          : 'Saved hours of teacher time',
                    ),
                  ),
                  SizedBox(width: AppSpacing.md.w),
                  Expanded(
                    child: StatCard(
                      title: strings.isArabic
                          ? 'امتحانات مولدة بالذكاء'
                          : 'AI Exams Generated',
                      value: '$aiExamsGenerated',
                      icon: Icons.quiz_rounded,
                      iconColor: Colors.orange,
                      subtitle: strings.isArabic
                          ? 'تم إنشاؤها تلقائياً'
                          : 'Auto-generated instantly',
                    ),
                  ),
                ],
              ),

              SizedBox(height: AppSpacing.xxl.h),

              // 3. Billing Details Card 💳
              Container(
                padding: EdgeInsets.all(AppSpacing.xl.w),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurface
                      : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          strings.isArabic
                              ? 'فاتورة هذا الشهر (تقديرية)'
                              : 'Current Month Bill (Estimated)',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 6.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusFull,
                            ),
                          ),
                          child: Text(
                            strings.isArabic ? 'نشط' : 'Active',
                            style: TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Divider(
                      height: 32.h,
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                    ),

                    // Line Items
                    _buildBillRow(
                      context,
                      strings.isArabic
                          ? 'إجمالي الاشتراكات النشطة'
                          : 'Active Enrollments',
                      '$totalEnrollments',
                      isBold: false,
                    ),
                    if (totalEnrollments == 0)
                      Padding(
                        padding: EdgeInsets.only(top: 8.h),
                        child: Text(
                          strings.isArabic
                              ? '(الاشتراك النشط = طالب حضر حصة واحدة على الأقل)'
                              : '(Active = Attended at least 1 session)',
                          style: TextStyle(color: Colors.grey, fontSize: 11.sp),
                        ),
                      ),

                    SizedBox(height: AppSpacing.md.h),
                    _buildBillRow(
                      context,
                      strings.isArabic
                          ? 'سعر الخدمة لكل اشتراك'
                          : 'Price per Enrollment',
                      '10 ${strings.currency}',
                      isBold: false,
                    ),

                    Divider(
                      height: 32.h,
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                    ),

                    // Total
                    _buildBillRow(
                      context,
                      strings.isArabic ? 'الإجمالي المستحق' : 'Total Due',
                      '${upcomingBill.toStringAsFixed(0)} ${strings.currency}',
                      isBold: true,
                      isTotal: true,
                    ),

                    SizedBox(height: AppSpacing.xl.h),

                    // Pay Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                strings.isArabic
                                    ? 'سيتم ربط بوابة الدفع قريباً'
                                    : 'Payment Gateway Coming Soon',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.payment_rounded),
                        label: Text(
                          strings.isArabic ? 'دفع الفاتورة' : 'Pay Bill',
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          textStyle: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
  }

  Widget _buildPlanBanner(
    BuildContext context,
    bool isDark,
    AppStrings strings,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSpacing.lg.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF8B5CF6),
            Color(0xFF6D28D9),
          ], // Purple for "Hitech/AI"
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              Icons.auto_awesome, // AI Icon
              size: 120.sp,
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text(
                  strings.isArabic ? 'النسخة الكاملة' : 'Full Version',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                strings.isArabic
                    ? 'مدعوم بالذكاء الاصطناعي 🧠'
                    : 'Powered by AI 🧠',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                strings.isArabic
                    ? 'جميع ميزات المساعد الذكي مفعلة لجميع المدرسين والطلاب'
                    : 'All AI Assistant features are active for everyone',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13.sp,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBillRow(
    BuildContext context,
    String label,
    String value, {
    bool isBold = false,
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isTotal ? 18.sp : 14.sp,
            color: isTotal ? AppColors.primary : null,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            fontSize: isTotal ? 20.sp : 14.sp,
            color: isTotal ? AppColors.primary : null,
          ),
        ),
      ],
    );
  }
}


