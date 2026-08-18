/*
Tujuan: Membangun ThemeData gelap/terang dari token AppColors.
Caller: main.dart (MaterialApp theme & darkTheme).
Dependensi: AppColors, Flutter Material.
Main Functions: buildAppTheme().
Side Effects: Tidak ada (membaca AppColors.isLight).
*/
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Theme SM Workshop: dark luxury (default) + light mode ala web SM-MIS.
ThemeData buildAppTheme() {
  final isLight = AppColors.isLight;
  return ThemeData(
    useMaterial3: true,
    brightness: isLight ? Brightness.light : Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: isLight
        ? ColorScheme.light(
            primary: AppColors.lightGold,
            onPrimary: AppColors.lightInk,
            secondary: AppColors.lightOrange,
            onSecondary: AppColors.lightInk,
            surface: AppColors.lightSurface,
            onSurface: AppColors.lightInk,
            error: AppColors.lightLocked,
            outline: AppColors.lightBorder,
          )
        : ColorScheme.dark(
            primary: AppColors.darkGold,
            onPrimary: AppColors.darkBackground,
            secondary: AppColors.darkOrange,
            onSecondary: AppColors.darkBackground,
            surface: AppColors.darkSurfaceCard,
            onSurface: AppColors.darkTextPrimary,
            error: AppColors.darkLocked,
            outline: AppColors.darkBorder,
          ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.surfaceCard,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.gold,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.gold,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surfaceCard,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceInput,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.gold.withValues(alpha: 0.5)),
      ),
      labelStyle: TextStyle(color: AppColors.textMuted),
      hintStyle: TextStyle(color: AppColors.textDisabled),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    dividerTheme: DividerThemeData(
      color: AppColors.borderSubtle,
      thickness: 1,
      space: 0,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surfaceCard,
      contentTextStyle: TextStyle(color: AppColors.textPrimary),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.gold,
        foregroundColor: isLight ? AppColors.lightInk : AppColors.darkBackground,
        disabledBackgroundColor: AppColors.surfaceInput,
        disabledForegroundColor: AppColors.textDisabled,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        textStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        side: BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.gold),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.surfaceNav,
      selectedItemColor: AppColors.gold,
      unselectedItemColor: AppColors.textDisabled,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
  );
}
