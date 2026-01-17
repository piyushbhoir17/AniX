import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'providers/app_providers.dart';
import 'features/main/main_screen.dart';
import 'features/permissions/permissions_screen.dart';

/// Main app widget
class AniXApp extends ConsumerWidget {
  const AniXApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final themeMode = ref.watch(themeModeProvider);

    // Show loading while settings are being fetched
    if (settings == null) {
      return MaterialApp(
        title: 'AniX',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp(
      title: 'AniX',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: settings.isFirstLaunch
          ? const PermissionsScreen()
          : const MainScreen(),
    );
  }
}
