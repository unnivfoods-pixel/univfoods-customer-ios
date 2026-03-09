import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primary = Color(0xFFFF9F1C);
  static const Color secondary = Color(0xFF2D3436);
  static const Color background = Color(0xFFF4F6F8);
  static const Color error = Color(0xFFD63031);
  static const Color success = Color(0xFF00B894);

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        secondary: secondary,
        error: error,
      ),
      fontFamily: GoogleFonts.outfit().fontFamily,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: secondary),
        titleTextStyle: TextStyle(
          color: secondary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
