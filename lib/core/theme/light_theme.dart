import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../constants/app_spacing.dart';

/// EdSentre Light Theme
/// ثيم الوضع الفاتح
class LightTheme {
  LightTheme._();

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        
        // Colors
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.lightBackground,
        
        // Color Scheme
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          onPrimary: AppColors.white,
          primaryContainer: AppColors.primarySurface,
          onPrimaryContainer: AppColors.primaryDark,
          
          secondary: AppColors.secondary,
          onSecondary: AppColors.white,
          secondaryContainer: AppColors.secondarySurface,
          onSecondaryContainer: AppColors.secondaryDark,
          
          surface: AppColors.lightSurface,
          onSurface: AppColors.lightTextPrimary,
          
          error: AppColors.error,
          onError: AppColors.white,
          errorContainer: AppColors.errorSurface,
          onErrorContainer: AppColors.errorDark,
          
          outline: AppColors.lightBorder,
          outlineVariant: AppColors.gray200,
        ),
        
        // Typography
        textTheme: AppTypography.textTheme.apply(
          bodyColor: AppColors.lightTextPrimary,
          displayColor: AppColors.lightTextPrimary,
        ),
        
        // AppBar Theme
        appBarTheme: AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 1,
          backgroundColor: AppColors.lightSurface,
          foregroundColor: AppColors.lightTextPrimary,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: AppTypography.headlineMediumStyle.copyWith(
            color: AppColors.lightTextPrimary,
          ),
          iconTheme: const IconThemeData(
            color: AppColors.lightTextPrimary,
            size: AppSpacing.iconSizeLg,
          ),
        ),
        
        // Card Theme
        cardTheme: CardThemeData(
          elevation: 0,
          color: AppColors.lightSurface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            side: const BorderSide(color: AppColors.lightBorder),
          ),
          margin: EdgeInsets.zero,
        ),
        
        // Elevated Button Theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
            minimumSize: const Size(0, AppSpacing.buttonHeight),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.buttonPaddingHorizontal,
              vertical: AppSpacing.buttonPaddingVertical,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            textStyle: AppTypography.labelLargeStyle,
          ),
        ),
        
        // Outlined Button Theme
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            minimumSize: const Size(0, AppSpacing.buttonHeight),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.buttonPaddingHorizontal,
              vertical: AppSpacing.buttonPaddingVertical,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            side: const BorderSide(color: AppColors.primary),
            textStyle: AppTypography.labelLargeStyle,
          ),
        ),
        
        // Text Button Theme
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            minimumSize: const Size(0, AppSpacing.buttonHeight),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.buttonPaddingHorizontal,
              vertical: AppSpacing.buttonPaddingVertical,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            textStyle: AppTypography.labelLargeStyle,
          ),
        ),
        
        // Input Decoration Theme
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.lightSurfaceVariant,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.inputPaddingHorizontal,
            vertical: AppSpacing.inputPaddingVertical,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            borderSide: const BorderSide(color: AppColors.lightBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            borderSide: const BorderSide(color: AppColors.lightBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            borderSide: const BorderSide(color: AppColors.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            borderSide: const BorderSide(color: AppColors.error, width: 2),
          ),
          hintStyle: AppTypography.bodyMediumStyle.copyWith(
            color: AppColors.lightTextTertiary,
          ),
          labelStyle: AppTypography.bodyMediumStyle.copyWith(
            color: AppColors.lightTextSecondary,
          ),
        ),
        
        // Divider Theme
        dividerTheme: const DividerThemeData(
          color: AppColors.lightDivider,
          thickness: 1,
          space: 1,
        ),
        
        // Icon Theme
        iconTheme: const IconThemeData(
          color: AppColors.lightTextSecondary,
          size: AppSpacing.iconSizeLg,
        ),
        
        // Dialog Theme
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.lightSurface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          ),
          titleTextStyle: AppTypography.headlineMediumStyle.copyWith(
            color: AppColors.lightTextPrimary,
          ),
        ),
        
        // Bottom Sheet Theme
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.lightSurface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusXl),
            ),
          ),
        ),
        
        // Chip Theme
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.lightSurfaceVariant,
          selectedColor: AppColors.primarySurface,
          disabledColor: AppColors.gray100,
          labelStyle: AppTypography.labelMediumStyle,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          ),
        ),
        
        // Tab Bar Theme
        tabBarTheme: TabBarThemeData(
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.lightTextSecondary,
          labelStyle: AppTypography.labelLargeStyle,
          unselectedLabelStyle: AppTypography.labelLargeStyle,
          indicator: const UnderlineTabIndicator(
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
        
        // Navigation Rail Theme
        navigationRailTheme: const NavigationRailThemeData(
          backgroundColor: AppColors.lightSurface,
          selectedIconTheme: IconThemeData(color: AppColors.primary),
          unselectedIconTheme: IconThemeData(color: AppColors.lightTextSecondary),
          indicatorColor: AppColors.primarySurface,
        ),
        
        // Drawer Theme
        drawerTheme: const DrawerThemeData(
          backgroundColor: AppColors.lightSurface,
          surfaceTintColor: Colors.transparent,
        ),
      );
}


