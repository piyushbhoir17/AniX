import 'package:isar/isar.dart';

part 'app_settings.g.dart';

@collection
class AppSettings {
  Id id = Isar.autoIncrement;

  // Theme
  @enumerated
  ThemeMode themeMode = ThemeMode.system;

  // Default streaming/download preferences
  String? defaultQuality; // e.g., "1080p", "720p", "480p"
  String? defaultLanguage; // e.g., "Hindi", "Japanese"
  bool saveQualityPreference = false;
  bool saveLanguagePreference = false;

  // Download settings
  int parallelDownloads = 2; // Number of parallel episode downloads
  int parallelSegments = 4; // Number of parallel segment downloads per episode
  bool downloadOnWifiOnly = false;
  bool autoResumeDownloads = true;

  // Storage
  String? safFolderUri; // SAF folder URI for downloads
  String? downloadPath; // Resolved download path

  // Permissions
  bool notificationPermissionGranted = false;
  bool storagePermissionGranted = false;
  bool permissionsSkipped = false;

  // App state
  bool isFirstLaunch = true;
  DateTime? lastOpenedAt;

  // Player settings
  bool autoPlayNext = true;
  double playbackSpeed = 1.0;
  bool rememberPlaybackPosition = true;

  AppSettings();

  /// Create default settings
  factory AppSettings.defaults() {
    return AppSettings()
      ..themeMode = ThemeMode.system
      ..parallelDownloads = 2
      ..parallelSegments = 4
      ..downloadOnWifiOnly = false
      ..autoResumeDownloads = true
      ..isFirstLaunch = true
      ..autoPlayNext = true
      ..playbackSpeed = 1.0
      ..rememberPlaybackPosition = true;
  }

  /// Check if app can download (has permissions or skipped)
  bool get canDownload => 
      (storagePermissionGranted && safFolderUri != null) || 
      !permissionsSkipped;

  /// Check if all required permissions are granted
  bool get hasAllPermissions => 
      notificationPermissionGranted && 
      storagePermissionGranted && 
      safFolderUri != null;

  @override
  String toString() => 'AppSettings(theme: $themeMode, quality: $defaultQuality, language: $defaultLanguage)';
}

/// Theme mode enum (matches Flutter's ThemeMode)
enum ThemeMode {
  system,
  light,
  dark,
}
