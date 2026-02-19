import 'package:flutter/material.dart';
import 'colors.dart';

final appTheme = ThemeData(
  useMaterial3: true,
  fontFamily: 'ReadexPro',
  colorScheme: const ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: Colors.white,
    secondary: AppColors.primaryVariant,
    onSecondary: Colors.white,
    error: AppColors.error,
    onError: Colors.white,
    surface: AppColors.surface,
    onSurface: AppColors.onSurface,
    surfaceContainerHighest: AppColors.background,
  ),
  scaffoldBackgroundColor: AppColors.background,
  cardTheme: const CardThemeData(
    color: AppColors.surface,
    elevation: 1,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.error),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      minimumSize: const Size(double.infinity, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: const TextStyle(
        fontFamily: 'ReadexPro',
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.primary,
      minimumSize: const Size(double.infinity, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      side: const BorderSide(color: AppColors.primary),
      textStyle: const TextStyle(
        fontFamily: 'ReadexPro',
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.surface,
    foregroundColor: AppColors.onSurface,
    elevation: 0,
    scrolledUnderElevation: 1,
    centerTitle: true,
    titleTextStyle: TextStyle(
      fontFamily: 'ReadexPro',
      fontSize: 20,
      fontWeight: FontWeight.w500,
      color: AppColors.onSurface,
    ),
  ),
  navigationRailTheme: const NavigationRailThemeData(
    backgroundColor: AppColors.surface,
    indicatorColor: Color(0x331B5E7B),
    useIndicator: true,
    selectedIconTheme: IconThemeData(
      color: AppColors.primary,
      size: 24,
    ),
    unselectedIconTheme: IconThemeData(
      color: AppColors.onSurfaceVariant,
      size: 22,
    ),
    selectedLabelTextStyle: TextStyle(
      fontFamily: 'ReadexPro',
      color: AppColors.primary,
      fontWeight: FontWeight.w700,
      fontSize: 13,
    ),
    unselectedLabelTextStyle: TextStyle(
      fontFamily: 'ReadexPro',
      color: AppColors.onSurfaceVariant,
      fontWeight: FontWeight.w400,
      fontSize: 12,
    ),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: AppColors.surface,
    indicatorColor: const Color(0x441B5E7B),
    elevation: 3,
    shadowColor: Colors.black26,
    iconTheme: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const IconThemeData(color: AppColors.primary, size: 24);
      }
      return const IconThemeData(color: AppColors.onSurfaceVariant, size: 22);
    }),
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const TextStyle(
          fontFamily: 'ReadexPro',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        );
      }
      return const TextStyle(
        fontFamily: 'ReadexPro',
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.onSurfaceVariant,
      );
    }),
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  ),
  dialogTheme: DialogThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
  ),
);
