import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors - Luxury Ivory & Obsidian Palette inspired by high-end Booking UI
  static const Color backgroundIvory = Color(0xFFF4F3EE);
  static const Color backgroundIvoryLight = Color(0xFFFAF9F6);
  static const Color obsidianBlack = Color(0xFF191817);
  static const Color obsidianCard = Color(0xFF1E1E1E);
  static const Color textMuted = Color(0xFF726F68);
  static const Color sandPill = Color(0xFFE8E5DD);
  static const Color accentGold = Color(0xFFD4A373);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: backgroundIvory,
      colorScheme: const ColorScheme.light(
        primary: obsidianBlack,
        onPrimary: Colors.white,
        surface: backgroundIvory,
        onSurface: obsidianBlack,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: obsidianBlack,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: obsidianBlack),
      ),
      cardTheme: CardThemeData(
        color: obsidianCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: obsidianBlack, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: obsidianBlack,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: CircleBorder(),
      ),
    );
  }

  static ThemeData get darkTheme => lightTheme;
}
