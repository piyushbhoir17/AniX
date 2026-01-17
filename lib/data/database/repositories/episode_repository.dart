import 'package:drift/drift.dart';
import '../database.dart';
import '../../../core/utils/logger.dart';

/// Repository for Episode operations
class EpisodeRepository {
  EpisodeRepository._();
  static final EpisodeRepository instance = EpisodeRepository._();

  AppDatabase get _db => AppDatabase.instance;

  /// Get all episodes for an anime
  Future<List<Episode>> getEpisodesForAnime(String animeId) async {
    return (_db.select(_db.episodes)
          ..where((e) => e.animeId.equals(animeId))
          ..orderBy([(e) => OrderingTerm.asc(e.episodeNumber)]))
        .get();
  }

  /// Get specific episode
  Future<Episode?> getEpisode(String animeId, int episodeNumber) async {
    return (_db.select(_db.episodes)
          ..where((e) => e.animeId.equals(animeId) & e.episodeNumber.equals(episodeNumber)))
        .getSingleOrNull();
  }

  /// Get episode by database id
  Future<Episode?> getById(int id) async {
    return (_db.select(_db.episodes)..where((e) => e.id.equals(id)))
        .getSingleOrNull();
  }

  /// Save or update episode
  Future<int> save(EpisodesCompanion episode) async {
    return _db.into(_db.episodes).insertOnConflictUpdate(episode);
  }

  /// Save multiple episodes
  Future<void> saveAll(List<EpisodesCompanion> episodes) async {
    await _db.batch((batch) {
      for (final episode in episodes) {
        batch.insert(_db.episodes, episode, onConflict: DoUpdate((old) => episode));
      }
    });
  }

  /// Upsert episode
  Future<Episode> upsert({
    required String animeId,
    required int episodeNumber,
    required String title,
    String? thumbnail,
    String? sourceUrl,
    int? duration,
  }) async {
    final existing = await getEpisode(animeId, episodeNumber);

    final companion = EpisodesCompanion(
      id: existing != null ? Value(existing.id) : const Value.absent(),
      animeId: Value(animeId),
      episodeNumber: Value(episodeNumber),
      title: Value(title),
      thumbnail: Value(thumbnail),
      sourceUrl: Value(sourceUrl),
      duration: Value(duration),
      // Preserve existing values
      watchedPosition: existing != null ? Value(existing.watchedPosition) : const Value(0),
      isWatched: existing != null ? Value(existing.isWatched) : const Value(false),
      watchedAt: existing != null ? Value(existing.watchedAt) : const Value.absent(),
      downloadStatus: existing != null ? Value(existing.downloadStatus) : const Value('none'),
      downloadPath: existing != null ? Value(existing.downloadPath) : const Value.absent(),
    );

    await save(companion);
    return (await getEpisode(animeId, episodeNumber))!;
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

    final effectiveDuration = duration ?? episode.duration ?? 0;
    final progress = effectiveDuration > 0 ? position / effectiveDuration : 0.0;
    final isWatched = progress > 0.9;

    await (_db.update(_db.episodes)
          ..where((e) => e.animeId.equals(animeId) & e.episodeNumber.equals(episodeNumber)))
        .write(EpisodesCompanion(
      watchedPosition: Value(position),
      duration: duration != null ? Value(duration) : const Value.absent(),
      isWatched: Value(isWatched),
      watchedAt: isWatched ? Value(DateTime.now()) : const Value.absent(),
    ));
  }

  /// Mark episode as watched
  Future<void> markAsWatched(String animeId, int episodeNumber) async {
    final episode = await getEpisode(animeId, episodeNumber);
    if (episode == null) return;

    await (_db.update(_db.episodes)
          ..where((e) => e.animeId.equals(animeId) & e.episodeNumber.equals(episodeNumber)))
        .write(EpisodesCompanion(
      isWatched: const Value(true),
      watchedAt: Value(DateTime.now()),
      watchedPosition: episode.duration != null ? Value(episode.duration!) : const Value.absent(),
    ));

    AppLogger.i('Marked as watched: $animeId ep $episodeNumber');
  }

  /// Update download status
  Future<void> updateDownloadStatus(
    String animeId,
    int episodeNumber, {
    required String status,
    String? downloadPath,
  }) async {
    await (_db.update(_db.episodes)
          ..where((e) => e.animeId.equals(animeId) & e.episodeNumber.equals(episodeNumber)))
        .write(EpisodesCompanion(
      downloadStatus: Value(status),
      downloadPath: downloadPath != null ? Value(downloadPath) : const Value.absent(),
    ));
  }

  /// Get downloaded episodes for an anime
  Future<List<Episode>> getDownloadedEpisodes(String animeId) async {
    return (_db.select(_db.episodes)
          ..where((e) => e.animeId.equals(animeId) & e.downloadStatus.equals('completed'))
          ..orderBy([(e) => OrderingTerm.asc(e.episodeNumber)]))
        .get();
  }

  /// Get next unwatched episode
  Future<Episode?> getNextUnwatched(String animeId) async {
    return (_db.select(_db.episodes)
          ..where((e) => e.animeId.equals(animeId) & e.isWatched.equals(false))
          ..orderBy([(e) => OrderingTerm.asc(e.episodeNumber)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Delete all episodes for an anime
  Future<void> deleteForAnime(String animeId) async {
    await (_db.delete(_db.episodes)..where((e) => e.animeId.equals(animeId))).go();
    AppLogger.i('Deleted episodes for anime: $animeId');
  }

  /// Count episodes for an anime
  Future<int> countForAnime(String animeId) async {
    final count = _db.episodes.id.count();
    final query = _db.selectOnly(_db.episodes)
      ..addColumns([count])
      ..where(_db.episodes.animeId.equals(animeId));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }
}
