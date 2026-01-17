import 'dart:convert';
import 'package:drift/drift.dart';
import '../database.dart';
import '../../../core/utils/logger.dart';

/// Repository for Anime operations
class AnimeRepository {
  AnimeRepository._();
  static final AnimeRepository instance = AnimeRepository._();

  AppDatabase get _db => AppDatabase.instance;

  /// Get all bookmarked anime
  Future<List<Anime>> getBookmarkedAnime() async {
    return (_db.select(_db.animes)
          ..where((a) => a.isBookmarked.equals(true))
          ..orderBy([(a) => OrderingTerm.desc(a.lastWatchedAt)]))
        .get();
  }

  /// Get anime by unique animeId
  Future<Anime?> getByAnimeId(String animeId) async {
    return (_db.select(_db.animes)..where((a) => a.animeId.equals(animeId)))
        .getSingleOrNull();
  }

  /// Get anime by database id
  Future<Anime?> getById(int id) async {
    return (_db.select(_db.animes)..where((a) => a.id.equals(id)))
        .getSingleOrNull();
  }

  /// Save or update anime
  Future<int> save(AnimesCompanion anime) async {
    return _db.into(_db.animes).insertOnConflictUpdate(anime);
  }

  /// Upsert anime (update if exists, insert if not)
  Future<Anime> upsert({
    required String animeId,
    required String title,
    String? titleHindi,
    String? coverUrl,
    String? bannerUrl,
    String? description,
    String? releaseYear,
    String? status,
    String? type,
    List<String>? genres,
    int? totalEpisodes,
    int? rating,
  }) async {
    final existing = await getByAnimeId(animeId);
    
    final companion = AnimesCompanion(
      id: existing != null ? Value(existing.id) : const Value.absent(),
      animeId: Value(animeId),
      title: Value(title),
      titleHindi: Value(titleHindi),
      coverUrl: Value(coverUrl),
      bannerUrl: Value(bannerUrl),
      description: Value(description),
      releaseYear: Value(releaseYear),
      status: Value(status),
      type: Value(type),
      genres: Value(jsonEncode(genres ?? [])),
      totalEpisodes: Value(totalEpisodes),
      rating: Value(rating),
      cachedAt: Value(DateTime.now()),
      // Preserve existing values
      isBookmarked: existing != null ? Value(existing.isBookmarked) : const Value(false),
      lastWatchedAt: existing != null ? Value(existing.lastWatchedAt) : const Value.absent(),
      lastWatchedEpisode: existing != null ? Value(existing.lastWatchedEpisode) : const Value(0),
      lastWatchedPosition: existing != null ? Value(existing.lastWatchedPosition) : const Value(0),
      addedAt: existing != null ? Value(existing.addedAt) : Value(DateTime.now()),
    );

    await save(companion);
    return (await getByAnimeId(animeId))!;
  }

  /// Toggle bookmark status
  Future<bool> toggleBookmark(String animeId) async {
    final anime = await getByAnimeId(animeId);
    if (anime == null) return false;

    final newValue = !anime.isBookmarked;
    await (_db.update(_db.animes)..where((a) => a.animeId.equals(animeId)))
        .write(AnimesCompanion(
      isBookmarked: Value(newValue),
      addedAt: newValue ? Value(DateTime.now()) : Value(anime.addedAt),
    ));

    AppLogger.i('Anime $animeId bookmark: $newValue');
    return newValue;
  }

  /// Update watch progress
  Future<void> updateWatchProgress(
    String animeId, {
    required int episodeNumber,
    required int position,
  }) async {
    await (_db.update(_db.animes)..where((a) => a.animeId.equals(animeId)))
        .write(AnimesCompanion(
      lastWatchedEpisode: Value(episodeNumber),
      lastWatchedPosition: Value(position),
      lastWatchedAt: Value(DateTime.now()),
    ));
  }

  /// Delete anime and related episodes
  Future<void> delete(String animeId) async {
    await (_db.delete(_db.episodes)..where((e) => e.animeId.equals(animeId))).go();
    await (_db.delete(_db.animes)..where((a) => a.animeId.equals(animeId))).go();
    AppLogger.i('Deleted anime: $animeId');
  }

  /// Search anime by title
  Future<List<Anime>> search(String query) async {
    if (query.isEmpty) return [];
    final pattern = '%$query%';
    return (_db.select(_db.animes)
          ..where((a) =>
              a.title.like(pattern) | a.titleHindi.like(pattern)))
        .get();
  }

  /// Get recently watched anime
  Future<List<Anime>> getRecentlyWatched({int limit = 10}) async {
    return (_db.select(_db.animes)
          ..where((a) => a.lastWatchedAt.isNotNull())
          ..orderBy([(a) => OrderingTerm.desc(a.lastWatchedAt)])
          ..limit(limit))
        .get();
  }

  /// Get anime with downloaded episodes
  Future<List<Anime>> getDownloadedAnime() async {
    final query = _db.selectOnly(_db.downloadTasks, distinct: true)
      ..addColumns([_db.downloadTasks.animeId])
      ..where(_db.downloadTasks.status.equals('completed'));

    final results = await query.get();
    final animeIds = results.map((r) => r.read(_db.downloadTasks.animeId)!).toSet().toList();

    if (animeIds.isEmpty) return [];

    return (_db.select(_db.animes)..where((a) => a.animeId.isIn(animeIds))).get();
  }

  /// Count total bookmarked anime
  Future<int> countBookmarked() async {
    final count = _db.animes.id.count();
    final query = _db.selectOnly(_db.animes)
      ..addColumns([count])
      ..where(_db.animes.isBookmarked.equals(true));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }
}
