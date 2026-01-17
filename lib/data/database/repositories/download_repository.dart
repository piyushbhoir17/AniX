import 'package:isar/isar.dart';
import '../database.dart';
import '../../models/download_task.dart';
import '../../models/download_segment.dart';
import '../../../core/utils/logger.dart';

/// Repository for Download operations
class DownloadRepository {
  DownloadRepository._();
  static final DownloadRepository instance = DownloadRepository._();

  Isar get _db => AppDatabase.instance;

  // ============ Download Tasks ============

  /// Get all download tasks
  Future<List<DownloadTask>> getAllTasks() async {
    return _db.downloadTasks.where().sortByCreatedAtDesc().findAll();
  }

  /// Get active tasks (queued or downloading)
  Future<List<DownloadTask>> getActiveTasks() async {
    return _db.downloadTasks
        .filter()
        .statusEqualTo(TaskStatus.queued)
        .or()
        .statusEqualTo(TaskStatus.downloading)
        .sortByCreatedAt()
        .findAll();
  }

  /// Get completed tasks
  Future<List<DownloadTask>> getCompletedTasks() async {
    return _db.downloadTasks
        .filter()
        .statusEqualTo(TaskStatus.completed)
        .sortByCompletedAtDesc()
        .findAll();
  }

  /// Get paused tasks
  Future<List<DownloadTask>> getPausedTasks() async {
    return _db.downloadTasks
        .filter()
        .statusEqualTo(TaskStatus.paused)
        .findAll();
  }

  /// Get task by taskId
  Future<DownloadTask?> getTaskById(String taskId) async {
    return _db.downloadTasks.filter().taskIdEqualTo(taskId).findFirst();
  }

  /// Get tasks for an anime
  Future<List<DownloadTask>> getTasksForAnime(String animeId) async {
    return _db.downloadTasks
        .filter()
        .animeIdEqualTo(animeId)
        .sortByEpisodeNumber()
        .findAll();
  }

  /// Get completed tasks for an anime
  Future<List<DownloadTask>> getCompletedTasksForAnime(String animeId) async {
    return _db.downloadTasks
        .filter()
        .animeIdEqualTo(animeId)
        .statusEqualTo(TaskStatus.completed)
        .sortByEpisodeNumber()
        .findAll();
  }

  /// Save task
  Future<int> saveTask(DownloadTask task) async {
    return _db.writeTxn(() async {
      return _db.downloadTasks.put(task);
    });
  }

  /// Update task status
  Future<void> updateTaskStatus(String taskId, TaskStatus status, {String? errorMessage}) async {
    final task = await getTaskById(taskId);
    if (task == null) return;

    task.status = status;
    task.errorMessage = errorMessage;

    switch (status) {
      case TaskStatus.downloading:
        task.startedAt ??= DateTime.now();
        break;
      case TaskStatus.completed:
        task.completedAt = DateTime.now();
        break;
      case TaskStatus.paused:
        task.pausedAt = DateTime.now();
        break;
      default:
        break;
    }

    await saveTask(task);
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
    final task = await getTaskById(taskId);
    if (task == null) return;

    task.downloadedSegments = downloadedSegments;
    task.downloadedBytes = downloadedBytes;
    if (totalSegments != null) task.totalSegments = totalSegments;
    if (totalBytes != null) task.totalBytes = totalBytes;

    await saveTask(task);
  }

  /// Delete task and its segments
  Future<void> deleteTask(String taskId) async {
    await _db.writeTxn(() async {
      // Delete segments first
      await _db.downloadSegments.filter().taskIdEqualTo(taskId).deleteAll();
      // Delete task
      await _db.downloadTasks.filter().taskIdEqualTo(taskId).deleteAll();
    });
    AppLogger.i('Deleted task: $taskId');
  }

  /// Delete all tasks for an anime
  Future<void> deleteTasksForAnime(String animeId) async {
    final tasks = await getTasksForAnime(animeId);
    for (final task in tasks) {
      await deleteTask(task.taskId);
    }
  }

  // ============ Download Segments ============

  /// Get all segments for a task
  Future<List<DownloadSegment>> getSegmentsForTask(String taskId) async {
    return _db.downloadSegments
        .filter()
        .taskIdEqualTo(taskId)
        .sortBySegmentIndex()
        .findAll();
  }

  /// Get pending segments for a task
  Future<List<DownloadSegment>> getPendingSegments(String taskId) async {
    return _db.downloadSegments
        .filter()
        .taskIdEqualTo(taskId)
        .statusEqualTo(SegmentStatus.pending)
        .sortBySegmentIndex()
        .findAll();
  }

  /// Get failed segments that can be retried
  Future<List<DownloadSegment>> getRetryableSegments(String taskId) async {
    return _db.downloadSegments
        .filter()
        .taskIdEqualTo(taskId)
        .statusEqualTo(SegmentStatus.failed)
        .retryCountLessThan(3)
        .sortBySegmentIndex()
        .findAll();
  }

  /// Save segment
  Future<int> saveSegment(DownloadSegment segment) async {
    return _db.writeTxn(() async {
      return _db.downloadSegments.put(segment);
    });
  }

  /// Save multiple segments
  Future<void> saveSegments(List<DownloadSegment> segments) async {
    await _db.writeTxn(() async {
      await _db.downloadSegments.putAll(segments);
    });
  }

  /// Update segment status
  Future<void> updateSegmentStatus(
    int segmentId,
    SegmentStatus status, {
    String? errorMessage,
    int? downloadedBytes,
    int? fileSize,
  }) async {
    final segment = await _db.downloadSegments.get(segmentId);
    if (segment == null) return;

    segment.status = status;
    if (errorMessage != null) segment.errorMessage = errorMessage;
    if (downloadedBytes != null) segment.downloadedBytes = downloadedBytes;
    if (fileSize != null) segment.fileSize = fileSize;

    if (status == SegmentStatus.failed) {
      segment.retryCount++;
    }

    await saveSegment(segment);
  }

  /// Count completed segments for a task
  Future<int> countCompletedSegments(String taskId) async {
    return _db.downloadSegments
        .filter()
        .taskIdEqualTo(taskId)
        .statusEqualTo(SegmentStatus.completed)
        .count();
  }

  /// Delete segments for a task
  Future<void> deleteSegmentsForTask(String taskId) async {
    await _db.writeTxn(() async {
      await _db.downloadSegments.filter().taskIdEqualTo(taskId).deleteAll();
    });
  }

  // ============ Statistics ============

  /// Get total download size (completed)
  Future<int> getTotalDownloadedSize() async {
    final tasks = await getCompletedTasks();
    return tasks.fold(0, (sum, task) => sum + task.downloadedBytes);
  }

  /// Count active downloads
  Future<int> countActiveDownloads() async {
    return _db.downloadTasks
        .filter()
        .statusEqualTo(TaskStatus.downloading)
        .count();
  }

  /// Count queued downloads
  Future<int> countQueuedDownloads() async {
    return _db.downloadTasks
        .filter()
        .statusEqualTo(TaskStatus.queued)
        .count();
  }
}
