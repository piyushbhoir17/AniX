import 'package:flutter/material.dart';

/// Dracula-inspired color palette for Material You
class AppColors {
  AppColors._();

  // Dracula Dark Theme Colors
  static const Color draculaBackground = Color(0xFF282A36);
  static const Color draculaCurrentLine = Color(0xFF44475A);
  static const Color draculaForeground = Color(0xFFF8F8F2);
  static const Color draculaComment = Color(0xFF6272A4);
  static const Color draculaCyan = Color(0xFF8BE9FD);
  static const Color draculaGreen = Color(0xFF50FA7B);
  static const Color draculaOrange = Color(0xFFFFB86C);
  static const Color draculaPink = Color(0xFFFF79C6);
  static const Color draculaPurple = Color(0xFFBD93F9);
  static const Color draculaRed = Color(0xFFFF5555);
  static const Color draculaYellow = Color(0xFFF1FA8C);

  // Light Theme Colors (Dracula-inspired light variant)
  static const Color lightBackground = Color(0xFFF8F8F2);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightForeground = Color(0xFF282A36);
  static const Color lightSecondary = Color(0xFF44475A);
  static const Color lightAccent = Color(0xFFBD93F9);

  // Semantic Colors
  static const Color success = draculaGreen;
  static const Color error = draculaRed;
  static const Color warning = draculaOrange;
  static const Color info = draculaCyan;

  // Card Colors
  static const Color cardDark = Color(0xFF343746);
  static const Color cardLight = Color(0xFFFFFFFF);

  // Gradient for accents
  static const LinearGradient accentGradient = LinearGradient(
    colors: [draculaPurple, draculaPink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
