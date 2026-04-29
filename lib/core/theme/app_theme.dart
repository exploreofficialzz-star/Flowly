import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Background
  static const bg = Color(0xFF0A0E23);
  static const bgCard = Color(0xFF12182E);
  static const bgSurface = Color(0xFF1A2140);

  // Neon accents
  static const neonBlue = Color(0xFF00C8FF);
  static const neonPurple = Color(0xFFB400FF);
  static const neonGreen = Color(0xFF00FF96);
  static const neonOrange = Color(0xFFFF8C00);
  static const neonPink = Color(0xFFFF0099);
  static const neonYellow = Color(0xFFFFE600);
  static const neonRed = Color(0xFFFF2D55);
  static const neonTeal = Color(0xFF00FFD1);

  // UI
  static const white = Color(0xFFFFFFFF);
  static const white70 = Color(0xB3FFFFFF);
  static const white40 = Color(0x66FFFFFF);
  static const white20 = Color(0x33FFFFFF);
  static const white10 = Color(0x1AFFFFFF);

  // Tube liquid colors (8 distinct neon shades)
  static const List<Color> liquidColors = [
    Color(0xFF00C8FF), // cyan
    Color(0xFFB400FF), // purple
    Color(0xFF00FF96), // green
    Color(0xFFFF8C00), // orange
    Color(0xFFFF0099), // pink
    Color(0xFFFFE600), // yellow
    Color(0xFFFF2D55), // red
    Color(0xFF00FFD1), // teal
    Color(0xFF7B61FF), // indigo
    Color(0xFF39FF14), // lime
    Color(0xFFFF6B6B), // coral
    Color(0xFF4ECDC4), // mint
  ];

  static const gradientPrimary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00C8FF), Color(0xFFB400FF)],
  );

  static const gradientBg = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0A0E23), Color(0xFF0D1530)],
  );
}

class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.neonBlue,
        secondary: AppColors.neonPurple,
        surface: AppColors.bgCard,
        background: AppColors.bg,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
}
