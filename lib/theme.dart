import 'package:flutter/material.dart';

/// STPG palette. Day/night variants match the original app exactly.
class Stpg {
  static bool day = true;

  static const orange = Color(0xFFFF6A00);
  static const green = Color(0xFF4CAF50);
  static const red = Color(0xFFFF3B30);

  static Color get black => day ? const Color(0xFFE2E6EC) : const Color(0xFF070A0F);
  static Color get dark => day ? const Color(0xFFEDF1F6) : const Color(0xFF0D1117);
  static Color get panel => day ? const Color(0xFFF8FAFC) : const Color(0xFF12161D);
  static Color get border => day ? const Color(0xFFCBD5E1) : const Color(0xFF222B38);
  static Color get gray => day ? const Color(0xFF475569) : const Color(0xFF9DA5B0);
  static Color get text => day ? const Color(0xFF0F172A) : Colors.white;
  static Color get deepPanel => day ? Colors.white : const Color(0xFF090B0E);
  static Color get alertPanel => day ? const Color(0xFFFFF1F0) : const Color(0xFF180B0B);
  static Color get activePanel => day ? const Color(0xFFFFF4EA) : const Color(0xFF1E1610);

  static TextStyle label({double size = 12, Color? color, FontWeight weight = FontWeight.w800, double spacing = 1.6}) =>
      TextStyle(fontSize: size, color: color ?? gray, fontWeight: weight, letterSpacing: spacing);

  static TextStyle title({double size = 20, Color? color, double spacing = 1.2}) =>
      TextStyle(fontSize: size, color: color ?? text, fontWeight: FontWeight.w900, letterSpacing: spacing);

  static ThemeData theme() => ThemeData(
        useMaterial3: true,
        brightness: day ? Brightness.light : Brightness.dark,
        scaffoldBackgroundColor: black,
        colorScheme: ColorScheme.fromSeed(
          seedColor: orange,
          brightness: day ? Brightness.light : Brightness.dark,
          primary: orange,
        ),
      );
}
