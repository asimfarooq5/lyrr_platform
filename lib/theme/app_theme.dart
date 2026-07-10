import 'package:flutter/material.dart';
import '../controllers/reader_controller.dart';

class AppTheme {
  // Common Colors
  static const Color primaryNeon = Color(0xFF6366F1); // Indigo
  static const Color secondaryTeal = Color(0xFF06B6D4); // Cyan
  static const Color accentRose = Color(0xFFF43F5E); // Rose

  // Dark Theme Colors
  static const Color darkBg = Color(0xFF0B0C10);
  static const Color darkCardBg = Color(0xFF161823);
  static const Color darkTextPrimary = Color(0xFFE2E8F0);
  static const Color darkTextSecondary = Color(0xFF94A3B8);

  // Light Theme Colors
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightCardBg = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);

  // Sepia Theme Colors
  static const Color sepiaBg = Color(0xFFF7F1E3);
  static const Color sepiaCardBg = Color(0xFFFEF9EF);
  static const Color sepiaTextPrimary = Color(0xFF4A3C31);
  static const Color sepiaTextSecondary = Color(0xFF7A6B5D);

  static ThemeData getDarkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      primaryColor: primaryNeon,
      colorScheme: const ColorScheme.dark(
        primary: primaryNeon,
        secondary: secondaryTeal,
        surface: darkCardBg,
        error: accentRose,
      ),
      cardTheme: CardThemeData(
        color: darkCardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: darkTextPrimary),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: darkTextPrimary),
        bodyLarge: TextStyle(fontSize: 16, color: darkTextPrimary),
        bodyMedium: TextStyle(fontSize: 14, color: darkTextSecondary),
      ),
    );
  }
}

class ReaderColors {
  final Color background;
  final Color text;
  final Color textSecondary;
  final Color highlightedText;
  final Color highlightedBackground;
  final Color cardBackground;
  final Color dividerColor;

  const ReaderColors({
    required this.background,
    required this.text,
    required this.textSecondary,
    required this.highlightedText,
    required this.highlightedBackground,
    required this.cardBackground,
    required this.dividerColor,
  });

  factory ReaderColors.of(ReaderThemeMode mode) {
    switch (mode) {
      case ReaderThemeMode.light:
        return const ReaderColors(
          background: AppTheme.lightBg,
          text: AppTheme.lightTextPrimary,
          textSecondary: AppTheme.lightTextSecondary,
          highlightedText: Colors.white,
          highlightedBackground: AppTheme.primaryNeon,
          cardBackground: AppTheme.lightCardBg,
          dividerColor: Color(0xFFE2E8F0),
        );
      case ReaderThemeMode.sepia:
        return const ReaderColors(
          background: AppTheme.sepiaBg,
          text: AppTheme.sepiaTextPrimary,
          textSecondary: AppTheme.sepiaTextSecondary,
          highlightedText: AppTheme.sepiaTextPrimary,
          highlightedBackground: Color(0xFFEAD8B1),
          cardBackground: AppTheme.sepiaCardBg,
          dividerColor: Color(0xFFE1D5C2),
        );
      case ReaderThemeMode.dark:
        return const ReaderColors(
          background: AppTheme.darkBg,
          text: AppTheme.darkTextPrimary,
          textSecondary: AppTheme.darkTextSecondary,
          highlightedText: Colors.black,
          highlightedBackground: AppTheme.secondaryTeal,
          cardBackground: AppTheme.darkCardBg,
          dividerColor: Color(0xFF1E293B),
        );
    }
  }
}
