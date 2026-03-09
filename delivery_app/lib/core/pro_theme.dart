import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProTheme {
  // --- HYPER-PREMIUM COLOR PALETTE ---
  static const Color primary =
      Color(0xFFFFD600); // Electric Yellow (High Visibility)
  static const Color secondary =
      Color(0xFF00C853); // Vibrant Mint Green (Ready/Success)
  static const Color accent =
      Color(0xFF00E5FF); // Cyber Blue (Routing/Navigation)

  static const Color dark =
      Color(0xFF051A10); // Midnight Forest (Deep Dark Green)
  static const Color slate = Color(0xFF0F172A); // Deep Slate
  static const Color gray = Color(0xFF64748B); // Cool Gray
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color bg = Color(0xFFF8FAFC); // Ultra-clean Neutral
  static const Color error = Color(0xFFFF3B30); // Alert Red

  // --- TYPOGRAPHY ENGINE ---
  static TextStyle get header => GoogleFonts.outfit(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: dark,
      letterSpacing: -0.5);

  static TextStyle get title => GoogleFonts.outfit(
      fontSize: 20, fontWeight: FontWeight.w600, color: dark);

  static TextStyle get body =>
      GoogleFonts.inter(fontSize: 14, color: gray, height: 1.5);

  static TextStyle get label => GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: gray,
      letterSpacing: 1.1);

  static TextStyle get button => GoogleFonts.outfit(
      fontSize: 16, fontWeight: FontWeight.w600, color: dark);

  // --- DESIGN SYSTEM ELEMENTS ---

  // High-End Card Decoration
  static BoxDecoration get cardDecor => BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: dark.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      );

  // Glassmorphism Protocol
  static BoxDecoration glassDecor(bool isDark) => BoxDecoration(
        color: (isDark ? slate : pureWhite).withOpacity(0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: (isDark ? pureWhite : dark).withOpacity(0.1)),
      );

  static List<BoxShadow> get softShadow => [
        BoxShadow(
            color: dark.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4)),
      ];

  static List<BoxShadow> get intenseShadow => [
        BoxShadow(
            color: dark.withOpacity(0.2),
            blurRadius: 30,
            offset: const Offset(0, 15)),
      ];

  // --- COMPONENT STYLES ---

  static InputDecoration inputDecor(String hint, IconData icon) =>
      InputDecoration(
        hintText: hint,
        hintStyle:
            GoogleFonts.inter(color: gray.withOpacity(0.5), fontSize: 14),
        prefixIcon: Icon(icon, color: dark, size: 20),
        filled: true,
        fillColor: pureWhite,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: dark.withOpacity(0.05)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: dark.withOpacity(0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
      );

  static ButtonStyle get ctaButton => ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: dark,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle:
            GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
      );

  static ButtonStyle get primaryButton => ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: dark,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle:
            GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold),
      );

  static ButtonStyle get secondaryButton => ElevatedButton.styleFrom(
        backgroundColor: slate,
        foregroundColor: pureWhite,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle:
            GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
      );

  // --- THEME DATA ---
  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: bg,
        primaryColor: primary,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          primary: primary,
          secondary: secondary,
          surface: pureWhite,
          background: bg,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: header.copyWith(fontSize: 20),
          iconTheme: const IconThemeData(color: dark),
        ),
      );
}
