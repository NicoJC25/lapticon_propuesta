import 'package:flutter/material.dart';

abstract final class AppColors {
  static const ink = Color(0xFF142F46);
  static const muted = Color(0xFF536978);
  static const teal = Color(0xFF007A70);
  static const mint = Color(0xFFD6F4EC);
  static const paper = Color(0xFFF8FAF9);
  static const border = Color(0xFFDCE5E5);
}

abstract final class AppTheme {
  static final light = ThemeData(
    useMaterial3: true,
    fontFamily: 'Manrope',
    scaffoldBackgroundColor: AppColors.paper,
    colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.teal,
        primary: AppColors.ink,
        secondary: AppColors.teal,
        surface: Colors.white),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
          fontSize: 38,
          height: 1.16,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.5,
          color: AppColors.ink),
      headlineMedium: TextStyle(
          fontSize: 30,
          height: 1.2,
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
          color: AppColors.ink),
      bodyLarge: TextStyle(fontSize: 15, height: 1.65, color: AppColors.muted),
      bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: AppColors.ink),
    ),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
      backgroundColor: AppColors.ink,
      foregroundColor: Colors.white,
      minimumSize: const Size(0, 56),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      textStyle: const TextStyle(
          fontFamily: 'Manrope', fontSize: 15, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    )),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.ink,
      minimumSize: const Size(0, 56),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      side: const BorderSide(color: AppColors.border),
      textStyle: const TextStyle(
          fontFamily: 'Manrope', fontSize: 14, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    )),
    textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
      foregroundColor: AppColors.teal,
      minimumSize: const Size(48, 48),
      textStyle:
          const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700),
    )),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: const TextStyle(color: Color(0xFF71818C), fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.teal, width: 2)),
      errorMaxLines: 3,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
  );
}
