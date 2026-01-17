import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';
import '../database/database.dart';
import '../database/repositories/download_repository.dart';
import '../database/repositories/episode_repository.dart';
import '../database/repositories/settings_repository.dart';
import '../models/m3u8_models.dart';
import 'm3u8_parser.dart';
import 'storage_service.dart';

/// Download manager for handling M3U8/HLS video downloads
class DownloadManager {
  DownloadManager._();
  static final DownloadManager instance = DownloadManager._();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: AppConstants.networkTimeout,
    receiveTimeout: const Duration(minutes: 5),
    headers: {'User-Agent': AppConstants.userAgent},
  ));

  final _uuid = const Uuid();
  final _downloadRepository = DownloadRepository.instance;
  final _episodeRepository = EpisodeRepository.instance;
  final _storageService = StorageService.instance;

  final Map<String, CancelToken> _cancelTokens = {};
  final Map<String, StreamController<DownloadProgress>> _progressControllers = {};
  
  bool _isRunning = false;
  int _activeDownloads = 0;
  int _maxParallelDownloads = 2;
  int _maxParallelSegments = 4;

  /// Initialize download manager
  Future<void> initialize() async {
    final settings = await SettingsRepository.instance.getSettings();
    _maxParallelDownloads = settings.parallelDownloads;
    _maxParallelSegments = settings.parallelSegments;
    
    // Resume paused/queued downloads if auto-resume is enabled
    if (settings.autoResumeDownloads) {
      await _resumePendingDownloads();
    }
  }

  /// Create a new download task
  Future<DownloadTask> createDownload({
    required String animeId,
    required String animeTitle,
    required int episodeNumber,
    required String episodeTitle,
    required String masterM3u8Url,
    required StreamSelection selection,
    String? cookies,
    String? referer,
  }) async {
    // Get episode folder
    final episodeFolder = await _storageService.getEpisodeFolder(
      animeTitle,
      episodeNumber,
    );

    // Create download task
    final task = await _downloadRepository.createTask(
      taskId: _uuid.v4(),
      animeId: animeId,
      animeTitle: animeTitle,
      episodeNumber: episodeNumber,
      episodeTitle: episodeTitle,
      masterM3u8Url: masterM3u8Url,
      downloadFolder: episodeFolder,
      selectedQuality: selection.videoStream.qualityLabel,
      selectedLanguage: selection.audioTrack?.displayName,
      audioGroupId: selection.audioTrack?.groupId,
      cookies: cookies,
      referer: referer,
    );

    // Update episode status
    await _episodeRepository.updateDownloadStatus(
      animeId,
      episodeNumber,
      status: 'queued',
    );

    AppLogger.i('Created download task: ${task.taskId}');

    // Start processing if not already running
    _processQueue();

    return task;
  }

  /// Pause a download
  Future<void> pauseDownload(String taskId) async {
    _cancelTokens[taskId]?.cancel('Paused by user');
    _cancelTokens.remove(taskId);
    
    await _downloadRepository.updateTaskStatus(taskId, 'paused');
    
    final task = await _downloadRepository.getTaskById(taskId);
    if (task != null) {
      await _episodeRepository.updateDownloadStatus(
        task.animeId,
        task.episodeNumber,
        status: 'paused',
      );
    }
    
    AppLogger.i('Paused download: $taskId');
  }

  /// Resume a paused download
  Future<void> resumeDownload(String taskId) async {
    await _downloadRepository.updateTaskStatus(taskId, 'queued');
    
    final task = await _downloadRepository.getTaskById(taskId);
    if (task != null) {
      await _episodeRepository.updateDownloadStatus(
        task.animeId,
        task.episodeNumber,
        status: 'queued',
      );
    }
    
    AppLogger.i('Resumed download: $taskId');
    _processQueue();
  }

  /// Cancel and delete a download
  Future<void> cancelDownload(String taskId) async {
    _cancelTokens[taskId]?.cancel('Cancelled by user');
    _cancelTokens.remove(taskId);
    _progressControllers[taskId]?.close();
    _progressControllers.remove(taskId);

    final task = await _downloadRepository.getTaskById(taskId);
    if (task != null) {
      // Delete downloaded files
      await _storageService.deleteEpisodeDownload(task.downloadFolder);
      
      // Update episode status
      await _episodeRepository.updateDownloadStatus(
        task.animeId,
        task.episodeNumber,
        status: 'none',
      );
    }

    // Delete task and segments from database
    await _downloadRepository.deleteTask(taskId);
    
    AppLogger.i('Cancelled download: $taskId');
  }

  /// Get download progress stream
  Stream<DownloadProgress> getProgressStream(String taskId) {
    _progressControllers[taskId] ??= StreamController<DownloadProgress>.broadcast();
    return _progressControllers[taskId]!.stream;
  }

  /// Process download queue
  Future<void> _processQueue() async {
    if (_isRunning) return;
    _isRunning = true;

    try {
      while (true) {
        // Check if we can start more downloads
        if (_activeDownloads >= _maxParallelDownloads) {
          await Future.delayed(const Duration(seconds: 1));
          continue;
        }

        // Get next queued task
        final queuedTasks = await _downloadRepository.getActiveTasks();
        final pendingTasks = queuedTasks.where((t) => t.status == 'queued').toList();

        if (pendingTasks.isEmpty) {
          break;
        }

        final task = pendingTasks.first;
        _activeDownloads++;
        
        // Start download in background
        _downloadTask(task).then((_) {
          _activeDownloads--;
          _processQueue();
        }).catchError((e) {
          _activeDownloads--;
          AppLogger.e('Download failed: ${task.taskId}', e);
        });
      }
    } finally {
      _isRunning = false;
    }
  }

  /// Download a single task
  Future<void> _downloadTask(DownloadTask task) async {
    AppLogger.i('Starting download: ${task.taskId}');
    
    final cancelToken = CancelToken();
    _cancelTokens[task.taskId] = cancelToken;

    try {
      // Update status to downloading
      await _downloadRepository.updateTaskStatus(task.taskId, 'downloading');
      await _episodeRepository.updateDownloadStatus(
        task.animeId,
        task.episodeNumber,
        status: 'downloading',
      );

      // Fetch media playlist
      final mediaPlaylist = await _fetchMediaPlaylist(task, cancelToken);
      
      // Create segments folder
      final segmentsFolder = await _storageService.getSegmentsFolder(
        task.animeTitle,
        task.episodeNumber,
      );

      // Create segment records if not exists
      final existingSegments = await _downloadRepository.getSegmentsForTask(task.taskId);
      if (existingSegments.isEmpty) {
        final segments = mediaPlaylist.segments.map((seg) {
          return DownloadSegmentsCompanion.insert(
            taskId: task.taskId,
            segmentIndex: seg.index,
            segmentUrl: seg.url,
            localPath: _storageService.getSegmentPath(segmentsFolder, seg.index),
            duration: Value(seg.duration),
          );
        }).toList();

        await _downloadRepository.saveSegments(segments);

        // Update task with total segments
        await _downloadRepository.updateTaskProgress(
          task.taskId,
          downloadedSegments: 0,
          downloadedBytes: 0,
          totalSegments: segments.length,
        );
      }

      // Refresh task data
      final updatedTask = await _downloadRepository.getTaskById(task.taskId);
      if (updatedTask == null) return;

      // Download segments in parallel
      await _downloadSegments(updatedTask, cancelToken);

      // Verify all segments downloaded
      final completedCount = await _downloadRepository.countCompletedSegments(task.taskId);
      if (completedCount < updatedTask.totalSegments) {
        throw Exception('Not all segments downloaded');
      }

      // Create local master.m3u8
      final segments = await _downloadRepository.getSegmentsForTask(task.taskId);
      final segmentPaths = segments.map((s) => 'segments/${s.localPath.split('/').last}').toList();
      await _storageService.createLocalMaster(task.downloadFolder, segmentPaths);

      // Update status to completed
      await _downloadRepository.updateTaskStatus(task.taskId, 'completed');
      await _episodeRepository.updateDownloadStatus(
        task.animeId,
        task.episodeNumber,
        status: 'completed',
        downloadPath: task.downloadFolder,
      );

      _emitProgress(task.taskId, DownloadProgress(
        taskId: task.taskId,
        progress: 1.0,
        downloadedBytes: updatedTask.downloadedBytes,
        totalBytes: updatedTask.totalBytes,
        speed: 0,
        status: 'completed',
      ));

      AppLogger.i('Download completed: ${task.taskId}');
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        AppLogger.i('Download cancelled: ${task.taskId}');
        return;
      }
      await _handleDownloadError(task, e);
    } catch (e, stack) {
      await _handleDownloadError(task, e, stack);
    } finally {
      _cancelTokens.remove(task.taskId);
    }
  }

  /// Fetch media playlist for task
  Future<MediaPlaylist> _fetchMediaPlaylist(DownloadTask task, CancelToken cancelToken) async {
    final response = await _dio.get(
      task.masterM3u8Url,
      cancelToken: cancelToken,
      options: Options(
        headers: {
          if (task.referer != null) 'Referer': task.referer!,
          if (task.cookies != null) 'Cookie': task.cookies!,
        },
      ),
    );

    return M3U8Parser.parseMediaPlaylist(response.data.toString(), task.masterM3u8Url);
  }

  /// Download segments with parallel execution
  Future<void> _downloadSegments(DownloadTask task, CancelToken cancelToken) async {
    final pendingSegments = await _downloadRepository.getPendingSegments(task.taskId);
    final retryableSegments = await _downloadRepository.getRetryableSegments(task.taskId);
    
    final allSegments = [...pendingSegments, ...retryableSegments];
    if (allSegments.isEmpty) return;

    int downloadedBytes = task.downloadedBytes;
    int completedSegments = await _downloadRepository.countCompletedSegments(task.taskId);
    final startTime = DateTime.now();

    // Process segments in batches
    for (var i = 0; i < allSegments.length; i += _maxParallelSegments) {
      if (cancelToken.isCancelled) break;

      final batch = allSegments.skip(i).take(_maxParallelSegments).toList();
      
      await Future.wait(batch.map((segment) async {
        if (cancelToken.isCancelled) return;

        try {
          await _downloadRepository.updateSegmentStatus(segment.id, 'downloading');

          final response = await _dio.download(
            segment.segmentUrl,
            segment.localPath,
            cancelToken: cancelToken,
            options: Options(
              headers: {
                if (task.referer != null) 'Referer': task.referer!,
                if (task.cookies != null) 'Cookie': task.cookies!,
              },
            ),
          );

          if (response.statusCode == 200) {
            final file = File(segment.localPath);
            final fileSize = await file.length();
            
            await _downloadRepository.updateSegmentStatus(
              segment.id,
              'completed',
              downloadedBytes: fileSize,
              fileSize: fileSize,
            );

            downloadedBytes += fileSize;
            completedSegments++;

            // Emit progress
            final elapsed = DateTime.now().difference(startTime).inSeconds;
            final speed = elapsed > 0 ? downloadedBytes / elapsed : 0;

            _emitProgress(task.taskId, DownloadProgress(
              taskId: task.taskId,
              progress: completedSegments / task.totalSegments,
              downloadedBytes: downloadedBytes,
              totalBytes: task.totalBytes,
              speed: speed.toInt(),
              status: 'downloading',
            ));

            // Update task progress
            await _downloadRepository.updateTaskProgress(
              task.taskId,
              downloadedSegments: completedSegments,
              downloadedBytes: downloadedBytes,
            );
          }
        } catch (e) {
          if (e is DioException && e.type == DioExceptionType.cancel) return;
          
          await _downloadRepository.updateSegmentStatus(
            segment.id,
            'failed',
            errorMessage: e.toString(),
          );
          AppLogger.w('Segment ${segment.segmentIndex} failed: $e');
        }
      }));
    }
  }

  /// Handle download error
  Future<void> _handleDownloadError(DownloadTask task, dynamic error, [StackTrace? stack]) async {
    AppLogger.e('Download error: ${task.taskId}', error, stack);
    
    final errorMessage = error.toString();

    if (task.retryCount < AppConstants.maxRetries) {
      // Retry later
      await _downloadRepository.updateTaskStatus(
        task.taskId,
        'queued',
        errorMessage: errorMessage,
      );
    } else {
      // Mark as failed
      await _downloadRepository.updateTaskStatus(
        task.taskId,
        'failed',
        errorMessage: errorMessage,
      );
      await _episodeRepository.updateDownloadStatus(
        task.animeId,
        task.episodeNumber,
        status: 'failed',
      );

      final updatedTask = await _downloadRepository.getTaskById(task.taskId);
      _emitProgress(task.taskId, DownloadProgress(
        taskId: task.taskId,
        progress: updatedTask?.totalSegments != null && updatedTask!.totalSegments > 0 
            ? updatedTask.downloadedSegments / updatedTask.totalSegments 
            : 0,
        downloadedBytes: updatedTask?.downloadedBytes ?? 0,
        totalBytes: updatedTask?.totalBytes ?? 0,
        speed: 0,
        status: 'failed',
        error: errorMessage,
      ));
    }
  }

  /// Emit download progress
  void _emitProgress(String taskId, DownloadProgress progress) {
    _progressControllers[taskId]?.add(progress);
  }

  /// Resume pending downloads
  Future<void> _resumePendingDownloads() async {
    final pausedTasks = await _downloadRepository.getPausedTasks();
    for (final task in pausedTasks) {
      await resumeDownload(task.taskId);
    }
  }

  /// Dispose download manager
  void dispose() {
    for (final token in _cancelTokens.values) {
      token.cancel('Manager disposed');
    }
    _cancelTokens.clear();
    
    for (final controller in _progressControllers.values) {
      controller.close();
    }
    _progressControllers.clear();
    
    _dio.close();
  }
}

/// Download progress data
class DownloadProgress {
  final String taskId;
  final double progress;
  final int downloadedBytes;
  final int totalBytes;
  final int speed; // bytes per second
  final String status;
  final String? error;

  DownloadProgress({
    required this.taskId,
    required this.progress,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.speed,
    required this.status,
    this.error,
  });

  String get progressPercent => '${(progress * 100).toStringAsFixed(1)}%';
  
  String get speedFormatted {
    if (speed <= 0) return '0 B/s';
    const suffixes = ['B/s', 'KB/s', 'MB/s', 'GB/s'];
    var i = 0;
    double s = speed.toDouble();
    while (s >= 1024 && i < suffixes.length - 1) {
      s /= 1024;
      i++;
    }
    return '${s.toStringAsFixed(2)} ${suffixes[i]}';
  }
}
