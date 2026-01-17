import 'package:isar/isar.dart';
import '../database.dart';
import '../../models/anime.dart';
import '../../../core/utils/logger.dart';

/// Repository for Anime operations
class AnimeRepository {
  AnimeRepository._();
  static final AnimeRepository instance = AnimeRepository._();

  Isar get _db => AppDatabase.instance;

  /// Get all bookmarked anime
  Future<List<Anime>> getBookmarkedAnime() async {
    return _db.animes
        .filter()
        .isBookmarkedEqualTo(true)
        .sortByLastWatchedAtDesc()
        .findAll();
  }

  /// Get anime by unique animeId
  Future<Anime?> getByAnimeId(String animeId) async {
    return _db.animes.filter().animeIdEqualTo(animeId).findFirst();
  }

  /// Get anime by database id
  Future<Anime?> getById(int id) async {
    return _db.animes.get(id);
  }

  /// Save or update anime
  Future<int> save(Anime anime) async {
    return _db.writeTxn(() async {
      return _db.animes.put(anime);
    });
  }

  /// Save or update anime (upsert by animeId)
  Future<Anime> upsert(Anime anime) async {
    final existing = await getByAnimeId(anime.animeId);
    if (existing != null) {
      // Update existing
      anime.id = existing.id;
      anime.isBookmarked = existing.isBookmarked;
      anime.lastWatchedAt = existing.lastWatchedAt;
      anime.lastWatchedEpisode = existing.lastWatchedEpisode;
      anime.lastWatchedPosition = existing.lastWatchedPosition;
      anime.addedAt = existing.addedAt;
    }
    await save(anime);
    return anime;
  }

  /// Toggle bookmark status
  Future<bool> toggleBookmark(String animeId) async {
    final anime = await getByAnimeId(animeId);
    if (anime == null) return false;

    anime.isBookmarked = !anime.isBookmarked;
    if (anime.isBookmarked) {
      anime.addedAt = DateTime.now();
    }
    await save(anime);
    AppLogger.i('Anime ${anime.title} bookmark: ${anime.isBookmarked}');
    return anime.isBookmarked;
  }

  /// Update watch progress
  Future<void> updateWatchProgress(
    String animeId, {
    required int episodeNumber,
    required int position,
  }) async {
    final anime = await getByAnimeId(animeId);
    if (anime == null) return;

    anime.lastWatchedEpisode = episodeNumber;
    anime.lastWatchedPosition = position;
    anime.lastWatchedAt = DateTime.now();
    await save(anime);
  }

  /// Delete anime and related episodes
  Future<void> delete(String animeId) async {
    await _db.writeTxn(() async {
      // Delete related episodes first
      await _db.episodes.filter().animeIdEqualTo(animeId).deleteAll();
      // Delete anime
      await _db.animes.filter().animeIdEqualTo(animeId).deleteAll();
    });
    AppLogger.i('Deleted anime: $animeId');
  }

  /// Search anime by title
  Future<List<Anime>> search(String query) async {
    if (query.isEmpty) return [];
    return _db.animes
        .filter()
        .titleContains(query, caseSensitive: false)
        .or()
        .titleHindiContains(query, caseSensitive: false)
        .findAll();
  }

  /// Get recently watched anime
  Future<List<Anime>> getRecentlyWatched({int limit = 10}) async {
    return _db.animes
        .filter()
        .lastWatchedAtIsNotNull()
        .sortByLastWatchedAtDesc()
        .limit(limit)
        .findAll();
  }

  /// Get anime with downloaded episodes
  Future<List<Anime>> getDownloadedAnime() async {
    // Get unique animeIds that have completed downloads
    final downloadedAnimeIds = await _db.downloadTasks
        .filter()
        .statusEqualTo(TaskStatus.completed)
        .animeIdProperty()
        .findAll();

    final uniqueIds = downloadedAnimeIds.toSet().toList();
    
    if (uniqueIds.isEmpty) return [];

    final result = <Anime>[];
    for (final animeId in uniqueIds) {
      final anime = await getByAnimeId(animeId);
      if (anime != null) {
        result.add(anime);
      }
    }
    return result;
  }

  /// Count total bookmarked anime
  Future<int> countBookmarked() async {
    return _db.animes.filter().isBookmarkedEqualTo(true).count();
  }

  /// Refresh anime cache
  Future<void> refreshCache(Anime anime) async {
    anime.refreshCache();
    await save(anime);
  }
}
