import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../constants/app_spacing.dart';

/// EdSentre Dark Theme
/// ثيم الوضع الداكن
class DarkTheme {
  DarkTheme._();

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        
        // Colors
        primaryColor: AppColors.primaryLight,
        scaffoldBackgroundColor: AppColors.darkBackground,
        
        // Color Scheme
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primaryLight,
          onPrimary: AppColors.white,
          primaryContainer: AppColors.primaryDark,
          onPrimaryContainer: AppColors.primarySurface,
          
          secondary: AppColors.secondaryLight,
          onSecondary: AppColors.white,
          secondaryContainer: AppColors.secondaryDark,
          onSecondaryContainer: AppColors.secondarySurface,
          
          surface: AppColors.darkSurface,
          onSurface: AppColors.darkTextPrimary,
          
          error: AppColors.errorLight,
          onError: AppColors.white,
          errorContainer: AppColors.errorDark,
          onErrorContainer: AppColors.errorSurface,
          
          outline: AppColors.darkBorder,
          outlineVariant: AppColors.gray700,
        ),
        
        // Typography
        textTheme: AppTypography.textTheme.apply(
          bodyColor: AppColors.darkTextPrimary,
          displayColor: AppColors.darkTextPrimary,
        ),
        
        // AppBar Theme
        appBarTheme: AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 1,
          backgroundColor: AppColors.darkSurface,
          foregroundColor: AppColors.darkTextPrimary,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: AppTypography.headlineMediumStyle.copyWith(
            color: AppColors.darkTextPrimary,
          ),
          iconTheme: const IconThemeData(
            color: AppColors.darkTextPrimary,
            size: AppSpacing.iconSizeLg,
          ),
        ),
        
        // Card Theme
        cardTheme: CardThemeData(
          elevation: 0,
          color: AppColors.darkSurface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            side: const BorderSide(color: AppColors.darkBorder),
          ),
          margin: EdgeInsets.zero,
        ),
        
        // Elevated Button Theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: AppColors.primaryLight,
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
            foregroundColor: AppColors.primaryLight,
            minimumSize: const Size(0, AppSpacing.buttonHeight),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.buttonPaddingHorizontal,
              vertical: AppSpacing.buttonPaddingVertical,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            side: const BorderSide(color: AppColors.primaryLight),
            textStyle: AppTypography.labelLargeStyle,
          ),
        ),
        
        // Text Button Theme
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primaryLight,
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
          fillColor: AppColors.darkSurfaceVariant,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.inputPaddingHorizontal,
            vertical: AppSpacing.inputPaddingVertical,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            borderSide: const BorderSide(color: AppColors.darkBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            borderSide: const BorderSide(color: AppColors.darkBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            borderSide: const BorderSide(color: AppColors.primaryLight, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            borderSide: const BorderSide(color: AppColors.errorLight),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            borderSide: const BorderSide(color: AppColors.errorLight, width: 2),
          ),
          hintStyle: AppTypography.bodyMediumStyle.copyWith(
            color: AppColors.darkTextTertiary,
          ),
          labelStyle: AppTypography.bodyMediumStyle.copyWith(
            color: AppColors.darkTextSecondary,
          ),
        ),
        
        // Divider Theme
        dividerTheme: const DividerThemeData(
          color: AppColors.darkDivider,
          thickness: 1,
          space: 1,
        ),
        
        // Icon Theme
        iconTheme: const IconThemeData(
          color: AppColors.darkTextSecondary,
          size: AppSpacing.iconSizeLg,
        ),
        
        // Dialog Theme
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.darkSurface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          ),
          titleTextStyle: AppTypography.headlineMediumStyle.copyWith(
            color: AppColors.darkTextPrimary,
          ),
        ),
        
        // Bottom Sheet Theme
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.darkSurface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusXl),
            ),
          ),
        ),
        
        // Chip Theme
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.darkSurfaceVariant,
          selectedColor: AppColors.primaryDark,
          disabledColor: AppColors.gray800,
          labelStyle: AppTypography.labelMediumStyle.copyWith(
            color: AppColors.darkTextPrimary,
          ),
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
          labelColor: AppColors.primaryLight,
          unselectedLabelColor: AppColors.darkTextSecondary,
          labelStyle: AppTypography.labelLargeStyle,
          unselectedLabelStyle: AppTypography.labelLargeStyle,
          indicator: const UnderlineTabIndicator(
            borderSide: BorderSide(color: AppColors.primaryLight, width: 2),
          ),
        ),
        
        // Navigation Rail Theme
        navigationRailTheme: const NavigationRailThemeData(
          backgroundColor: AppColors.darkSurface,
          selectedIconTheme: IconThemeData(color: AppColors.primaryLight),
          unselectedIconTheme: IconThemeData(color: AppColors.darkTextSecondary),
          indicatorColor: AppColors.primaryDark,
        ),
        
        // Drawer Theme
        drawerTheme: const DrawerThemeData(
          backgroundColor: AppColors.darkSurface,
          surfaceTintColor: Colors.transparent,
        ),
      );
}


