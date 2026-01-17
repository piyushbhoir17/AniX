import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../core/utils/logger.dart';

part 'database.g.dart';

// ============ Table Definitions ============

/// Anime table
class Animes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get animeId => text().unique()();
  TextColumn get title => text()();
  TextColumn get titleHindi => text().nullable()();
  TextColumn get coverUrl => text().nullable()();
  TextColumn get bannerUrl => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get releaseYear => text().nullable()();
  TextColumn get status => text().nullable()();
  TextColumn get type => text().nullable()();
  TextColumn get genres => text().withDefault(const Constant('[]'))(); // JSON array
  IntColumn get totalEpisodes => integer().nullable()();
  IntColumn get rating => integer().nullable()();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastWatchedAt => dateTime().nullable()();
  BoolColumn get isBookmarked => boolean().withDefault(const Constant(false))();
  DateTimeColumn get cachedAt => dateTime().nullable()();
  IntColumn get lastWatchedEpisode => integer().withDefault(const Constant(0))();
  IntColumn get lastWatchedPosition => integer().withDefault(const Constant(0))();
}

/// Episodes table
class Episodes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get animeId => text().references(Animes, #animeId)();
  IntColumn get episodeNumber => integer()();
  TextColumn get title => text()();
  TextColumn get thumbnail => text().nullable()();
  TextColumn get sourceUrl => text().nullable()();
  IntColumn get duration => integer().nullable()();
  IntColumn get watchedPosition => integer().withDefault(const Constant(0))();
  BoolColumn get isWatched => boolean().withDefault(const Constant(false))();
  DateTimeColumn get watchedAt => dateTime().nullable()();
  TextColumn get downloadStatus => text().withDefault(const Constant('none'))();
  TextColumn get downloadPath => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {animeId, episodeNumber}
      ];
}

/// Download tasks table
class DownloadTasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get taskId => text().unique()();
  TextColumn get animeId => text()();
  TextColumn get animeTitle => text()();
  IntColumn get episodeNumber => integer()();
  TextColumn get episodeTitle => text()();
  TextColumn get masterM3u8Url => text()();
  TextColumn get selectedQuality => text().nullable()();
  TextColumn get selectedLanguage => text().nullable()();
  TextColumn get audioGroupId => text().nullable()();
  TextColumn get downloadFolder => text()();
  TextColumn get segmentListPath => text().nullable()();
  IntColumn get totalSegments => integer().withDefault(const Constant(0))();
  IntColumn get downloadedSegments => integer().withDefault(const Constant(0))();
  IntColumn get totalBytes => integer().withDefault(const Constant(0))();
  IntColumn get downloadedBytes => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('queued'))();
  TextColumn get errorMessage => text().nullable()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get pausedAt => dateTime().nullable()();
  TextColumn get cookies => text().nullable()();
  TextColumn get referer => text().nullable()();
}

/// Download segments table
class DownloadSegments extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get taskId => text().references(DownloadTasks, #taskId)();
  IntColumn get segmentIndex => integer()();
  TextColumn get segmentUrl => text()();
  TextColumn get localPath => text()();
  RealColumn get duration => real().nullable()();
  IntColumn get fileSize => integer().nullable()();
  IntColumn get downloadedBytes => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get errorMessage => text().nullable()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {taskId, segmentIndex}
      ];
}

/// App settings table
class AppSettingsTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get themeMode => text().withDefault(const Constant('system'))();
  TextColumn get defaultQuality => text().nullable()();
  TextColumn get defaultLanguage => text().nullable()();
  BoolColumn get saveQualityPreference => boolean().withDefault(const Constant(false))();
  BoolColumn get saveLanguagePreference => boolean().withDefault(const Constant(false))();
  IntColumn get parallelDownloads => integer().withDefault(const Constant(2))();
  IntColumn get parallelSegments => integer().withDefault(const Constant(4))();
  BoolColumn get downloadOnWifiOnly => boolean().withDefault(const Constant(false))();
  BoolColumn get autoResumeDownloads => boolean().withDefault(const Constant(true))();
  TextColumn get safFolderUri => text().nullable()();
  TextColumn get downloadPath => text().nullable()();
  BoolColumn get notificationPermissionGranted => boolean().withDefault(const Constant(false))();
  BoolColumn get storagePermissionGranted => boolean().withDefault(const Constant(false))();
  BoolColumn get permissionsSkipped => boolean().withDefault(const Constant(false))();
  BoolColumn get isFirstLaunch => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastOpenedAt => dateTime().nullable()();
  BoolColumn get autoPlayNext => boolean().withDefault(const Constant(true))();
  RealColumn get playbackSpeed => real().withDefault(const Constant(1.0))();
  BoolColumn get rememberPlaybackPosition => boolean().withDefault(const Constant(true))();

  @override
  String get tableName => 'app_settings';
}

// ============ Database Class ============

@DriftDatabase(tables: [Animes, Episodes, DownloadTasks, DownloadSegments, AppSettingsTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase._() : super(_openConnection());

  static AppDatabase? _instance;

  static AppDatabase get instance {
    _instance ??= AppDatabase._();
    return _instance!;
  }

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        // Insert default settings
        await into(appSettingsTable).insert(AppSettingsTableCompanion.insert());
        AppLogger.i('Database created with default settings');
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Handle future migrations here
      },
    );
  }

  /// Close the database
  static Future<void> close() async {
    await _instance?.close();
    _instance = null;
    AppLogger.i('Database closed');
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'anix_db.sqlite'));
    AppLogger.i('Database path: ${file.path}');
    return NativeDatabase.createInBackground(file);
  });
}
