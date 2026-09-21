import 'package:flutter/material.dart';

class AppColors {
  static const black = Color(0xFF000000);
  static const darkNavy = Color(0xFF07131F);
  static const deepBlue = Color(0xFF10263A);
  static const steelBlue = Color(0xFF49677E);
  static const iceBlue = Color(0xFFDCEAF2);
  static const snowWhite = Color(0xFFF7FAFC);
  static const mutedGrey = Color(0xFF8FA1AE);
  static const errorRed = Color(0xFFE53935);
  static const cardWhite = Color(0xFFFFFFFF);

}
class AppSizes {
  static const pagePadding = 24.0;
  static const cardRadius = 22.0;
  static const inputRadius = 14.0;
  static const buttonHeight = 54.0;
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: AppColors.snowWhite,
      primaryColor: AppColors.deepBlue,

      colorScheme: const ColorScheme.light(
        brightness: Brightness.light,
        primary: AppColors.deepBlue,
        onPrimary: AppColors.snowWhite,
        secondary: AppColors.steelBlue,
        onSecondary: AppColors.snowWhite,
        error: AppColors.errorRed,
        onError: AppColors.snowWhite,
        background: AppColors.iceBlue,
        onBackground: AppColors.darkNavy,
        surface: AppColors.snowWhite,
        onSurface: AppColors.darkNavy,
      ),
      
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.deepBlue,
        foregroundColor: AppColors.snowWhite,
        centerTitle: true,
      ),
    );
  }
}