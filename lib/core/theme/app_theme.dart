import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

/// App theme configuration with Material You and Dracula styling
class AppTheme {
  AppTheme._();

  // Border radius used throughout the app
  static const double borderRadius = 16.0;
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(borderRadius));

  /// Dark theme (Dracula)
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: AppColors.draculaPurple,
        secondary: AppColors.draculaPink,
        tertiary: AppColors.draculaCyan,
        surface: AppColors.draculaBackground,
        error: AppColors.draculaRed,
        onPrimary: AppColors.draculaBackground,
        onSecondary: AppColors.draculaBackground,
        onSurface: AppColors.draculaForeground,
        onError: AppColors.draculaForeground,
        outline: AppColors.draculaComment,
      ),
      scaffoldBackgroundColor: AppColors.draculaBackground,
      cardColor: AppColors.cardDark,
      dividerColor: AppColors.draculaCurrentLine,
      
      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.draculaBackground,
        foregroundColor: AppColors.draculaForeground,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: AppColors.draculaBackground,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),

      // Cards
      cardTheme: CardTheme(
        color: AppColors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: cardRadius),
        clipBehavior: Clip.antiAlias,
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.draculaPurple,
          foregroundColor: AppColors.draculaBackground,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.draculaPurple,
          side: const BorderSide(color: AppColors.draculaPurple),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.draculaPurple,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),

      // Floating Action Button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.draculaPurple,
        foregroundColor: AppColors.draculaBackground,
        elevation: 4,
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.draculaCurrentLine,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: AppColors.draculaPurple, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // Bottom Navigation
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.draculaBackground,
        selectedItemColor: AppColors.draculaPurple,
        unselectedItemColor: AppColors.draculaComment,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // Navigation Bar (Material 3)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.draculaBackground,
        indicatorColor: AppColors.draculaPurple.withOpacity(0.2),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.draculaPurple);
          }
          return const IconThemeData(color: AppColors.draculaComment);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: AppColors.draculaPurple,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            );
          }
          return const TextStyle(
            color: AppColors.draculaComment,
            fontSize: 12,
          );
        }),
      ),

      // Progress Indicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.draculaPurple,
        linearTrackColor: AppColors.draculaCurrentLine,
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.draculaCurrentLine,
        contentTextStyle: const TextStyle(color: AppColors.draculaForeground),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),

      // Dialog
      dialogTheme: DialogTheme(
        backgroundColor: AppColors.draculaBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
      ),

      // Bottom Sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.draculaBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.draculaCurrentLine,
        selectedColor: AppColors.draculaPurple,
        labelStyle: const TextStyle(color: AppColors.draculaForeground),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      // Text Theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: AppColors.draculaForeground, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(color: AppColors.draculaForeground, fontWeight: FontWeight.bold),
        displaySmall: TextStyle(color: AppColors.draculaForeground, fontWeight: FontWeight.bold),
        headlineLarge: TextStyle(color: AppColors.draculaForeground, fontWeight: FontWeight.w600),
        headlineMedium: TextStyle(color: AppColors.draculaForeground, fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(color: AppColors.draculaForeground, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: AppColors.draculaForeground, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: AppColors.draculaForeground, fontWeight: FontWeight.w500),
        titleSmall: TextStyle(color: AppColors.draculaForeground, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: AppColors.draculaForeground),
        bodyMedium: TextStyle(color: AppColors.draculaForeground),
        bodySmall: TextStyle(color: AppColors.draculaComment),
        labelLarge: TextStyle(color: AppColors.draculaForeground, fontWeight: FontWeight.w500),
        labelMedium: TextStyle(color: AppColors.draculaForeground),
        labelSmall: TextStyle(color: AppColors.draculaComment),
      ),
    );
  }

  /// Light theme (Dracula-inspired light variant)
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: AppColors.draculaPurple,
        secondary: AppColors.draculaPink,
        tertiary: AppColors.draculaCyan,
        surface: AppColors.lightBackground,
        error: AppColors.draculaRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.lightForeground,
        onError: Colors.white,
        outline: AppColors.lightSecondary.withOpacity(0.3),
      ),
      scaffoldBackgroundColor: AppColors.lightBackground,
      cardColor: AppColors.cardLight,
      dividerColor: AppColors.lightSecondary.withOpacity(0.1),

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightBackground,
        foregroundColor: AppColors.lightForeground,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: AppColors.lightBackground,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      ),

      // Cards
      cardTheme: CardTheme(
        color: AppColors.cardLight,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: cardRadius),
        clipBehavior: Clip.antiAlias,
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.draculaPurple,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.draculaPurple,
          side: const BorderSide(color: AppColors.draculaPurple),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.draculaPurple,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),

      // Floating Action Button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.draculaPurple,
        foregroundColor: Colors.white,
        elevation: 4,
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: AppColors.draculaPurple, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // Bottom Navigation
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.lightSurface,
        selectedItemColor: AppColors.draculaPurple,
        unselectedItemColor: AppColors.lightSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // Navigation Bar (Material 3)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.lightSurface,
        indicatorColor: AppColors.draculaPurple.withOpacity(0.15),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.draculaPurple);
          }
          return IconThemeData(color: AppColors.lightSecondary);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: AppColors.draculaPurple,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            );
          }
          return TextStyle(
            color: AppColors.lightSecondary,
            fontSize: 12,
          );
        }),
      ),

      // Progress Indicator
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.draculaPurple,
        linearTrackColor: Colors.grey.shade200,
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.lightForeground,
        contentTextStyle: const TextStyle(color: AppColors.lightBackground),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),

      // Dialog
      dialogTheme: DialogTheme(
        backgroundColor: AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
      ),

      // Bottom Sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: Colors.grey.shade100,
        selectedColor: AppColors.draculaPurple,
        labelStyle: TextStyle(color: AppColors.lightForeground),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      // Text Theme
      textTheme: TextTheme(
        displayLarge: TextStyle(color: AppColors.lightForeground, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(color: AppColors.lightForeground, fontWeight: FontWeight.bold),
        displaySmall: TextStyle(color: AppColors.lightForeground, fontWeight: FontWeight.bold),
        headlineLarge: TextStyle(color: AppColors.lightForeground, fontWeight: FontWeight.w600),
        headlineMedium: TextStyle(color: AppColors.lightForeground, fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(color: AppColors.lightForeground, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: AppColors.lightForeground, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: AppColors.lightForeground, fontWeight: FontWeight.w500),
        titleSmall: TextStyle(color: AppColors.lightForeground, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: AppColors.lightForeground),
        bodyMedium: TextStyle(color: AppColors.lightForeground),
        bodySmall: TextStyle(color: AppColors.lightSecondary),
        labelLarge: TextStyle(color: AppColors.lightForeground, fontWeight: FontWeight.w500),
        labelMedium: TextStyle(color: AppColors.lightForeground),
        labelSmall: TextStyle(color: AppColors.lightSecondary),
      ),
    );
  }
}
