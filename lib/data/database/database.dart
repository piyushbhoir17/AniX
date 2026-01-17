import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/anime.dart';
import '../models/episode.dart';
import '../models/download_task.dart';
import '../models/download_segment.dart';
import '../models/app_settings.dart';
import '../../core/utils/logger.dart';

/// Database singleton for Isar
class AppDatabase {
  AppDatabase._();

  static Isar? _instance;
  static bool _isInitialized = false;

  /// Get Isar instance
  static Isar get instance {
    if (_instance == null) {
      throw Exception('Database not initialized. Call AppDatabase.initialize() first.');
    }
    return _instance!;
  }

  /// Check if database is initialized
  static bool get isInitialized => _isInitialized;

  /// Initialize the database
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final dir = await getApplicationDocumentsDirectory();
      
      _instance = await Isar.open(
        [
          AnimeSchema,
          EpisodeSchema,
          DownloadTaskSchema,
          DownloadSegmentSchema,
          AppSettingsSchema,
        ],
        directory: dir.path,
        name: 'anix_db',
      );

      _isInitialized = true;
      AppLogger.i('Database initialized successfully');

      // Ensure default settings exist
      await _ensureDefaultSettings();
    } catch (e, stack) {
      AppLogger.e('Failed to initialize database', e, stack);
      rethrow;
    }
  }

  /// Ensure default settings exist in database
  static Future<void> _ensureDefaultSettings() async {
    final settings = await _instance!.appSettings.where().findFirst();
    if (settings == null) {
      await _instance!.writeTxn(() async {
        await _instance!.appSettings.put(AppSettings.defaults());
      });
      AppLogger.i('Default settings created');
    }
  }

  /// Close the database
  static Future<void> close() async {
    if (_instance != null) {
      await _instance!.close();
      _instance = null;
      _isInitialized = false;
      AppLogger.i('Database closed');
    }
  }

  /// Clear all data (for debugging/reset)
  static Future<void> clearAll() async {
    if (_instance != null) {
      await _instance!.writeTxn(() async {
        await _instance!.clear();
      });
      await _ensureDefaultSettings();
      AppLogger.w('All database data cleared');
    }
  }
}
