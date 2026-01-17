import 'package:isar/isar.dart';
import '../database.dart';
import '../../models/app_settings.dart';
import '../../../core/utils/logger.dart';

/// Repository for App Settings operations
class SettingsRepository {
  SettingsRepository._();
  static final SettingsRepository instance = SettingsRepository._();

  Isar get _db => AppDatabase.instance;

  /// Get current settings
  Future<AppSettings> getSettings() async {
    final settings = await _db.appSettings.where().findFirst();
    return settings ?? AppSettings.defaults();
  }

  /// Save settings
  Future<void> saveSettings(AppSettings settings) async {
    await _db.writeTxn(() async {
      await _db.appSettings.put(settings);
    });
    AppLogger.i('Settings saved');
  }

  /// Update theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    final settings = await getSettings();
    settings.themeMode = mode;
    await saveSettings(settings);
  }

  /// Update default quality
  Future<void> setDefaultQuality(String? quality, {bool save = false}) async {
    final settings = await getSettings();
    settings.defaultQuality = quality;
    settings.saveQualityPreference = save;
    await saveSettings(settings);
  }

  /// Update default language
  Future<void> setDefaultLanguage(String? language, {bool save = false}) async {
    final settings = await getSettings();
    settings.defaultLanguage = language;
    settings.saveLanguagePreference = save;
    await saveSettings(settings);
  }

  /// Update SAF folder
  Future<void> setSafFolder(String? uri, String? path) async {
    final settings = await getSettings();
    settings.safFolderUri = uri;
    settings.downloadPath = path;
    settings.storagePermissionGranted = uri != null;
    await saveSettings(settings);
  }

  /// Update notification permission status
  Future<void> setNotificationPermission(bool granted) async {
    final settings = await getSettings();
    settings.notificationPermissionGranted = granted;
    await saveSettings(settings);
  }

  /// Mark permissions as skipped
  Future<void> setPermissionsSkipped(bool skipped) async {
    final settings = await getSettings();
    settings.permissionsSkipped = skipped;
    await saveSettings(settings);
  }

  /// Mark first launch complete
  Future<void> setFirstLaunchComplete() async {
    final settings = await getSettings();
    settings.isFirstLaunch = false;
    settings.lastOpenedAt = DateTime.now();
    await saveSettings(settings);
  }

  /// Update last opened timestamp
  Future<void> updateLastOpened() async {
    final settings = await getSettings();
    settings.lastOpenedAt = DateTime.now();
    await saveSettings(settings);
  }

  /// Update download settings
  Future<void> setDownloadSettings({
    int? parallelDownloads,
    int? parallelSegments,
    bool? downloadOnWifiOnly,
    bool? autoResumeDownloads,
  }) async {
    final settings = await getSettings();
    if (parallelDownloads != null) settings.parallelDownloads = parallelDownloads;
    if (parallelSegments != null) settings.parallelSegments = parallelSegments;
    if (downloadOnWifiOnly != null) settings.downloadOnWifiOnly = downloadOnWifiOnly;
    if (autoResumeDownloads != null) settings.autoResumeDownloads = autoResumeDownloads;
    await saveSettings(settings);
  }

  /// Update player settings
  Future<void> setPlayerSettings({
    bool? autoPlayNext,
    double? playbackSpeed,
    bool? rememberPlaybackPosition,
  }) async {
    final settings = await getSettings();
    if (autoPlayNext != null) settings.autoPlayNext = autoPlayNext;
    if (playbackSpeed != null) settings.playbackSpeed = playbackSpeed;
    if (rememberPlaybackPosition != null) settings.rememberPlaybackPosition = rememberPlaybackPosition;
    await saveSettings(settings);
  }
}
