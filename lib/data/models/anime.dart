import 'package:isar/isar.dart';

part 'anime.g.dart';

@collection
class Anime {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String animeId; // Unique identifier from source

  late String title;
  String? titleHindi;
  String? coverUrl;
  String? bannerUrl;
  String? description;
  String? releaseYear;
  String? status; // Ongoing, Completed
  String? type; // TV, Movie, OVA, etc.
  
  List<String> genres = [];
  
  int? totalEpisodes;
  int? rating; // 1-100

  @Index()
  late DateTime addedAt;
  
  DateTime? lastWatchedAt;
  
  @Index()
  bool isBookmarked = false;

  // Cache control
  DateTime? cachedAt;
  
  // Watch progress
  int lastWatchedEpisode = 0;
  int lastWatchedPosition = 0; // Position in seconds

  Anime();

  factory Anime.create({
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
  }) {
    return Anime()
      ..animeId = animeId
      ..title = title
      ..titleHindi = titleHindi
      ..coverUrl = coverUrl
      ..bannerUrl = bannerUrl
      ..description = description
      ..releaseYear = releaseYear
      ..status = status
      ..type = type
      ..genres = genres ?? []
      ..totalEpisodes = totalEpisodes
      ..rating = rating
      ..addedAt = DateTime.now()
      ..cachedAt = DateTime.now();
  }

  /// Check if cache is expired (older than 7 days)
  bool get isCacheExpired {
    if (cachedAt == null) return true;
    return DateTime.now().difference(cachedAt!).inDays > 7;
  }

  /// Update cache timestamp
  void refreshCache() {
    cachedAt = DateTime.now();
  }

  @override
  String toString() => 'Anime(id: $id, animeId: $animeId, title: $title)';
}
