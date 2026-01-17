import 'package:drift/drift.dart';
import '../database.dart';
import '../../../core/utils/logger.dart';

/// Repository for Download operations
class DownloadRepository {
  DownloadRepository._();
  static final DownloadRepository instance = DownloadRepository._();

  AppDatabase get _db => AppDatabase.instance;

  // ============ Download Tasks ============

  /// Get all download tasks
  Future<List<DownloadTask>> getAllTasks() async {
    return (_db.select(_db.downloadTasks)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// Get active tasks (queued or downloading)
  Future<List<DownloadTask>> getActiveTasks() async {
    return (_db.select(_db.downloadTasks)
          ..where((t) => t.status.isIn(['queued', 'downloading']))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  /// Get completed tasks
  Future<List<DownloadTask>> getCompletedTasks() async {
    return (_db.select(_db.downloadTasks)
          ..where((t) => t.status.equals('completed'))
          ..orderBy([(t) => OrderingTerm.desc(t.completedAt)]))
        .get();
  }

  /// Get paused tasks
  Future<List<DownloadTask>> getPausedTasks() async {
    return (_db.select(_db.downloadTasks)..where((t) => t.status.equals('paused'))).get();
  }

  /// Get task by taskId
  Future<DownloadTask?> getTaskById(String taskId) async {
    return (_db.select(_db.downloadTasks)..where((t) => t.taskId.equals(taskId)))
        .getSingleOrNull();
  }

  /// Get tasks for an anime
  Future<List<DownloadTask>> getTasksForAnime(String animeId) async {
    return (_db.select(_db.downloadTasks)
          ..where((t) => t.animeId.equals(animeId))
          ..orderBy([(t) => OrderingTerm.asc(t.episodeNumber)]))
        .get();
  }

  /// Save task
  Future<int> saveTask(DownloadTasksCompanion task) async {
    return _db.into(_db.downloadTasks).insertOnConflictUpdate(task);
  }

  /// Create new task
  Future<DownloadTask> createTask({
    required String taskId,
    required String animeId,
    required String animeTitle,
    required int episodeNumber,
    required String episodeTitle,
    required String masterM3u8Url,
    required String downloadFolder,
    String? selectedQuality,
    String? selectedLanguage,
    String? audioGroupId,
    String? cookies,
    String? referer,
  }) async {
    final companion = DownloadTasksCompanion.insert(
      taskId: taskId,
      animeId: animeId,
      animeTitle: animeTitle,
      episodeNumber: episodeNumber,
      episodeTitle: episodeTitle,
      masterM3u8Url: masterM3u8Url,
      downloadFolder: downloadFolder,
      selectedQuality: Value(selectedQuality),
      selectedLanguage: Value(selectedLanguage),
      audioGroupId: Value(audioGroupId),
      cookies: Value(cookies),
      referer: Value(referer),
    );

    await saveTask(companion);
    return (await getTaskById(taskId))!;
  }

  /// Update task status
  Future<void> updateTaskStatus(String taskId, String status, {String? errorMessage}) async {
    final updates = DownloadTasksCompanion(
      status: Value(status),
      errorMessage: Value(errorMessage),
    );

    // Add timestamps based on status
    DownloadTasksCompanion finalUpdates;
    switch (status) {
      case 'downloading':
        finalUpdates = updates.copyWith(startedAt: Value(DateTime.now()));
        break;
      case 'completed':
        finalUpdates = updates.copyWith(completedAt: Value(DateTime.now()));
        break;
      case 'paused':
        finalUpdates = updates.copyWith(pausedAt: Value(DateTime.now()));
        break;
      default:
        finalUpdates = updates;
    }

    await (_db.update(_db.downloadTasks)..where((t) => t.taskId.equals(taskId)))
        .write(finalUpdates);
    AppLogger.i('Task $taskId status updated to $status');
  }

  /// Update task progress
  Future<void> updateTaskProgress(
    String taskId, {
    required int downloadedSegments,
    required int downloadedBytes,
    int? totalSegments,
    int? totalBytes,
  }) async {
    await (_db.update(_db.downloadTasks)..where((t) => t.taskId.equals(taskId)))
        .write(DownloadTasksCompanion(
      downloadedSegments: Value(downloadedSegments),
      downloadedBytes: Value(downloadedBytes),
      totalSegments: totalSegments != null ? Value(totalSegments) : const Value.absent(),
      totalBytes: totalBytes != null ? Value(totalBytes) : const Value.absent(),
    ));
  }

  /// Delete task and its segments
  Future<void> deleteTask(String taskId) async {
    await (_db.delete(_db.downloadSegments)..where((s) => s.taskId.equals(taskId))).go();
    await (_db.delete(_db.downloadTasks)..where((t) => t.taskId.equals(taskId))).go();
    AppLogger.i('Deleted task: $taskId');
  }

  // ============ Download Segments ============

  /// Get all segments for a task
  Future<List<DownloadSegment>> getSegmentsForTask(String taskId) async {
    return (_db.select(_db.downloadSegments)
          ..where((s) => s.taskId.equals(taskId))
          ..orderBy([(s) => OrderingTerm.asc(s.segmentIndex)]))
        .get();
  }

  /// Get pending segments for a task
  Future<List<DownloadSegment>> getPendingSegments(String taskId) async {
    return (_db.select(_db.downloadSegments)
          ..where((s) => s.taskId.equals(taskId) & s.status.equals('pending'))
          ..orderBy([(s) => OrderingTerm.asc(s.segmentIndex)]))
        .get();
  }

  /// Get failed segments that can be retried
  Future<List<DownloadSegment>> getRetryableSegments(String taskId) async {
    return (_db.select(_db.downloadSegments)
          ..where((s) =>
              s.taskId.equals(taskId) & s.status.equals('failed') & s.retryCount.isSmallerThanValue(3))
          ..orderBy([(s) => OrderingTerm.asc(s.segmentIndex)]))
        .get();
  }

  /// Save segment
  Future<int> saveSegment(DownloadSegmentsCompanion segment) async {
    return _db.into(_db.downloadSegments).insertOnConflictUpdate(segment);
  }

  /// Save multiple segments
  Future<void> saveSegments(List<DownloadSegmentsCompanion> segments) async {
    await _db.batch((batch) {
      for (final segment in segments) {
        batch.insert(_db.downloadSegments, segment, onConflict: DoUpdate((old) => segment));
      }
    });
  }

  /// Update segment status
  Future<void> updateSegmentStatus(
    int segmentId,
    String status, {
    String? errorMessage,
    int? downloadedBytes,
    int? fileSize,
  }) async {
    final segment = await (_db.select(_db.downloadSegments)..where((s) => s.id.equals(segmentId)))
        .getSingleOrNull();
    if (segment == null) return;

    await (_db.update(_db.downloadSegments)..where((s) => s.id.equals(segmentId)))
        .write(DownloadSegmentsCompanion(
      status: Value(status),
      errorMessage: Value(errorMessage),
      downloadedBytes: downloadedBytes != null ? Value(downloadedBytes) : const Value.absent(),
      fileSize: fileSize != null ? Value(fileSize) : const Value.absent(),
      retryCount: status == 'failed' ? Value(segment.retryCount + 1) : const Value.absent(),
    ));
  }

  /// Count completed segments for a task
  Future<int> countCompletedSegments(String taskId) async {
    final count = _db.downloadSegments.id.count();
    final query = _db.selectOnly(_db.downloadSegments)
      ..addColumns([count])
      ..where(_db.downloadSegments.taskId.equals(taskId) &
          _db.downloadSegments.status.equals('completed'));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  /// Get total download size (completed)
  Future<int> getTotalDownloadedSize() async {
    final sum = _db.downloadTasks.downloadedBytes.sum();
    final query = _db.selectOnly(_db.downloadTasks)
      ..addColumns([sum])
      ..where(_db.downloadTasks.status.equals('completed'));
    final result = await query.getSingle();
    return result.read(sum) ?? 0;
  }
}

extension on DownloadTasksCompanion {
  DownloadTasksCompanion copyWith({
    Value<DateTime?>? startedAt,
    Value<DateTime?>? completedAt,
    Value<DateTime?>? pausedAt,
  }) {
    return DownloadTasksCompanion(
      id: id,
      taskId: taskId,
      animeId: animeId,
      animeTitle: animeTitle,
      episodeNumber: episodeNumber,
      episodeTitle: episodeTitle,
      masterM3u8Url: masterM3u8Url,
      selectedQuality: selectedQuality,
      selectedLanguage: selectedLanguage,
      audioGroupId: audioGroupId,
      downloadFolder: downloadFolder,
      segmentListPath: segmentListPath,
      totalSegments: totalSegments,
      downloadedSegments: downloadedSegments,
      totalBytes: totalBytes,
      downloadedBytes: downloadedBytes,
      status: status,
      errorMessage: errorMessage,
      retryCount: retryCount,
      createdAt: createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      pausedAt: pausedAt ?? this.pausedAt,
      cookies: cookies,
      referer: referer,
    );
  }
}
