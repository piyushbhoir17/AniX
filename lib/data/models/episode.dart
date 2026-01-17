import 'package:isar/isar.dart';

part 'episode.g.dart';

@collection
class Episode {
  Id id = Isar.autoIncrement;

  @Index()
  late String animeId; // Reference to parent anime

  @Index(unique: true, composite: [CompositeIndex('animeId')])
  late int episodeNumber;

  late String title;
  String? thumbnail;
  String? sourceUrl; // URL to episode page for scraping

  // Duration in seconds
  int? duration;

  // Watch progress
  int watchedPosition = 0; // Position in seconds
  bool isWatched = false;
  DateTime? watchedAt;

  // Download status
  @enumerated
  DownloadStatus downloadStatus = DownloadStatus.none;
  
  String? downloadPath; // Local path to downloaded episode folder

  Episode();

  factory Episode.create({
    required String animeId,
    required int episodeNumber,
    required String title,
    String? thumbnail,
    String? sourceUrl,
    int? duration,
  }) {
    return Episode()
      ..animeId = animeId
      ..episodeNumber = episodeNumber
      ..title = title
      ..thumbnail = thumbnail
      ..sourceUrl = sourceUrl
      ..duration = duration;
  }

  /// Get watch progress as percentage (0.0 - 1.0)
  double get watchProgress {
    if (duration == null || duration == 0) return 0.0;
    return (watchedPosition / duration!).clamp(0.0, 1.0);
  }

  /// Check if episode is partially watched (more than 5% but less than 90%)
  bool get isPartiallyWatched {
    final progress = watchProgress;
    return progress > 0.05 && progress < 0.90;
  }

  /// Mark episode as watched
  void markAsWatched() {
    isWatched = true;
    watchedAt = DateTime.now();
    if (duration != null) {
      watchedPosition = duration!;
    }
  }

  @override
  String toString() => 'Episode(animeId: $animeId, ep: $episodeNumber, title: $title)';
}

/// Download status enum
enum DownloadStatus {
  none,
  queued,
  downloading,
  paused,
  completed,
  failed,
}
