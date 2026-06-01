// lib/utils/theme.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Reminder type labels (Vietnamese) ──────────────────────────────────────
String reminderTypeLabel(String? type) {
  switch ((type ?? '').toUpperCase()) {
    case 'EXERCISE':   return 'Bài tập';
    case 'MEDICATION': return 'Thuốc uống';
    case 'NUTRITION':  return 'Dinh dưỡng';
    default:           return type ?? 'Khác';
  }
}

IconData reminderTypeIcon(String? type) {
  switch ((type ?? '').toUpperCase()) {
    case 'EXERCISE':   return Icons.fitness_center_rounded;
    case 'MEDICATION': return Icons.medication_rounded;
    case 'NUTRITION':  return Icons.restaurant_rounded;
    default:           return Icons.notifications_rounded;
  }
}

Color reminderTypeColor(String? type) {
  switch ((type ?? '').toUpperCase()) {
    case 'EXERCISE':   return const Color(0xFF0D9488);
    case 'MEDICATION': return const Color(0xFFF97316);
    case 'NUTRITION':  return const Color(0xFF22C55E);
    default:           return const Color(0xFF8B5CF6);
  }
}

class AppTheme {
  static const Color primary      = Color(0xFF0D9488); // teal-600
  static const Color primaryDark  = Color(0xFF0F766E); // teal-700
  static const Color accent       = Color(0xFFF97316); // orange-500
  static const Color success      = Color(0xFF22C55E); // green-500
  static const Color warning      = Color(0xFFEAB308); // yellow-500
  static const Color danger       = Color(0xFFEF4444); // red-500
  static const Color surface      = Color(0xFFF0FDFA); // teal-50
  static const Color cardBg       = Colors.white;
  static const Color textPrimary  = Color(0xFF134E4A); // teal-900
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color robotBlue    = Color(0xFF0D9488);
  static const Color elderlyPurple = Color(0xFF8B5CF6);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
      ).copyWith(
        primary: primary,
        secondary: accent,
        surface: surface,
      ),
      textTheme: GoogleFonts.nunitoTextTheme().copyWith(
        headlineLarge:  GoogleFonts.nunito(fontSize: 28, fontWeight: FontWeight.w800, color: textPrimary),
        headlineMedium: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w700, color: textPrimary),
        titleLarge:     GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary),
        titleMedium:    GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w600, color: textPrimary),
        bodyLarge:      GoogleFonts.nunito(fontSize: 16, color: textPrimary, height: 1.5),
        bodyMedium:     GoogleFonts.nunito(fontSize: 15, color: textSecondary, height: 1.5),
        labelLarge:     GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black12,
        centerTitle: true,
        titleTextStyle: GoogleFonts.nunito(
            fontSize: 19, fontWeight: FontWeight.w800, color: textPrimary),
        iconTheme: const IconThemeData(color: textPrimary, size: 24),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 54),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FFFE),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCCFBF1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCCFBF1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: danger, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 15),
        hintStyle: const TextStyle(color: textSecondary, fontSize: 15),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFCCFBF1)),
        ),
        clipBehavior: Clip.antiAlias,
        color: cardBg,
      ),
      chipTheme: ChipThemeData(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        labelStyle: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFCCFBF1), thickness: 1, space: 1),
      scaffoldBackgroundColor: surface,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
