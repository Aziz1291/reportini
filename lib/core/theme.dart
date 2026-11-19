import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const civicBlue = Color(0xFF003980);
const civicCanvas = Color(0xFFF7F9FB);
const civicInk = Color(0xFF191C1E);
const civicMuted = Color(0xFF545C69);
const civicLine = Color(0xFFE2E8F0);
const civicTint = Color(0xFFEAF1FC);

ThemeData civicTheme({bool useGoogleFonts = true}) {
  final base = ThemeData(
    useMaterial3: true,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    colorScheme: ColorScheme.fromSeed(seedColor: civicBlue).copyWith(
      primary: civicBlue,
      onPrimary: Colors.white,
      surface: civicCanvas,
      onSurface: civicInk,
      outlineVariant: civicLine,
      error: const Color(0xFFBA1A1A),
    ),
    scaffoldBackgroundColor: civicCanvas,
  );
  // The bundled variable face supplies all weights without a font request.
  if (useGoogleFonts) GoogleFonts.config.allowRuntimeFetching = false;
  final inter = useGoogleFonts ? GoogleFonts.inter() : null;
  final text = base.textTheme.apply(
    fontFamily: inter?.fontFamily,
    bodyColor: civicInk,
    displayColor: civicInk,
  );
  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: civicLine),
  );
  final button = FilledButton.styleFrom(
    minimumSize: const Size(0, 50),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: text.labelLarge?.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w600,
    ),
  );
  return base.copyWith(
    textTheme: text.copyWith(
      headlineMedium: text.headlineMedium?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -.5,
      ),
      headlineSmall: text.headlineSmall?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -.35,
      ),
      titleLarge: text.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: text.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 15, height: 1.45),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: civicInk,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: Border(bottom: BorderSide(color: civicLine)),
    ),
    filledButtonTheme: FilledButtonThemeData(style: button),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        side: const BorderSide(color: civicLine),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: const Color(0xFFF2F4F6),
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: civicBlue, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: const TextStyle(color: civicMuted),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    navigationBarTheme: const NavigationBarThemeData(
      height: 64,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: civicTint,
    ),
  );
}
