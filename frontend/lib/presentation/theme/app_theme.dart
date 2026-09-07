/// Application Theme — "Ink & Gold"
///
/// A visual identity grounded in bound books rather than generic SaaS
/// purple: warm ink/parchment neutrals, a garnet + gold accent pair, and
/// Fraunces (a characterful literary serif) for titles/display paired with
/// Public Sans for UI and body text.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// App colors
class AppColors {
  // Primary — deep garnet, like a leather binding
  static const Color primary = Color(0xFF9B2C3E);
  static const Color primaryDark = Color(0xFF7A2230);
  static const Color primaryLight = Color(0xFFD9536A);

  // Secondary / accent — embossed gold foil
  static const Color secondary = Color(0xFFC9A227);
  static const Color accent = Color(0xFF5B7B5E); // muted sage, tertiary variety

  // Background — warm ink / parchment, not cold navy or grey
  static const Color backgroundLight = Color(0xFFF7F1E6);
  static const Color backgroundDark = Color(0xFF1B140F);
  static const Color surfaceLight = Color(0xFFFFFDF8);
  static const Color surfaceDark = Color(0xFF251C15);
  static const Color surfaceRaisedDark = Color(0xFF2E2219);

  // Kindle reading modes
  static const Color readingLight = Color(0xFFF5F2EB);   // Warm cream
  static const Color readingSepia = Color(0xFFF4ECD8);   // Classic sepia
  static const Color readingDark = Color(0xFF1B140F);    // Matches ink bg

  // Text
  static const Color textPrimaryLight = Color(0xFF2A1D14);
  static const Color textSecondaryLight = Color(0xFF8A7862);
  static const Color textPrimaryDark = Color(0xFFF2E9DA);
  static const Color textSecondaryDark = Color(0xFFB3A08C);

  // Status
  static const Color success = Color(0xFF5B8C5A);
  static const Color warning = Color(0xFFC9A227);
  static const Color error = Color(0xFFD9534F);
  static const Color info = Color(0xFF5B7B9E);

  // Bookmarks
  static const Color bookmarkYellow = Color(0xFFC9A227);
  static const Color bookmarkGreen = Color(0xFF5B8C5A);
  static const Color bookmarkBlue = Color(0xFF5B7B9E);
  static const Color bookmarkPink = Color(0xFFD9536A);
  static const Color bookmarkPurple = Color(0xFF8B5A8C);

  // Kindle UI
  static const Color kindleOrange = Color(0xFFC9752E);

  static const Color dividerLight = Color(0xFFE6DCC8);
  static const Color dividerDark = Color(0xFF3A2C20);
}

/// Animation durations and values used across the app
class AppAnimations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 600);
  static const Duration highlight = Duration(milliseconds: 200);

  static const double highlightScale = 1.04;
  static const double highlightRadius = 3;
}

/// Type helpers — Fraunces for titles/display, Public Sans for UI/body.
class AppType {
  static TextStyle display({
    required double size,
    FontWeight weight = FontWeight.w600,
    Color? color,
    double? letterSpacing,
  }) =>
      GoogleFonts.fraunces(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: 1.15,
      );

  static TextStyle body({
    required double size,
    FontWeight weight = FontWeight.normal,
    Color? color,
  }) =>
      GoogleFonts.publicSans(fontSize: size, fontWeight: weight, color: color);
}

/// App theme
class AppTheme {
  static const _buttonRadius = 11.0;
  static const _cardRadius = 18.0;
  static const _fieldRadius = 13.0;

  static TextTheme _textTheme(Color textColor, Color mutedColor) {
    final base = GoogleFonts.publicSansTextTheme();
    return base.copyWith(
      displayLarge: AppType.display(size: 32, weight: FontWeight.w700, color: textColor, letterSpacing: -0.3),
      displayMedium: AppType.display(size: 24, weight: FontWeight.w700, color: textColor, letterSpacing: -0.2),
      displaySmall: AppType.display(size: 20, weight: FontWeight.w600, color: textColor),
      titleLarge: AppType.display(size: 18, weight: FontWeight.w600, color: textColor),
      bodyLarge: GoogleFonts.publicSans(fontSize: 16, color: textColor),
      bodyMedium: GoogleFonts.publicSans(fontSize: 14, color: mutedColor),
      bodySmall: GoogleFonts.publicSans(fontSize: 12, color: mutedColor),
      labelLarge: GoogleFonts.publicSans(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
    );
  }

  // Light theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: GoogleFonts.publicSans().fontFamily,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        tertiary: AppColors.accent,
        surface: AppColors.surfaceLight,
        onPrimary: Colors.white,
        onSecondary: Color(0xFF2A1D14),
        onSurface: AppColors.textPrimaryLight,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.backgroundLight,
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: AppColors.backgroundLight,
        foregroundColor: AppColors.textPrimaryLight,
        titleTextStyle: AppType.display(size: 20, weight: FontWeight.w600, color: AppColors.textPrimaryLight),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cardRadius),
          side: const BorderSide(color: AppColors.dividerLight),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          textStyle: GoogleFonts.publicSans(fontWeight: FontWeight.w600, fontSize: 15),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_buttonRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.4),
          textStyle: GoogleFonts.publicSans(fontWeight: FontWeight.w600, fontSize: 15),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_buttonRadius)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: GoogleFonts.publicSans(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight,
        labelStyle: GoogleFonts.publicSans(color: AppColors.textSecondaryLight),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_fieldRadius),
          borderSide: const BorderSide(color: AppColors.dividerLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_fieldRadius),
          borderSide: const BorderSide(color: AppColors.dividerLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_fieldRadius),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceLight,
        indicatorColor: AppColors.primary.withValues(alpha: 0.14),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => GoogleFonts.publicSans(
          fontSize: 11.5,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? AppColors.primary : AppColors.textSecondaryLight,
        )),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? AppColors.primary : AppColors.textSecondaryLight,
        )),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceLight,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondaryLight,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerLight,
        thickness: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.primary.withValues(alpha: 0.08),
        labelStyle: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primary),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      textTheme: _textTheme(AppColors.textPrimaryLight, AppColors.textSecondaryLight),
    );
  }

  // Dark theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: GoogleFonts.publicSans().fontFamily,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryLight,
        secondary: AppColors.secondary,
        tertiary: AppColors.accent,
        surface: AppColors.surfaceDark,
        onPrimary: Colors.white,
        onSecondary: Color(0xFF2A1D14),
        onSurface: AppColors.textPrimaryDark,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.backgroundDark,
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: AppColors.backgroundDark,
        foregroundColor: AppColors.textPrimaryDark,
        titleTextStyle: AppType.display(size: 20, weight: FontWeight.w600, color: AppColors.textPrimaryDark),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surfaceDark,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cardRadius),
          side: const BorderSide(color: AppColors.dividerDark),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.primaryLight,
          foregroundColor: const Color(0xFF1B140F),
          textStyle: GoogleFonts.publicSans(fontWeight: FontWeight.w600, fontSize: 15),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_buttonRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          side: const BorderSide(color: AppColors.primaryLight, width: 1.4),
          textStyle: GoogleFonts.publicSans(fontWeight: FontWeight.w600, fontSize: 15),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_buttonRadius)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          textStyle: GoogleFonts.publicSans(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceDark,
        labelStyle: GoogleFonts.publicSans(color: AppColors.textSecondaryDark),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_fieldRadius),
          borderSide: const BorderSide(color: AppColors.dividerDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_fieldRadius),
          borderSide: const BorderSide(color: AppColors.dividerDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_fieldRadius),
          borderSide: const BorderSide(color: AppColors.primaryLight, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        indicatorColor: AppColors.primaryLight.withValues(alpha: 0.18),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => GoogleFonts.publicSans(
          fontSize: 11.5,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? AppColors.primaryLight : AppColors.textSecondaryDark,
        )),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? AppColors.primaryLight : AppColors.textSecondaryDark,
        )),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        selectedItemColor: AppColors.primaryLight,
        unselectedItemColor: AppColors.textSecondaryDark,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerDark,
        thickness: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.primaryLight.withValues(alpha: 0.14),
        labelStyle: GoogleFonts.publicSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primaryLight),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      textTheme: _textTheme(AppColors.textPrimaryDark, AppColors.textSecondaryDark),
    );
  }
}
