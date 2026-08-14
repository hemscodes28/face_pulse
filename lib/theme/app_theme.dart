import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Color Palette
  static const Color primary = Color(0xFF006877);
  static const Color primaryLight = Color(0xFFE6F4F8);
  static const Color accent = Color(0xFF2FD9F4);
  static const Color darkNavy = Color(0xFF1E3A5F);
  static const Color background = Color(0xFFFAF8FF);
  static const Color surface = Colors.white;
  static const Color textDark = Color(0xFF131B2E);
  static const Color textMedium = Color(0xFF6C797D);
  static const Color textLight = Color(0xFF94A3B8);
  static const Color outline = Color(0xFFE2E8F0);

  // Typography Styles
  static TextStyle serifFont({
    double fontSize = 16.0,
    FontWeight fontWeight = FontWeight.normal,
    Color color = textDark,
    double? height,
    FontStyle fontStyle = FontStyle.normal,
  }) {
    return GoogleFonts.playfairDisplay(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      fontStyle: fontStyle,
    );
  }

  static TextStyle sansFont({
    double fontSize = 14.0,
    FontWeight fontWeight = FontWeight.normal,
    Color color = textDark,
    double? height,
    double? letterSpacing,
    FontStyle fontStyle = FontStyle.normal,
  }) {
    return GoogleFonts.hankenGrotesk(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      fontStyle: fontStyle,
    );
  }

  // Floating Input Decoration Style
  static InputDecoration inputDecoration({
    required String labelText,
    required IconData prefixIcon,
    Widget? suffixIcon,
    bool isFocused = false,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: sansFont(
        fontSize: 14.0,
        fontWeight: FontWeight.w600,
        color: isFocused ? primary : textMedium,
      ),
      floatingLabelStyle: sansFont(
        fontSize: 10.0,
        fontWeight: FontWeight.bold,
        color: primary,
        letterSpacing: 0.08,
      ),
      prefixIcon: Icon(
        prefixIcon,
        color: isFocused ? primary : textLight,
        size: 20,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: outline, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }
}
