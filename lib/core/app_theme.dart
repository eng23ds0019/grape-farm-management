import 'package:flutter/material.dart';

class AppColors {
  static const grapeGreen = Color(0xFF2E7D32); // Primary Green #2E7D32
  static const freshGreen = Color(0xFF4CAF50); // Secondary Green #4CAF50
  static const leafLight = Color(0xFFE8F5E9);  // Light green accent
  static const cream = Color(0xFFFFFFFF);      // Plain white background #FFFFFF
  static const softYellow = Color(0xFFFFD66B);
  static const earthBrown = Color(0xFF8B5E34);
  static const grapePurple = Color(0xFF2E7D32); // Keep green theme dominant
  static const ink = Color(0xFF1E293B);
  static const muted = Color(0xFF64748B);
  static const surface = Color(0xFFFFFFFF);
  static const danger = Color(0xFFD94A38);
}

class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.grapeGreen,
      primary: AppColors.grapeGreen,
      secondary: AppColors.grapePurple,
      surface: AppColors.surface,
      error: AppColors.danger,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.cream,
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
        headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(fontSize: 16, height: 1.35),
        bodyMedium: TextStyle(fontSize: 14, height: 1.35),
      ).apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE5EADD)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.grapeGreen, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          minimumSize: const Size.fromHeight(56),
          foregroundColor: Colors.white,
          backgroundColor: AppColors.grapeGreen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        indicatorColor: AppColors.leafLight,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
