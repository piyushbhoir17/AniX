import 'package:flutter/material.dart' hide ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'data/models/app_settings.dart';
import 'providers/app_providers.dart';
import 'features/main/main_screen.dart';
import 'features/permissions/permissions_screen.dart';

/// Main app widget
class AniXApp extends ConsumerWidget {
  const AniXApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final themeMode = settings.themeMode;

    return MaterialApp(
      title: 'AniX',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _mapThemeMode(themeMode),
      home: settings.isFirstLaunch
          ? const PermissionsScreen()
          : const MainScreen(),
    );
  }

  ThemeMode _mapThemeMode(AppSettings_ThemeMode mode) {
    switch (mode) {
      case AppSettings_ThemeMode.light:
        return ThemeMode.light;
      case AppSettings_ThemeMode.dark:
        return ThemeMode.dark;
      case AppSettings_ThemeMode.system:
        return ThemeMode.system;
    }
  }
}

// Alias for the ThemeMode enum from app_settings
typedef AppSettings_ThemeMode = ThemeMode;
