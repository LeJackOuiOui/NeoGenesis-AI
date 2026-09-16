import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryGreen = Color(0xFF00C853);
  static const Color darkBackground = Color(0xFF0B1917);
  static const Color lightGreenBg = Color(0xFFEAFCEF);
  static const Color textDark = Color(0xFF0F172A);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        primary: primaryGreen,
      ),
      fontFamily: 'Roboto', // Ajusta según la fuente de tu proyecto
    );
  }
}