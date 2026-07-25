import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SenAlgoTheme {
  static const neonGreen = Color(0xFF39FF14);
  static const neonCyan = Color(0xFF00FFFF);
  static const neonPink = Color(0xFFFE019A);
  static const neonYellow = Color(0xFFFDF001);
  static const darkBg = Color(0xFF0D0D0D);
  static const surfaceBg = Color(0xFF1A1A1A);

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: neonCyan,
      brightness: Brightness.dark,
      surface: surfaceBg,
      primary: neonCyan,
      secondary: neonGreen,
    ),
    scaffoldBackgroundColor: darkBg,
    textTheme: GoogleFonts.firaCodeTextTheme(ThemeData.dark().textTheme),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
  );
}
