import 'package:drift/drift.dart';
import '../database.dart';
import '../../../core/utils/logger.dart';

/// Repository for App Settings operations
class SettingsRepository {
  SettingsRepository._();
  static final SettingsRepository instance = SettingsRepository._();

  AppDatabase get _db => AppDatabase.instance;

  /// Get current settings (always returns first row)
  Future<AppSettingsTableData> getSettings() async {
    final result = await _db.select(_db.appSettingsTable).getSingleOrNull();
    if (result == null) {
      // Create default settings if not exists
      await _db.into(_db.appSettingsTable).insert(AppSettingsTableCompanion.insert());
      return (await _db.select(_db.appSettingsTable).getSingle());
    }
    return result;
  }

  /// Update settings
  Future<void> _updateSettings(AppSettingsTableCompanion settings) async {
    final current = await getSettings();
    await (_db.update(_db.appSettingsTable)..where((s) => s.id.equals(current.id)))
        .write(settings);
    AppLogger.i('Settings updated');
  }

  /// Update theme mode
  Future<void> setThemeMode(String mode) async {
    await _updateSettings(AppSettingsTableCompanion(themeMode: Value(mode)));
  }

  /// Update default quality
  Future<void> setDefaultQuality(String? quality, {bool save = false}) async {
    await _updateSettings(AppSettingsTableCompanion(
      defaultQuality: Value(quality),
      saveQualityPreference: Value(save),
    ));
  }

  /// Update default language
  Future<void> setDefaultLanguage(String? language, {bool save = false}) async {
    await _updateSettings(AppSettingsTableCompanion(
      defaultLanguage: Value(language),
      saveLanguagePreference: Value(save),
    ));
  }

  /// Update SAF folder
  Future<void> setSafFolder(String? uri, String? path) async {
    await _updateSettings(AppSettingsTableCompanion(
      safFolderUri: Value(uri),
      downloadPath: Value(path),
      storagePermissionGranted: Value(uri != null),
    ));
  }

  /// Update notification permission status
  Future<void> setNotificationPermission(bool granted) async {
    await _updateSettings(AppSettingsTableCompanion(
      notificationPermissionGranted: Value(granted),
    ));
  }

  /// Mark permissions as skipped
  Future<void> setPermissionsSkipped(bool skipped) async {
    await _updateSettings(AppSettingsTableCompanion(
      permissionsSkipped: Value(skipped),
    ));
  }

  /// Mark first launch complete
  Future<void> setFirstLaunchComplete() async {
    await _updateSettings(AppSettingsTableCompanion(
      isFirstLaunch: const Value(false),
      lastOpenedAt: Value(DateTime.now()),
    ));
  }

  /// Update last opened timestamp
  Future<void> updateLastOpened() async {
    await _updateSettings(AppSettingsTableCompanion(
      lastOpenedAt: Value(DateTime.now()),
    ));
  }

  /// Update download settings
  Future<void> setDownloadSettings({
    int? parallelDownloads,
    int? parallelSegments,
    bool? downloadOnWifiOnly,
    bool? autoResumeDownloads,
  }) async {
    await _updateSettings(AppSettingsTableCompanion(
      parallelDownloads: parallelDownloads != null ? Value(parallelDownloads) : const Value.absent(),
      parallelSegments: parallelSegments != null ? Value(parallelSegments) : const Value.absent(),
      downloadOnWifiOnly: downloadOnWifiOnly != null ? Value(downloadOnWifiOnly) : const Value.absent(),
      autoResumeDownloads: autoResumeDownloads != null ? Value(autoResumeDownloads) : const Value.absent(),
    ));
  }

  /// Update player settings
  Future<void> setPlayerSettings({
    bool? autoPlayNext,
    double? playbackSpeed,
    bool? rememberPlaybackPosition,
  }) async {
    await _updateSettings(AppSettingsTableCompanion(
      autoPlayNext: autoPlayNext != null ? Value(autoPlayNext) : const Value.absent(),
      playbackSpeed: playbackSpeed != null ? Value(playbackSpeed) : const Value.absent(),
      rememberPlaybackPosition: rememberPlaybackPosition != null ? Value(rememberPlaybackPosition) : const Value.absent(),
    ));
  }
}
