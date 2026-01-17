import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:saf/saf.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/extensions.dart';
import '../database/repositories/settings_repository.dart';

/// Service for managing storage and file operations
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  final Saf _saf = Saf(AppConstants.downloadFolderName);
  String? _downloadBasePath;

  /// Initialize storage service
  Future<void> initialize() async {
    final settings = await SettingsRepository.instance.getSettings();
    if (settings.safFolderUri != null) {
      _downloadBasePath = settings.downloadPath;
    }
  }

  /// Request SAF folder permission
  Future<bool> requestSafPermission() async {
    try {
      final granted = await _saf.getDirectoryPermission(isDynamic: true);
      
      if (granted == true) {
        // Get the paths
        final paths = await _saf.getPersistedPermissionDirectories();
        if (paths != null && paths.isNotEmpty) {
          _downloadBasePath = paths.first;
          
          // Save to settings
          await SettingsRepository.instance.setSafFolder(
            _downloadBasePath,
            _downloadBasePath,
          );
          
          AppLogger.i('SAF permission granted: $_downloadBasePath');
          return true;
        }
      }
      
      AppLogger.w('SAF permission denied');
      return false;
    } catch (e, stack) {
      AppLogger.e('Failed to request SAF permission', e, stack);
      return false;
    }
  }

  /// Check if SAF permission is granted
  Future<bool> hasSafPermission() async {
    try {
      final paths = await _saf.getPersistedPermissionDirectories();
      return paths != null && paths.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get download base path
  String? get downloadBasePath => _downloadBasePath;

  /// Get or create anime download folder
  Future<String> getAnimeFolder(String animeTitle) async {
    final sanitizedTitle = animeTitle.sanitizeFileName;
    
    if (_downloadBasePath != null) {
      // Using SAF
      final animePath = p.join(_downloadBasePath!, sanitizedTitle);
      await _ensureDirectoryExists(animePath);
      return animePath;
    }
    
    // Fallback to app documents directory
    final appDir = await getApplicationDocumentsDirectory();
    final animePath = p.join(appDir.path, AppConstants.downloadFolderName, sanitizedTitle);
    await _ensureDirectoryExists(animePath);
    return animePath;
  }

  /// Get or create episode download folder
  Future<String> getEpisodeFolder(String animeTitle, int episodeNumber) async {
    final animeFolder = await getAnimeFolder(animeTitle);
    final episodeFolder = p.join(animeFolder, 'Episode_$episodeNumber');
    await _ensureDirectoryExists(episodeFolder);
    return episodeFolder;
  }

  /// Get segments folder for an episode
  Future<String> getSegmentsFolder(String animeTitle, int episodeNumber) async {
    final episodeFolder = await getEpisodeFolder(animeTitle, episodeNumber);
    final segmentsFolder = p.join(episodeFolder, 'segments');
    await _ensureDirectoryExists(segmentsFolder);
    return segmentsFolder;
  }

  /// Get local master.m3u8 path for an episode
  String getLocalMasterPath(String episodeFolder) {
    return p.join(episodeFolder, 'master.m3u8');
  }

  /// Create local master.m3u8 for offline playback
  Future<String> createLocalMaster(String episodeFolder, List<String> segmentFiles) async {
    final masterPath = getLocalMasterPath(episodeFolder);
    
    final buffer = StringBuffer();
    buffer.writeln('#EXTM3U');
    buffer.writeln('#EXT-X-VERSION:3');
    buffer.writeln('#EXT-X-TARGETDURATION:10');
    buffer.writeln('#EXT-X-MEDIA-SEQUENCE:0');

    for (final segmentFile in segmentFiles) {
      buffer.writeln('#EXTINF:10.0,');
      buffer.writeln(segmentFile);
    }

    buffer.writeln('#EXT-X-ENDLIST');

    final file = File(masterPath);
    await file.writeAsString(buffer.toString());
    
    AppLogger.i('Created local master.m3u8 at: $masterPath');
    return masterPath;
  }

  /// Get segment file path
  String getSegmentPath(String segmentsFolder, int index) {
    return p.join(segmentsFolder, 'segment_$index.ts');
  }

  /// Check if episode is fully downloaded
  Future<bool> isEpisodeDownloaded(String episodeFolder) async {
    final masterPath = getLocalMasterPath(episodeFolder);
    return File(masterPath).exists();
  }

  /// Get downloaded episode size
  Future<int> getEpisodeSize(String episodeFolder) async {
    final dir = Directory(episodeFolder);
    if (!await dir.exists()) return 0;

    int totalSize = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        totalSize += await entity.length();
      }
    }
    return totalSize;
  }

  /// Delete episode download
  Future<void> deleteEpisodeDownload(String episodeFolder) async {
    final dir = Directory(episodeFolder);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      AppLogger.i('Deleted episode folder: $episodeFolder');
    }
  }

  /// Delete anime download folder
  Future<void> deleteAnimeDownloads(String animeTitle) async {
    final sanitizedTitle = animeTitle.sanitizeFileName;
    
    String animePath;
    if (_downloadBasePath != null) {
      animePath = p.join(_downloadBasePath!, sanitizedTitle);
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      animePath = p.join(appDir.path, AppConstants.downloadFolderName, sanitizedTitle);
    }

    final dir = Directory(animePath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      AppLogger.i('Deleted anime folder: $animePath');
    }
  }

  /// Get total downloaded size
  Future<int> getTotalDownloadedSize() async {
    String basePath;
    if (_downloadBasePath != null) {
      basePath = _downloadBasePath!;
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      basePath = p.join(appDir.path, AppConstants.downloadFolderName);
    }

    final dir = Directory(basePath);
    if (!await dir.exists()) return 0;

    int totalSize = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        totalSize += await entity.length();
      }
    }
    return totalSize;
  }

  /// Get app cache directory
  Future<String> getCacheDirectory() async {
    final cacheDir = await getTemporaryDirectory();
    final anixCacheDir = p.join(cacheDir.path, 'anix_cache');
    await _ensureDirectoryExists(anixCacheDir);
    return anixCacheDir;
  }

  /// Clear app cache
  Future<void> clearCache() async {
    final cacheDir = await getCacheDirectory();
    final dir = Directory(cacheDir);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      AppLogger.i('Cache cleared');
    }
  }

  /// Ensure directory exists
  Future<void> _ensureDirectoryExists(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }
}
