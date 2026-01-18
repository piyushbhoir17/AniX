import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database/repositories/anime_repository.dart';
import '../data/database/repositories/episode_repository.dart';
import '../data/database/repositories/download_repository.dart';
import '../data/database/repositories/settings_repository.dart';
import '../data/models/anime.dart';
import '../data/models/anime_detail.dart';
import '../data/models/episode.dart';
import '../data/models/download_task.dart';
import '../data/models/app_settings.dart';
import '../data/services/download_manager.dart';
import '../data/services/scraper_service.dart';
import '../data/services/search_service.dart';
import '../data/services/storage_service.dart';

// ============ Repository Providers ============

final animeRepositoryProvider = Provider((ref) => AnimeRepository.instance);
final episodeRepositoryProvider = Provider((ref) => EpisodeRepository.instance);
final downloadRepositoryProvider = Provider((ref) => DownloadRepository.instance);
final settingsRepositoryProvider = Provider((ref) => SettingsRepository.instance);

// ============ Service Providers ============

final scraperServiceProvider = Provider((ref) => ScraperService.instance);
final searchServiceProvider = Provider((ref) => SearchService.instance);
final downloadManagerProvider = Provider((ref) => DownloadManager.instance);
final storageServiceProvider = Provider((ref) => StorageService.instance);

// ============ Settings Provider ============

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings?>((ref) {
  return SettingsNotifier(ref.read(settingsRepositoryProvider));
});

class SettingsNotifier extends StateNotifier<AppSettings?> {
  final SettingsRepository _repository;

  SettingsNotifier(this._repository) : super(null) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    state = await _repository.getSettings();
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    await _repository.setThemeMode(mode);
    state = await _repository.getSettings();
  }

  Future<void> setDefaultQuality(String? quality, {bool save = false}) async {
    await _repository.setDefaultQuality(quality, save: save);
    state = await _repository.getSettings();
  }

  Future<void> setDefaultLanguage(String? language, {bool save = false}) async {
    await _repository.setDefaultLanguage(language, save: save);
    state = await _repository.getSettings();
  }

  Future<void> setDownloadPath(String path) async {
    await _repository.setDownloadPath(path);
    state = await _repository.getSettings();
  }

  Future<void> setNotificationPermission(bool granted) async {
    await _repository.setNotificationPermission(granted);
    state = await _repository.getSettings();
  }

  Future<void> setPermissionsSkipped(bool skipped) async {
    await _repository.setPermissionsSkipped(skipped);
    state = await _repository.getSettings();
  }

  Future<void> completeFirstLaunch() async {
    await _repository.setFirstLaunchComplete();
    state = await _repository.getSettings();
  }

  Future<void> refresh() async {
    state = await _repository.getSettings();
  }
}

// ============ Theme Provider ============

final themeModeProvider = Provider<ThemeMode>((ref) {
  final settings = ref.watch(settingsProvider);
  if (settings == null) return ThemeMode.system;
  
  switch (settings.themeMode) {
    case AppThemeMode.light:
      return ThemeMode.light;
    case AppThemeMode.dark:
      return ThemeMode.dark;
    case AppThemeMode.system:
      return ThemeMode.system;
  }
});

// ============ Anime Providers ============

final bookmarkedAnimeProvider = FutureProvider<List<Anime>>((ref) async {
  return ref.read(animeRepositoryProvider).getBookmarkedAnime();
});

final downloadedAnimeProvider = FutureProvider<List<Anime>>((ref) async {
  return ref.read(animeRepositoryProvider).getDownloadedAnime();
});

final recentlyWatchedProvider = FutureProvider<List<Anime>>((ref) async {
  return ref.read(animeRepositoryProvider).getRecentlyWatched();
});

final animeDetailProvider = FutureProvider.family<AnimeDetail, Anime>((ref, anime) async {
  if (anime.sourceUrl == null) {
    return AnimeDetail(anime: anime, episodesBySeason: {});
  }

  final scraper = ref.read(scraperServiceProvider);
  final detail = await scraper.fetchAnimeDetail(anime.sourceUrl!, anime.animeId);

  // First save the anime to ensure it exists in DB
  final animeRepo = ref.read(animeRepositoryProvider);
  await animeRepo.upsert(detail.anime);
  
  // Then save episodes using upsert to avoid index violations
  final episodes = detail.episodesBySeason.values.expand((list) => list).toList();
  if (episodes.isNotEmpty) {
    final episodeRepo = ref.read(episodeRepositoryProvider);
    for (final episode in episodes) {
      await episodeRepo.upsert(episode);
    }
  }

  return detail;
});

// ============ Episode Providers ============

final episodesProvider = FutureProvider.family<List<Episode>, String>((ref, animeId) async {
  return ref.read(episodeRepositoryProvider).getEpisodesForAnime(animeId);
});

final downloadedEpisodesProvider = FutureProvider.family<List<Episode>, String>((ref, animeId) async {
  return ref.read(episodeRepositoryProvider).getDownloadedEpisodes(animeId);
});

// ============ Download Providers ============

final activeDownloadsProvider = FutureProvider<List<DownloadTask>>((ref) async {
  return ref.read(downloadRepositoryProvider).getActiveTasks();
});

final completedDownloadsProvider = FutureProvider<List<DownloadTask>>((ref) async {
  return ref.read(downloadRepositoryProvider).getCompletedTasks();
});

final downloadTasksForAnimeProvider = FutureProvider.family<List<DownloadTask>, String>((ref, animeId) async {
  return ref.read(downloadRepositoryProvider).getTasksForAnime(animeId);
});

// ============ Navigation Provider ============

final currentNavIndexProvider = StateProvider<int>((ref) => 0);

// ============ Search Provider ============

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider<List<Anime>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) return [];
  return ref.read(searchServiceProvider).searchAnime(query);
});
