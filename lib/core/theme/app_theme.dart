import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors - Futuristic Steel Grey, Deep Charcoal & Electric Ember Orange
  static const Color backgroundGrey = Color(0xFFE5E7EB);
  static const Color backgroundGreyLight = Color(0xFFEDEFF3);
  static const Color charcoalDark = Color(0xFF141518);
  static const Color charcoalCard = Color(0xFF1A1C21);
  static const Color charcoalText = Color(0xFF121316);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color pillGrey = Color(0xFFD9DCE3);
  static const Color accentOrange = Color(0xFFFF5225);
  static const Color accentOrangeGlow = Color(0xFFFF693B);
  static const Color accentOrangeDark = Color(0xFFFF3812);

  // Backward-compatible aliases
  static const Color backgroundIvory = backgroundGrey;
  static const Color backgroundIvoryLight = backgroundGreyLight;
  static const Color obsidianBlack = charcoalDark;
  static const Color obsidianCard = charcoalCard;
  static const Color sandPill = pillGrey;
  static const Color accentGold = accentOrange;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: backgroundGrey,
      colorScheme: const ColorScheme.light(
        primary: accentOrange,
        onPrimary: Colors.white,
        surface: backgroundGrey,
        onSurface: charcoalText,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: charcoalText,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: charcoalText),
      ),
      cardTheme: CardThemeData(
        color: charcoalCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.65),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.85), width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.85), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: accentOrange, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accentOrange,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: CircleBorder(),
      ),
    );
  }

  static ThemeData get darkTheme => lightTheme;
}
