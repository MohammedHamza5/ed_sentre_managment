import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../../../core/supabase/supabase_client.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/utils/responsive_utils.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _jobTitleController = TextEditingController();
  final _bioController = TextEditingController();

  DateTime? _birthDate;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final user = SupabaseClientManager.currentUser;
    if (user != null) {
      final meta = user.userMetadata ?? {};
      _nameController.text = meta['full_name'] ?? '';
      _emailController.text = user.email ?? '';
      _phoneController.text = meta['phone'] ?? '';
      _addressController.text = meta['address'] ?? '';
      _jobTitleController.text = meta['job_title'] ?? '';
      _bioController.text = meta['bio'] ?? '';
      
      if (meta['birth_date'] != null) {
        _birthDate = DateTime.tryParse(meta['birth_date']);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _jobTitleController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile(AppStrings strings) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updates = {
        'full_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'job_title': _jobTitleController.text.trim(),
        'bio': _bioController.text.trim(),
        'birth_date': _birthDate?.toIso8601String(),
      };
      
      await SupabaseClientManager.client.auth.updateUser(
        UserAttributes(data: updates),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(strings.saveSuccess),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${strings.error}: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final isDesktop = !ResponsiveUtils.isMobile(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildCoverHeader(context, isDark),
          Padding(
            padding: EdgeInsets.all(AppSpacing.xl.w),
            child: isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _buildProfileCard(context, strings, isDark)),
                      SizedBox(width: AppSpacing.xl.w),
                      Expanded(flex: 7, child: _buildDetailedForm(context, strings, isDark)),
                    ],
                  )
                : Column(
                    children: [
                      _buildProfileCard(context, strings, isDark),
                      SizedBox(height: AppSpacing.xl.h),
                      _buildDetailedForm(context, strings, isDark),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverHeader(BuildContext context, bool isDark) {
    return SizedBox(
      height: 200.h,
      width: double.infinity,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned.fill(
             child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(color: Colors.white.withValues(alpha: 0.1)),
             ),
          ),
          Positioned(
            left: AppSpacing.xl.w,
            bottom: AppSpacing.xl.h,
            child: Text(
              'الملف الشخصي', // Localized in AppStrings but accessible via context
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, AppStrings strings, bool isDark) {
    final initial = _nameController.text.isNotEmpty 
        ? _nameController.text.characters.first.toUpperCase() 
        : 'U';
        
    return Container(
      padding: EdgeInsets.all(AppSpacing.xl.w),
      decoration: _glassDecoration(isDark),
      child: Column(
        children: [
          Container(
            width: 120.w,
            height: 120.h,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 20.r,
                  offset: Offset(0, 10.h),
                ),
              ],
            ),
            child: Center(
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: 48.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            _nameController.text,
            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          Text(
            _jobTitleController.text.isEmpty ? 'مدير السنتر' : _jobTitleController.text, // "Center Manager" fallback
            style: TextStyle(color: AppColors.gray500, fontSize: 13.sp),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.xl.h),
          const Divider(),
          SizedBox(height: AppSpacing.md.h),
          _buildInfoRow(Icons.email_outlined, _emailController.text, isDark),
          SizedBox(height: AppSpacing.md.h),
          _buildInfoRow(Icons.phone_outlined, _phoneController.text.isEmpty ? 'غير محدد' : _phoneController.text, isDark),
          SizedBox(height: AppSpacing.md.h),
          _buildInfoRow(Icons.location_on_outlined, _addressController.text.isEmpty ? 'غير محدد' : _addressController.text, isDark),
        ],
      ),
    );
  }

  Widget _buildDetailedForm(BuildContext context, AppStrings strings, bool isDark) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.xl.w),
      decoration: _glassDecoration(isDark),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Text(
              'تعديل البيانات', // "Edit Details"
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 20.sp),
            ),
            SizedBox(height: AppSpacing.xl.h),
            
            Row(
              children: [
                Expanded(child: _buildTextField(strings.fullName, _nameController, Icons.person_outline, isDark)),
                SizedBox(width: AppSpacing.lg.w),
                Expanded(child: _buildTextField('المسمى الوظيفي', _jobTitleController, Icons.work_outline, isDark)), // Job Title
              ],
            ),
            SizedBox(height: AppSpacing.lg.h),

            Row(
              children: [
                Expanded(child: _buildTextField('رقم الهاتف', _phoneController, Icons.phone_outlined, isDark)), // Phone
                SizedBox(width: AppSpacing.lg.w),
                Expanded(child: _buildTextField('العنوان', _addressController, Icons.location_on_outlined, isDark)), // Address
              ],
            ),
            SizedBox(height: AppSpacing.lg.h),

             _buildTextField('نبذة عني', _bioController, Icons.info_outline, isDark, maxLines: 3), // Bio

            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              height: 50.h,
              child: AppButton(
                text: strings.saveChanges,
                onPressed: () => _updateProfile(strings),
                isLoading: _isLoading,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, bool isDark, {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.gray50.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r),
          borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.gray200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r),
          borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.gray200),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 20.sp, color: AppColors.primary),
        SizedBox(width: AppSpacing.md.w),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14.sp,
              color: isDark ? Colors.white.withValues(alpha: 0.7) : AppColors.gray700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  BoxDecoration _glassDecoration(bool isDark) {
    return BoxDecoration(
      color: isDark ? AppColors.darkSurface.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg.r),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 20.r,
          offset: Offset(0, 10.h),
        ),
      ],
      border: Border.all(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
      ),
    );
  }
}


