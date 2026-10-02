import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SenAlgoTheme {
  static const neonGreen = Color(0xFF88E5BE);
  static const neonCyan = Color(0xFF8ABEFF);
  static const neonPink = Color(0xFFC5A5F5);
  static const neonYellow = Color(0xFFF0CE8A);
  static const darkBg = Color(0xFF0B1220);
  static const surfaceBg = Color(0xFF111C2E);
  static const raisedSurface = Color(0xFF19263B);
  static const border = Color(0xFF26354B);
  static const muted = Color(0xFF93A4BA);
  static const ink = Color(0xFFE8EFF8);

  static ThemeData get darkTheme {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: neonGreen,
        brightness: Brightness.dark,
        surface: surfaceBg,
        primary: neonGreen,
        onPrimary: darkBg,
        secondary: neonCyan,
        onSurface: ink,
      ),
      scaffoldBackgroundColor: darkBg,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: ink, displayColor: ink,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBg,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: muted, minimumSize: const Size(48, 48)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: neonGreen, foregroundColor: darkBg,
          disabledBackgroundColor: raisedSurface, disabledForegroundColor: muted,
          elevation: 0, minimumSize: const Size(48, 48), shape: shape,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink, side: const BorderSide(color: border),
          minimumSize: const Size(48, 48), shape: shape,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: raisedSurface,
        hintStyle: const TextStyle(color: muted),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating, backgroundColor: raisedSurface,
        contentTextStyle: const TextStyle(color: ink), shape: shape,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceBg, surfaceTintColor: Colors.transparent,
        showDragHandle: true, dragHandleColor: muted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: darkBg,
        selectedIconTheme: const IconThemeData(color: neonGreen),
        unselectedIconTheme: const IconThemeData(color: muted),
        selectedLabelTextStyle: const TextStyle(color: neonGreen, fontWeight: FontWeight.w700, fontSize: 12),
        unselectedLabelTextStyle: const TextStyle(color: muted, fontSize: 12),
        indicatorColor: neonGreen.withValues(alpha: 0.14),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68, backgroundColor: darkBg, surfaceTintColor: Colors.transparent,
        indicatorColor: neonGreen.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
          fontSize: 12, fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? neonGreen : muted,
        )),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
          size: 22, color: states.contains(WidgetState.selected) ? neonGreen : muted,
        )),
      ),
    );
  }
}
