import 'package:isar/isar.dart';
import '../database.dart';
import '../../models/episode.dart';
import '../../../core/utils/logger.dart';

/// Repository for Episode operations
class EpisodeRepository {
  EpisodeRepository._();
  static final EpisodeRepository instance = EpisodeRepository._();

  Isar get _db => AppDatabase.instance;

  /// Get all episodes for an anime
  Future<List<Episode>> getEpisodesForAnime(String animeId) async {
    return _db.episodes
        .filter()
        .animeIdEqualTo(animeId)
        .sortByEpisodeNumber()
        .findAll();
  }

  /// Get specific episode
  Future<Episode?> getEpisode(String animeId, int episodeNumber) async {
    return _db.episodes
        .filter()
        .animeIdEqualTo(animeId)
        .episodeNumberEqualTo(episodeNumber)
        .findFirst();
  }

  /// Get episode by database id
  Future<Episode?> getById(int id) async {
    return _db.episodes.get(id);
  }

  /// Save or update episode
  Future<int> save(Episode episode) async {
    return _db.writeTxn(() async {
      return _db.episodes.put(episode);
    });
  }

  /// Save multiple episodes
  Future<void> saveAll(List<Episode> episodes) async {
    await _db.writeTxn(() async {
      await _db.episodes.putAll(episodes);
    });
  }

  /// Upsert episode (update if exists, insert if not)
  Future<Episode> upsert(Episode episode) async {
    final existing = await getEpisode(episode.animeId, episode.episodeNumber);
    if (existing != null) {
      // Preserve watch progress and download status
      episode.id = existing.id;
      episode.watchedPosition = existing.watchedPosition;
      episode.isWatched = existing.isWatched;
      episode.watchedAt = existing.watchedAt;
      episode.downloadStatus = existing.downloadStatus;
      episode.downloadPath = existing.downloadPath;
    }
    await save(episode);
    return episode;
  }

  /// Update watch progress
  Future<void> updateWatchProgress(
    String animeId,
    int episodeNumber, {
    required int position,
    int? duration,
  }) async {
    final episode = await getEpisode(animeId, episodeNumber);
    if (episode == null) return;

    episode.watchedPosition = position;
    if (duration != null) {
      episode.duration = duration;
    }
    
    // Mark as watched if progress > 90%
    if (episode.watchProgress > 0.9) {
      episode.markAsWatched();
    }
    
    await save(episode);
  }

  /// Mark episode as watched
  Future<void> markAsWatched(String animeId, int episodeNumber) async {
    final episode = await getEpisode(animeId, episodeNumber);
    if (episode == null) return;

    episode.markAsWatched();
    await save(episode);
    AppLogger.i('Marked as watched: $animeId ep $episodeNumber');
  }

  /// Update download status
  Future<void> updateDownloadStatus(
    String animeId,
    int episodeNumber, {
    required DownloadStatus status,
    String? downloadPath,
  }) async {
    final episode = await getEpisode(animeId, episodeNumber);
    if (episode == null) return;

    episode.downloadStatus = status;
    if (downloadPath != null) {
      episode.downloadPath = downloadPath;
    }
    await save(episode);
  }

  /// Get downloaded episodes for an anime
  Future<List<Episode>> getDownloadedEpisodes(String animeId) async {
    return _db.episodes
        .filter()
        .animeIdEqualTo(animeId)
        .downloadStatusEqualTo(DownloadStatus.completed)
        .sortByEpisodeNumber()
        .findAll();
  }

  /// Get next unwatched episode
  Future<Episode?> getNextUnwatched(String animeId) async {
    return _db.episodes
        .filter()
        .animeIdEqualTo(animeId)
        .isWatchedEqualTo(false)
        .sortByEpisodeNumber()
        .findFirst();
  }

  /// Get continue watching episode (last partially watched)
  Future<Episode?> getContinueWatching(String animeId) async {
    final episodes = await _db.episodes
        .filter()
        .animeIdEqualTo(animeId)
        .watchedPositionGreaterThan(0)
        .isWatchedEqualTo(false)
        .sortByEpisodeNumberDesc()
        .findAll();

    return episodes.isNotEmpty ? episodes.first : null;
  }

  /// Delete all episodes for an anime
  Future<void> deleteForAnime(String animeId) async {
    await _db.writeTxn(() async {
      await _db.episodes.filter().animeIdEqualTo(animeId).deleteAll();
    });
    AppLogger.i('Deleted episodes for anime: $animeId');
  }

  /// Count episodes for an anime
  Future<int> countForAnime(String animeId) async {
    return _db.episodes.filter().animeIdEqualTo(animeId).count();
  }

  /// Count watched episodes for an anime
  Future<int> countWatchedForAnime(String animeId) async {
    return _db.episodes
        .filter()
        .animeIdEqualTo(animeId)
        .isWatchedEqualTo(true)
        .count();
  }
}
