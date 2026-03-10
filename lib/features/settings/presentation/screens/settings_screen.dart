import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/providers/center_provider.dart';
import '../../../../core/supabase/supabase_client.dart';
import 'package:ed_sentre/features/settings/presentation/screens/subscription_settings_screen.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/supabase/supabase_config.dart';
import '../../../../core/services/backup_service.dart';
import '../widgets/roles_management_widget.dart';
import '../widgets/team_management_widget.dart';
import '../widgets/access_card_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../shared/models/billing_models.dart';
import '../../../../core/offline/local_cache_service.dart';

/// شاشة الإعدادات
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedSection = 0;
  bool _hasChanges = false;

  // Form Controllers
  final _centerNameController = TextEditingController(text: '');
  final _addressController = TextEditingController(text: '');
  final _phoneController = TextEditingController(text: '');
  final _emailController = TextEditingController(text: '');
  final _licenseController = TextEditingController(text: '');

  bool _emailNotifications = true;
  bool _smsNotifications = true;
  bool _autoBackup = true;
  bool _isLoading = false;
  int _usersRefreshKey = 0;

  List<Map<String, dynamic>> _getSections(AppStrings strings) => [
    // General
    {
      'id': 'center',
      'title': strings.centerInfo,
      'icon': Icons.business,
      'group': 'عام',
    },
    {
      'id': 'billing',
      'title': 'نظام الدفع',
      'icon': Icons.payment,
      'group': 'عام',
    },
    {
      'id': 'prices',
      'title': '💰 جدول الأسعار',
      'icon': Icons.price_change,
      'group': 'عام',
    },
    {
      'id': 'appearance',
      'title': strings.appearance,
      'icon': Icons.palette,
      'group': 'عام',
    },

    // Administration
    {
      'id': 'subscription',
      'title': strings.isArabic ? 'إدارة الاشتراك والباقة' : 'Subscription',
      'icon': Icons.diamond_outlined, // Premium icon
      'group': 'الإدارة',
    },
    {
      'id': 'team',
      'title': 'إدارة الفريق',
      'icon': Icons.groups,
      'group': 'الإدارة',
    },

    // System
    {
      'id': 'notifications',

      'title': strings.notifications,
      'icon': Icons.notifications_active,
      'group': 'النظام',
    },
    {
      'id': 'backup',
      'title': strings.backup,
      'icon': Icons.cloud_sync,
      'group': 'النظام',
    },
    {
      'id': 'security',
      'title': strings.security,
      'icon': Icons.security,
      'group': 'النظام',
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFromProvider();
    });
  }

  void _initializeFromProvider() {
    final centerProvider = context.read<CenterProvider>();
    if (centerProvider.hasCenter) {
      _centerNameController.text = centerProvider.centerName;
      _addressController.text = centerProvider.centerAddress;
      _phoneController.text = centerProvider.centerPhone;
      _emailController.text = centerProvider.centerEmail;
      _licenseController.text = centerProvider.licenseNumber;
    }
  }

  @override
  void dispose() {
    _centerNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final padding = EdgeInsets.all(AppSpacing.pagePadding.w);
    final isMobile = ResponsiveUtils.isMobile(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final strings = AppStrings.of(context);
    final sections = _getSections(strings);

    return Stack(
      children: [
        SingleChildScrollView(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    strings.settingsTitle,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_hasChanges)
                    AppButton(
                      text: strings.saveChanges,
                      icon: Icons.save,
                      onPressed: _isLoading
                          ? null
                          : () => _saveSettings(strings),
                      isLoading: _isLoading,
                    ),
                ],
              ),
              SizedBox(height: AppSpacing.xxl.h),

              // Content
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sidebar
                  if (!isMobile)
                    Container(
                      width: 220.w,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurface
                            : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusLg,
                        ),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
                      ),
                      child: Column(
                        children: [
                          for (
                            int index = 0;
                            index < sections.length;
                            index++
                          ) ...[
                            if (index == 0 ||
                                sections[index]['group'] !=
                                    sections[index - 1]['group'])
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  24,
                                  16,
                                  8,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      sections[index]['group'],
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            InkWell(
                              onTap: () =>
                                  setState(() => _selectedSection = index),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: _selectedSection == index
                                      ? AppColors.primarySurface
                                      : null,
                                  border: Border(
                                    right: BorderSide(
                                      color: _selectedSection == index
                                          ? AppColors.primary
                                          : Colors.transparent,
                                      width: 3,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      sections[index]['icon'],
                                      size: 20,
                                      color: _selectedSection == index
                                          ? AppColors.primary
                                          : (isDark
                                                ? AppColors.darkTextSecondary
                                                : AppColors.lightTextSecondary),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      sections[index]['title'],
                                      style: TextStyle(
                                        fontWeight: _selectedSection == index
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: _selectedSection == index
                                            ? AppColors.primary
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                  if (!isMobile) SizedBox(width: AppSpacing.xl.w),

                  // Content Area
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(AppSpacing.xl.w),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurface
                            : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusLg,
                        ),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
                      ),
                      child: _buildSectionContent(
                        isDark,
                        settingsProvider,
                        strings,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Loader Overlay
        if (_isLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.5),
            child: Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(24.0.w),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16.h),
                      Text('جاري المعالجة... يرجى الانتظار'),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSectionContent(
    bool isDark,
    SettingsProvider settings,
    AppStrings strings,
  ) {
    switch (_selectedSection) {
      // General
      case 0: // معلومات السنتر
        return _buildCenterInfoSection(isDark, strings);
      case 1: // نظام الدفع
        return _buildBillingSection(isDark, strings);
      case 2: // جدول الأسعار
        return _buildPricesSection(isDark, strings);
      case 3: // المظهر
        return _buildAppearanceSection(isDark, settings, strings);

      // Administration
      case 4: // إدارة الاشتراك
        return const SubscriptionSettingsScreen();
      case 5: // إدارة الفريق (المستخدمين + الأدوار)
        return TeamManagementWidget(isDark: isDark);

      // System
      // System
      case 6: // الإشعارات
        return _buildNotificationsSection(isDark, strings);
      case 7: // النسخ الاحتياطي
        return _buildBackupSection(isDark, strings);
      case 8: // الأمان
        return _buildSecuritySection(isDark, strings);
      default:
        return const SizedBox();
    }
  }

  Widget _buildRolesSection(bool isDark, AppStrings strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الأدوار والصلاحيات',
          style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: AppSpacing.xl.h),
        RolesManagementWidget(isDark: isDark),
      ],
    );
  }

  Widget _buildCenterInfoSection(bool isDark, AppStrings strings) {
    return Consumer<CenterProvider>(
      builder: (context, centerProvider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.centerInfo,
              style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: AppSpacing.xl.h),

            // Subscription Info Card (Removed as per user request)
            /*
            if (centerProvider.hasCenter)
              Card(...)
            */
            SizedBox(height: AppSpacing.xl.h),

            // نظام التسعير متاح في قسم "جدول الأسعار" و "نظام الدفع"
            _buildTextField(
              strings.centerName,
              _centerNameController,
              Icons.business,
            ),
            SizedBox(height: AppSpacing.lg.h),
            _buildTextField(
              strings.address,
              _addressController,
              Icons.location_on,
            ),
            SizedBox(height: AppSpacing.lg.h),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    strings.phone,
                    _phoneController,
                    Icons.phone,
                  ),
                ),
                SizedBox(width: AppSpacing.lg.w),
                Expanded(
                  child: _buildTextField(
                    strings.email,
                    _emailController,
                    Icons.email,
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.lg.h),
            _buildTextField(
              strings.licenseNumber,
              _licenseController,
              Icons.badge,
            ),
          ],
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Billing Section - قسم نظام الدفع
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildBillingSection(bool isDark, AppStrings strings) {
    return Consumer<CenterProvider>(
      builder: (context, centerProvider, child) {
        final config = centerProvider.billingConfig;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'نظام الدفع',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'اختر نظام الدفع المناسب لمركزك',
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.grey[600],
                fontSize: 14.sp,
              ),
            ),
            SizedBox(height: AppSpacing.xl.h),

            // نوع الدفع الأساسي
            Card(
              color: isDark
                  ? AppColors.darkSurfaceVariant
                  : AppColors.lightSurfaceVariant,
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.payment, color: AppColors.primary),
                        SizedBox(width: 8.w),
                        Text(
                          'نوع الدفع الأساسي',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16.sp,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppSpacing.lg.h),

                    // اختيارات نوع الدفع
                    Wrap(
                      spacing: 12.w,
                      runSpacing: 12.h,
                      children: [
                        _buildBillingTypeChip(
                          'شهري',
                          'اشتراك شهري ثابت',
                          Icons.calendar_month,
                          config.billingType == BillingType.monthly,
                          () => _updateBillingType(BillingType.monthly),
                          isDark,
                        ),
                        _buildBillingTypeChip(
                          'بالحصة',
                          'الدفع لكل حصة',
                          Icons.timelapse,
                          config.billingType == BillingType.perSession,
                          () => _updateBillingType(BillingType.perSession),
                          isDark,
                        ),
                        _buildBillingTypeChip(
                          'مختلط',
                          'كل مجموعة بنظامها',
                          Icons.shuffle,
                          config.billingType == BillingType.mixed,
                          () => _updateBillingType(BillingType.mixed),
                          isDark,
                        ),
                        _buildBillingTypeChip(
                          'معطّل',
                          'بدون نظام دفع',
                          Icons.money_off,
                          config.billingType == BillingType.disabled,
                          () => _updateBillingType(BillingType.disabled),
                          isDark,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: AppSpacing.lg.h),

            // إعدادات إضافية للنظام الشهري
            if (config.billingType == BillingType.monthly ||
                config.billingType == BillingType.mixed)
              Card(
                color: isDark
                    ? AppColors.darkSurfaceVariant
                    : AppColors.lightSurfaceVariant,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_today, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(
                            'نوع الحساب الشهري',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16.sp,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppSpacing.md.h),

                      RadioListTile<MonthlyPaymentMode>(
                        title: const Text('كل شهر كامل (30 يوم)'),
                        subtitle: const Text(
                          'الطالب يدفع كل شهر بغض النظر عن عدد الحصص',
                        ),
                        value: MonthlyPaymentMode.calendarMonth,
                        groupValue: config.monthlyPaymentMode,
                        onChanged: (val) => _updateMonthlyMode(val!),
                      ),
                      RadioListTile<MonthlyPaymentMode>(
                        title: Text('كل ${config.sessionsPerCycle} حصص'),
                        subtitle: const Text(
                          'الطالب يدفع عند إكمال عدد معين من الحصص',
                        ),
                        value: MonthlyPaymentMode.sessionCount,
                        groupValue: config.monthlyPaymentMode,
                        onChanged: (val) => _updateMonthlyMode(val!),
                      ),

                      if (config.monthlyPaymentMode ==
                          MonthlyPaymentMode.sessionCount)
                        Padding(
                          padding: EdgeInsets.only(right: 48.w, top: 8.h),
                          child: Row(
                            children: [
                              const Text('عدد الحصص: '),
                              SizedBox(width: 12.w),
                              DropdownButton<int>(
                                value: config.sessionsPerCycle,
                                items: [4, 6, 8, 10, 12]
                                    .map(
                                      (n) => DropdownMenuItem(
                                        value: n,
                                        child: Text('$n حصص'),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) =>
                                    _updateSessionsPerCycle(val!),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.lg),

            // إعدادات المهلة والدين
            Card(
              color: isDark
                  ? AppColors.darkSurfaceVariant
                  : AppColors.lightSurfaceVariant,
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.timer, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text(
                          'إعدادات المهلة والدين',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16.sp,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppSpacing.lg.h),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('مهلة الحصص المجانية'),
                              Text(
                                'عدد الحصص المسموحة بدون دفع قبل التحذير',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButton<int>(
                                value: config.graceSessions,
                                items: [1, 2, 3, 4, 5]
                                    .map(
                                      (n) => DropdownMenuItem(
                                        value: n,
                                        child: Text('$n حصص'),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) => _updateGraceSessions(val!),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: AppSpacing.xl.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('الحد الأقصى للدين'),
                              Text(
                                'عدد الحصص قبل منع الحضور',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButton<int>(
                                value: config.maxDebtSessions,
                                items: [2, 3, 4, 5, 6, 8, 10]
                                    .map(
                                      (n) => DropdownMenuItem(
                                        value: n,
                                        child: Text('$n حصص'),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) =>
                                    _updateMaxDebtSessions(val!),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: AppSpacing.xl.h),

            // معلومات النظام الحالي
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.primary),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'النظام الحالي: ${config.billingTypeArabic}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        if (config.isMonthly)
                          Text(
                            config.monthlyModeArabic,
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: AppColors.primary,
                            ),
                          ),
                        Text(
                          'المهلة: ${config.graceSessions} حصص | الحد الأقصى للدين: ${config.maxDebtSessions} حصص',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Prices Section - قسم جدول الأسعار
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPricesSection(bool isDark, AppStrings strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.price_change, color: Colors.green, size: 28.sp),
            SizedBox(width: 12.w),
            Text(
              'جدول الأسعار',
              style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () {
                context.pushNamed('coursePrices');
              },
              icon: Icon(Icons.open_in_new, size: 18.sp),
              label: const Text('فتح الشاشة الكاملة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'حدد أسعار المواد حسب المدرس والمرحلة الدراسية',
          style: TextStyle(color: Colors.grey[600]),
        ),
        const SizedBox(height: AppSpacing.xl),

        // شرح النظام
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.green.withValues(alpha: 0.1),
                Colors.teal.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.lightbulb, color: Colors.amber),
                  const SizedBox(width: 8),
                  Text(
                    'كيف يعمل نظام التسعير الذكي؟',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildPriceFeature('🎯', 'السعر = المادة + المدرس + المرحلة'),
              _buildPriceFeature('📊', 'كل مدرس يمكن أن يكون بسعر مختلف'),
              _buildPriceFeature(
                '📚',
                'كل مرحلة دراسية يمكن أن تكون بسعر مختلف',
              ),
              _buildPriceFeature('⚡', 'النظام يبحث تلقائياً عن أنسب سعر'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // مثال
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '📋 مثال:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Table(
                border: TableBorder.all(
                  color: Colors.grey.withValues(alpha: 0.3),
                ),
                children: [
                  const TableRow(
                    decoration: BoxDecoration(color: Color(0x1010B981)),
                    children: [
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          'المادة',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          'المدرس',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          'المرحلة',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          'الحصة',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  _buildExampleRow('رياضيات', 'أ/ محمد', 'ثالثة ثانوي', '70 ج'),
                  _buildExampleRow('رياضيات', 'أ/ محمد', 'ثانية ثانوي', '60 ج'),
                  _buildExampleRow('رياضيات', 'أ/ أحمد', 'ثالثة ثانوي', '80 ج'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriceFeature(String emoji, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }

  TableRow _buildExampleRow(
    String subject,
    String teacher,
    String grade,
    String price,
  ) {
    return TableRow(
      children: [
        Padding(padding: EdgeInsets.all(8.w), child: Text(subject)),
        Padding(padding: EdgeInsets.all(8.w), child: Text(teacher)),
        Padding(padding: EdgeInsets.all(8.w), child: Text(grade)),
        Padding(
          padding: EdgeInsets.all(8.w),
          child: Text(
            price,
            style: const TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBillingTypeChip(
    String label,
    String subtitle,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
    bool isDark,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? Colors.white70 : Colors.grey[600]),
              size: 28.sp,
            ),
            SizedBox(height: 8.h),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primary : null,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11.sp,
                color: isDark ? Colors.white60 : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateBillingType(BillingType type) async {
    final centerProvider = context.read<CenterProvider>();
    final currentType = centerProvider.billingConfig.billingType;

    // إذا كان نفس النوع، لا تفعل شيء
    if (currentType == type) return;

    // إظهار Dialog تحذيري قوي
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
          side: BorderSide(color: Colors.red.shade400, width: 3),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: Colors.red.shade700,
                size: 32.sp,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                '⚠️ تحذير هام جداً!',
                style: TextStyle(
                  color: Colors.red.shade800,
                  fontWeight: FontWeight.bold,
                  fontSize: 22.sp,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.swap_horiz,
                    color: Colors.red.shade700,
                    size: 28.sp,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      'تغيير من "${centerProvider.billingConfig.billingTypeArabic}" إلى "${_getBillingTypeArabic(type)}"',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade800,
                        fontSize: 16.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'هذا التغيير سيؤثر على:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),
            _buildWarningItem('👨‍🎓', 'جميع الطلاب المسجلين حالياً'),
            _buildWarningItem('💰', 'طريقة حساب المدفوعات'),
            _buildWarningItem('👨‍🏫', 'حسابات رواتب المعلمين'),
            _buildWarningItem('📊', 'كل التقارير المالية'),
            _buildWarningItem('📋', 'سجلات الحضور والغياب'),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'سيتم إعادة تعيين حالة الدفع لجميع الطلاب',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'هل أنت متأكد من هذا التغيير؟',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.grey.shade900,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'إلغاء',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check_circle),
            label: const Text(
              'نعم، غيّر النظام',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // تنفيذ التغيير
    final newConfig = centerProvider.billingConfig.copyWith(billingType: type);
    final success = await centerProvider.updateBillingConfig(newConfig);
    if (mounted && success) {
      // ⚡ إعادة بناء الـ UI لعرض النظام الجديد
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text('تم تغيير نظام الدفع إلى: ${newConfig.billingTypeArabic}'),
            ],
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Widget _buildWarningItem(String emoji, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Text(emoji, style: TextStyle(fontSize: 18.sp)),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 14.sp)),
          ),
        ],
      ),
    );
  }

  String _getBillingTypeArabic(BillingType type) {
    switch (type) {
      case BillingType.monthly:
        return 'شهري';
      case BillingType.perSession:
        return 'بالحصة';
      case BillingType.mixed:
        return 'مختلط';
      case BillingType.disabled:
        return 'معطّل';
    }
  }

  Future<void> _updateMonthlyMode(MonthlyPaymentMode mode) async {
    final centerProvider = context.read<CenterProvider>();
    final newConfig = centerProvider.billingConfig.copyWith(
      monthlyPaymentMode: mode,
    );
    await centerProvider.updateBillingConfig(newConfig);
  }

  Future<void> _updateSessionsPerCycle(int count) async {
    final centerProvider = context.read<CenterProvider>();
    final newConfig = centerProvider.billingConfig.copyWith(
      sessionsPerCycle: count,
    );
    await centerProvider.updateBillingConfig(newConfig);
  }

  Future<void> _updateGraceSessions(int count) async {
    final centerProvider = context.read<CenterProvider>();
    final newConfig = centerProvider.billingConfig.copyWith(
      graceSessions: count,
    );
    await centerProvider.updateBillingConfig(newConfig);
  }

  Future<void> _updateMaxDebtSessions(int count) async {
    final centerProvider = context.read<CenterProvider>();
    final newConfig = centerProvider.billingConfig.copyWith(
      maxDebtSessions: count,
    );
    await centerProvider.updateBillingConfig(newConfig);
  }

  Widget _buildInfoRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.lightTextSecondary),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            ),
            child: Text(
              value,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceSection(
    bool isDark,
    SettingsProvider settings,
    AppStrings strings,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.appearance,
          style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppSpacing.xl),
        _buildSwitchTile(
          strings.darkMode,
          strings.enableDarkMode,
          Icons.dark_mode,
          settings.isDarkMode,
          isDark,
          (v) {
            settings.toggleTheme(v);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  v ? strings.darkModeEnabled : strings.lightModeEnabled,
                ),
                backgroundColor: AppColors.success,
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        _buildDropdownTile(
          strings.language,
          strings.appLanguage,
          Icons.language,
          settings.locale.languageCode,
          [
            {'value': 'ar', 'label': strings.arabic},
            {'value': 'en', 'label': strings.english},
          ],
          isDark,
          (v) {
            if (v != null) {
              settings.setLocale(v);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    v == 'ar'
                        ? strings.languageChangedToArabic
                        : strings.languageChangedToEnglish,
                  ),
                  backgroundColor: AppColors.success,
                ),
              );
            }
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        _buildDropdownTile(
          strings.currency,
          strings.defaultCurrency,
          Icons.attach_money,
          settings.currency,
          [
            {'value': 'EGP', 'label': strings.egp},
            {'value': 'SAR', 'label': strings.sar},
            {'value': 'USD', 'label': strings.usd},
          ],
          isDark,
          (v) {
            if (v != null) {
              settings.setCurrency(v);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(strings.currencyChanged),
                  backgroundColor: AppColors.success,
                ),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildNotificationsSection(bool isDark, AppStrings strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.notifications,
          style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppSpacing.xl),
        _buildSwitchTile(
          strings.emailNotifications,
          'تلقي إشعارات عبر البريد الإلكتروني',
          Icons.email,
          _emailNotifications,
          isDark,
          (v) {
            setState(() {
              _emailNotifications = v;
            });
            _saveNotificationSettings();
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        _buildSwitchTile(
          strings.smsNotifications,
          'تلقي رسائل نصية SMS',
          Icons.sms,
          _smsNotifications,
          isDark,
          (v) {
            setState(() {
              _smsNotifications = v;
            });
            _saveNotificationSettings();
          },
        ),
      ],
    );
  }

  Widget _buildBackupSection(bool isDark, AppStrings strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.backup,
          style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppSpacing.xl),
        _buildSwitchTile(
          strings.autoBackup,
          'نسخ احتياطي تلقائي يومي',
          Icons.backup,
          _autoBackup,
          isDark,
          (v) {
            setState(() {
              _autoBackup = v;
            });
          },
        ),
        const SizedBox(height: AppSpacing.xl),
        Wrap(
          spacing: AppSpacing.lg.w,
          runSpacing: AppSpacing.lg.h,
          children: [
            ElevatedButton.icon(
              onPressed: _performBackup,
              icon: const Icon(Icons.backup),
              label: Text(strings.createBackup),
            ),
            OutlinedButton.icon(
              onPressed: _showRestoreDialog,
              icon: const Icon(Icons.restore),
              label: Text(strings.restoreBackup),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUsersSection(bool isDark, AppStrings strings) {
    return _UsersListWidget(
      key: ValueKey(_usersRefreshKey),
      isDark: isDark,
      strings: strings,
    );
  }

  Widget _buildSecuritySection(bool isDark, AppStrings strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.security,
          style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppSpacing.xl),

        ListTile(
          leading: const Icon(Icons.lock, color: AppColors.primary),
          title: const Text('تغيير كلمة المرور'),
          subtitle: const Text('تحديث كلمة مرور حسابك'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showChangePasswordDialog(strings),
        ),
        const Divider(),

        ListTile(
          leading: const Icon(Icons.logout, color: AppColors.error),
          title: const Text(
            'تسجيل الخروج',
            style: TextStyle(color: AppColors.error),
          ),
          subtitle: const Text('الخروج من حسابك'),
          onTap: _logout,
        ),

        const SizedBox(height: AppSpacing.xxl),
        Text(
          "المنطقة الخطرة",
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.error,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildDangerZoneCard(context, isDark, strings),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      onChanged: (_) => setState(() => _hasChanges = true),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    bool isDark,
    Function(bool) onChanged,
  ) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md.w),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceVariant
            : AppColors.lightSurfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildDropdownTile(
    String title,
    String subtitle,
    IconData icon,
    String value,
    List<Map<String, String>> options,
    bool isDark,
    Function(String?) onChanged,
  ) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md.w),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceVariant
            : AppColors.lightSurfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
              ],
            ),
          ),
          DropdownButton<String>(
            value: value,
            underline: const SizedBox(),
            items: options
                .map(
                  (o) => DropdownMenuItem(
                    value: o['value'],
                    child: Text(o['label']!),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Future<void> _saveSettings(AppStrings strings) async {
    setState(() => _isLoading = true);

    try {
      final centerProvider = context.read<CenterProvider>();

      final success = await centerProvider.updateCenterInfo(
        name: _centerNameController.text.trim(),
        address: _addressController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        licenseNumber: _licenseController.text.trim(),
      );

      if (!mounted) return;

      if (success) {
        setState(() => _hasChanges = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(strings.settingsSaved),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('فشل حفظ التغييرات'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showChangePasswordDialog(AppStrings strings) async {
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تغيير كلمة المرور'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'كلمة المرور الجديدة',
                ),
                validator: (v) => (v != null && v.length >= 6)
                    ? null
                    : 'يجب أن تكون 6 أحرف على الأقل',
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'تأكيد كلمة المرور',
                ),
                validator: (v) => v == passwordController.text
                    ? null
                    : 'كلمات المرور غير متطابقة',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(strings.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                try {
                  await SupabaseClientManager.client.auth.updateUser(
                    UserAttributes(password: passwordController.text),
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم تغيير كلمة المرور بنجاح'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('فشل تغيير كلمة المرور: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              }
            },
            child: Text(strings.save),
          ),
        ],
      ),
    );
  }

  Future<void> _saveNotificationSettings() async {
    await Provider.of<SettingsProvider>(
      context,
      listen: false,
    ).setNotificationSettings(
      email: _emailNotifications,
      sms: _smsNotifications,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ إعدادات الإشعارات'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await SupabaseClientManager.client.auth.signOut();
        if (mounted) {
          context.read<CenterProvider>().clear();
          context.go('/login');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('فشل تسجيل الخروج: $e')));
        }
      }
    }
  }

  Future<void> _performBackup() async {
    setState(() => _isLoading = true);

    // No showDialog here - _isLoading triggers overlay

    try {
      final centerId = context.read<CenterProvider>().centerId;
      if (centerId == null) throw Exception('Center ID not found');

      final filePath = await BackupService().exportData(centerId: centerId);

      if (mounted) {
        setState(() => _isLoading = false);

        // Show Success & Share Dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.success),
                SizedBox(width: 8),
                Text('تم النسخ الاحتياطي بنجاح'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('تم حفظ ملف النسخة الاحتياطية في الجهاز.'),
                const SizedBox(height: 8),
                Text(
                  filePath,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إغلاق'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  BackupService().shareBackupFile(filePath);
                },
                icon: const Icon(Icons.share),
                label: const Text('مشاركة الملف'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل النسخ الاحتياطي: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _showRestoreDialog() async {
    // 1. Pick File
    final filePath = await BackupService().pickBackupFile();

    if (filePath == null) return; // Cancelled

    if (!mounted) return;

    // 2. Confirm Restore
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('استعادة البيانات ⚠️'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'هل أنت متأكد من استعادة البيانات من هذا الملف؟',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'سيؤدي هذا إلى استبدال البيانات الحالية بالبيانات الموجودة في الملف. لا يمكن التراجع عن هذه العملية.',
              style: TextStyle(color: Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performRestore(filePath);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('استعادة (تحديث البيانات)'),
          ),
        ],
      ),
    );
  }

  Future<void> _performRestore(String filePath) async {
    setState(() => _isLoading = true);
    // No showDialog - overlay active

    try {
      await BackupService().restoreData(filePath);

      if (mounted) {
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم استعادة البيانات بنجاح!'),
            backgroundColor: AppColors.success,
          ),
        );

        // Refresh entire app state if possible
        // For now, at least refresh users list
        _usersRefreshKey++;
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في الاستعادة: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildDangerZoneCard(
    BuildContext context,
    bool isDark,
    AppStrings strings,
  ) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md.w),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg.r),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(
              Icons.delete_forever_rounded,
              color: AppColors.error,
            ),
            title: Text(
              "مسح بيانات التطبيق المخزنة",
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
                fontSize: 16.sp,
              ),
            ),
            subtitle: Text(
              "سيقوم هذا بتسجيل الخروج ومسح كافة الإعدادات والبيانات المؤقتة من هذا الجهاز.",
              style: TextStyle(fontSize: 12.sp),
            ),
            trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              onPressed: () => _confirmAppReset(context),
              child: const Text("مسح وإعادة ضبط"),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAppReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ تحذير: إعادة ضبط التطبيق'),
        content: const Text(
          'هل أنت متأكد أنك تريد مسح كافة البيانات المخزنة محلياً؟\n\n'
          'سيؤدي هذا إلى:\n'
          '1. تسجيل الخروج من حسابك.\n'
          '2. مسح إعدادات التطبيق (السمة، اللغة، إلخ).\n'
          '3. مسح البيانات المؤقتة (Cache).\n\n'
          'لن يتم حذف بياناتك المحفوظة على السحابة (Supabase).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('نعم، امسح كل شيء'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _handleAppReset();
    }
  }

  Future<void> _handleAppReset() async {
    setState(() => _isLoading = true);

    try {
      // 1. Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      debugPrint('✅ SharedPreferences cleared');

      // 2. Delete SQLite Database (Drift)
      try {
        final dbFolder = await getApplicationDocumentsDirectory();

        // Potential DB filenames
        final filesToDelete = ['ed_sentre.sqlite', 'db.sqlite'];

        for (final fileName in filesToDelete) {
          final file = File(p.join(dbFolder.path, fileName));
          if (await file.exists()) {
            await file.delete();
            debugPrint('✅ Deleted database file: $fileName');
          }
        }
      } catch (e) {
        debugPrint('⚠️ Failed to delete database files: $e');
      }

      // 3. Sign Out from Supabase
      try {
        await SupabaseClientManager.client.auth.signOut();
        debugPrint('✅ Supabase signed out');
      } catch (e) {
        debugPrint('⚠️ Supabase signout error (ignored): $e');
      }

      // 4. Clear CachingRepository in-memory cache (TODO: Implement CachingRepository)
      // This cache clearing is handled by LocalCacheService below
      debugPrint('ℹ️ CachingRepository not implemented yet, skipping...');

      // 5. Clear LocalCacheService (disk cache including center_id)
      try {
        await LocalCacheService().clearAll();
        debugPrint('✅ LocalCacheService cleared');
      } catch (e) {
        debugPrint('⚠️ LocalCacheService clear error (ignored): $e');
      }

      // 6. Clear CenterProvider state
      try {
        context.read<CenterProvider>().clear();
        debugPrint('✅ CenterProvider cleared');
      } catch (e) {
        debugPrint('⚠️ CenterProvider clear error (ignored): $e');
      }

      if (mounted) {
        // Force hard navigation to ensure providers are reset if possible
        // Ideally, we should restart the app, but navigation to login is the standard "soft" reset.
        context.go('/login');

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تمت إعادة ضبط التطبيق بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ App Reset Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء إعادة الضبط: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

class _UsersListWidget extends StatefulWidget {
  final bool isDark;
  final AppStrings strings;

  const _UsersListWidget({
    super.key,
    required this.isDark,
    required this.strings,
  });

  @override
  State<_UsersListWidget> createState() => _UsersListWidgetState();
}

class _UsersListWidgetState extends State<_UsersListWidget> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    debugPrint('🔘 SettingsScreen (Users): _fetchUsers called');
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final centerProvider = context.read<CenterProvider>();
      final centerId = centerProvider.centerId;

      debugPrint('🔘 SettingsScreen (Users): Center ID: $centerId');

      if (centerId == null || centerId.isEmpty) {
        debugPrint('🔴 SettingsScreen (Users): Center ID is null!');
        throw Exception('السنتر غير معرف');
      }

      debugPrint(
        '🔘 SettingsScreen (Users): querying users for centerId: $centerId',
      );

      final response = await SupabaseClientManager.client
          .from('users')
          .select('id, full_name, email, phone, role, is_active')
          .eq('default_center_id', centerId)
          .neq('role', 'teacher')
          .neq('role', 'student')
          .order('created_at', ascending: false);

      debugPrint(
        '🟢 SettingsScreen (Users): Query successful. Records: ${response.length}',
      );

      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('🔴 SettingsScreen (Users): Error: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addUser() async {
    debugPrint('🔘 SettingsScreen (Users): _addUser dialog requested');
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    String role = 'center_admin';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة مستخدم جديد'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'الاسم الكامل'),
                  validator: (v) => v == null || v.isEmpty ? 'مطلوب' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'مطلوب';
                    if (v.length < 10) return 'رقم هاتف غير صحيح';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                DropdownButtonFormField<String>(
                  value: role,
                  decoration: const InputDecoration(labelText: 'الدور'),
                  items: const [
                    DropdownMenuItem(
                      value: 'center_admin',
                      child: Text('مدير مركز (Full Access)'),
                    ),
                    DropdownMenuItem(
                      value: 'reception',
                      child: Text('استقبال (Reception)'),
                    ),
                    DropdownMenuItem(
                      value: 'accountant',
                      child: Text('محاسب (Accountant)'),
                    ),
                    DropdownMenuItem(
                      value: 'supervisor',
                      child: Text('مشرف (Supervisor)'),
                    ),
                  ],
                  onChanged: (v) => role = v!,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);

                try {
                  setState(() => _isLoading = true);

                  final centerProvider = context.read<CenterProvider>();
                  final centerId = centerProvider.centerId;

                  if (centerId == null || centerId.isEmpty) {
                    throw Exception('No center ID found');
                  }

                  // 1. Generate Smart Credentials
                  final phone = phoneController.text.trim();
                  final cleanPhone = phone.replaceAll(
                    RegExp(r'\D'),
                    '',
                  ); // Numbers only
                  final smartEmail = '$cleanPhone@edsentre.local';
                  final tempPassword =
                      'Ed${cleanPhone.substring(cleanPhone.length - 4)}${DateTime.now().millisecond}'; // e.g., Ed5678123

                  debugPrint(
                    '🔐 ══════════════════════════════════════════════',
                  );
                  debugPrint('🔐 [AddUser] Starting user creation...');
                  debugPrint('🔐 [AddUser] Smart Email: $smartEmail');
                  debugPrint('🔐 [AddUser] Target Center ID: $centerId');
                  debugPrint(
                    '🔐 [AddUser] Current Admin UID: ${SupabaseClientManager.client.auth.currentUser?.id}',
                  );
                  debugPrint(
                    '🔐 ══════════════════════════════════════════════',
                  );

                  // 2. Create User using Temporary Client (to avoid logging out Admin)
                  debugPrint(
                    '🔐 [AddUser] Step 1: Creating temp Supabase client...',
                  );
                  final tempClient = SupabaseClient(
                    SupabaseConfig.url,
                    SupabaseConfig.anonKey,
                    authOptions: const FlutterAuthClientOptions(
                      authFlowType: AuthFlowType.implicit,
                    ), // Don't persist session
                  );

                  debugPrint('🔐 [AddUser] Step 2: Calling signUp...');
                  final authResponse = await tempClient.auth.signUp(
                    email: smartEmail,
                    password: tempPassword,
                    data: {
                      'full_name': nameController.text.trim(),
                      'role': role,
                      'center_id': centerId,
                      'phone': phone,
                    },
                  );

                  if (authResponse.user == null) {
                    debugPrint(
                      '🔴 [AddUser] Step 2 FAILED: authResponse.user is null',
                    );
                    throw Exception('Auth creation failed');
                  }

                  debugPrint('🟢 [AddUser] Step 2 SUCCESS: Auth user created');
                  debugPrint(
                    '🔐 [AddUser] New User ID: ${authResponse.user!.id}',
                  );
                  debugPrint(
                    '🔐 [AddUser] Admin UID (should be unchanged): ${SupabaseClientManager.client.auth.currentUser?.id}',
                  );

                  // 3. Upsert into public.users via RPC (bypasses RLS)
                  debugPrint(
                    '🔐 [AddUser] Step 3: Calling admin_upsert_user RPC...',
                  );
                  debugPrint('🔐 [AddUser] RPC params:');
                  debugPrint('   - p_user_id: ${authResponse.user!.id}');
                  debugPrint('   - p_full_name: ${nameController.text.trim()}');
                  debugPrint('   - p_phone: $phone');
                  debugPrint('   - p_role: $role');
                  debugPrint('   - p_center_id: $centerId');

                  try {
                    await SupabaseClientManager.client.rpc(
                      'admin_upsert_user',
                      params: {
                        'p_user_id': authResponse.user!.id,
                        'p_full_name': nameController.text.trim(),
                        'p_phone': phone,
                        'p_role': role,
                        'p_center_id': centerId,
                      },
                    );
                    debugPrint(
                      '🟢 [AddUser] Step 3 SUCCESS: User inserted via RPC',
                    );
                  } catch (rpcError) {
                    debugPrint('🔴 [AddUser] Step 3 FAILED (RPC): $rpcError');
                    rethrow;
                  }

                  debugPrint('🟢 User created successfully');
                  debugPrint(
                    '🔐 ══════════════════════════════════════════════',
                  );

                  // Save values before Navigator.pop closes dialog
                  final savedName = nameController.text.trim();
                  final savedPhone = phone;
                  final savedPassword = tempPassword;
                  final savedRole = role;

                  // Close the add user dialog first
                  if (mounted) Navigator.of(context).pop();

                  // Refresh users list
                  _fetchUsers();

                  // Show Access Card Dialog (use root navigator context)
                  if (mounted) {
                    await Future.delayed(const Duration(milliseconds: 100));
                    if (mounted) {
                      showDialog(
                        context: this.context, // Use widget's context
                        barrierDismissible: false,
                        builder: (dialogContext) => AccessCardDialog(
                          userName: savedName,
                          phoneNumber: savedPhone,
                          password: savedPassword,
                          role: savedRole,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  debugPrint(
                    '🔴 ══════════════════════════════════════════════',
                  );
                  debugPrint('🔴 Creation failed: $e');
                  debugPrint(
                    '🔴 ══════════════════════════════════════════════',
                  );
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('فشل إنشاء المستخدم: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                    setState(() => _isLoading = false);
                  }
                }
              }
            },
            child: const Text('إصدار بطاقة موظف'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.strings.userManagement,
              style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'إضافة مستخدم',
                  onPressed: _addUser,
                  color: AppColors.primary,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'تحديث',
                  onPressed: () {
                    debugPrint('🔘 SettingsScreen (Users): Refresh pressed');
                    _fetchUsers();
                  },
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: AppSpacing.md.h),
        Text(
          'إدارة المديريين والموظفين في السنتر.',
          style: TextStyle(
            color: AppColors.lightTextSecondary,
            fontSize: 13.sp,
          ),
        ),
        SizedBox(height: AppSpacing.xl.h),

        if (_isLoading)
          Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xl.w),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_error != null)
          Center(
            child: Column(
              children: [
                Icon(Icons.error_outline, size: 48.sp, color: AppColors.error),
                SizedBox(height: AppSpacing.md.h),
                Text('حدث خطأ: $_error'),
                const SizedBox(height: AppSpacing.md),
                ElevatedButton.icon(
                  onPressed: _fetchUsers,
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          )
        else if (_users.isEmpty)
          Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xl.w),
              child: Column(
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 48.sp,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: AppSpacing.md.h),
                  Text(
                    'لا يوجد مستخدمين',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'اضغط على + لإضافة مستخدم جديد',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _users.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final user = _users[index];
              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            (user['full_name'] as String?)
                                    ?.substring(0, 1)
                                    .toUpperCase() ??
                                'U',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      // User Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user['full_name'] ?? 'مستخدم بدون اسم',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            if (user['phone'] != null)
                              Row(
                                children: [
                                  // The following lines are syntactically incorrect in this context.
                                  // They appear to be part of a switch statement from another part of the code.
                                  // To maintain syntactic correctness, I'm placing them as a comment.
                                  // If these lines are intended to be part of a switch statement,
                                  // please provide the full switch statement context.
                                  /*
                                  case 'subscription':
                                    return const SubscriptionSettingsScreen();
                                  case 'team':
                                    return _buildTeamManagementSection(isDark, strings);
                                  */
                                  const Icon(
                                    Icons.phone_outlined,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    user['phone'],
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      // Role Chip
                      Chip(
                        label: Text(
                          user['role'] == 'center_admin'
                              ? 'مدير مركز'
                              : user['role'] == 'super_admin'
                              ? 'مدير نظام'
                              : user['role'] ?? 'غير محدد',
                          style: const TextStyle(fontSize: 11),
                        ),
                        backgroundColor:
                            (user['role'] == 'center_admin' ||
                                user['role'] == 'super_admin')
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : Colors.grey.withValues(alpha: 0.1),
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color:
                              (user['role'] == 'center_admin' ||
                                  user['role'] == 'super_admin')
                              ? AppColors.primary
                              : Colors.black87,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
