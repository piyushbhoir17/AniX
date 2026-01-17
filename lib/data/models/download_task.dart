import 'package:isar/isar.dart';

part 'download_task.g.dart';

@collection
class DownloadTask {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String taskId; // UUID for this download task

  @Index()
  late String animeId;
  
  late String animeTitle;
  late int episodeNumber;
  late String episodeTitle;

  // M3U8 info
  late String masterM3u8Url;
  String? selectedQuality;
  String? selectedLanguage;
  String? audioGroupId;

  // Download paths
  late String downloadFolder; // Full path to episode download folder
  String? segmentListPath; // Path to segment list file

  // Progress tracking
  int totalSegments = 0;
  int downloadedSegments = 0;
  int totalBytes = 0;
  int downloadedBytes = 0;

  // Status
  @enumerated
  TaskStatus status = TaskStatus.queued;
  
  String? errorMessage;
  int retryCount = 0;

  // Timestamps
  late DateTime createdAt;
  DateTime? startedAt;
  DateTime? completedAt;
  DateTime? pausedAt;

  // Cookies and headers for authenticated downloads
  String? cookies;
  String? referer;

  DownloadTask();

  factory DownloadTask.create({
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
  }) {
    return DownloadTask()
      ..taskId = taskId
      ..animeId = animeId
      ..animeTitle = animeTitle
      ..episodeNumber = episodeNumber
      ..episodeTitle = episodeTitle
      ..masterM3u8Url = masterM3u8Url
      ..downloadFolder = downloadFolder
      ..selectedQuality = selectedQuality
      ..selectedLanguage = selectedLanguage
      ..audioGroupId = audioGroupId
      ..cookies = cookies
      ..referer = referer
      ..createdAt = DateTime.now();
  }

  /// Get download progress as percentage (0.0 - 1.0)
  double get progress {
    if (totalSegments == 0) return 0.0;
    return (downloadedSegments / totalSegments).clamp(0.0, 1.0);
  }

  /// Get download progress as percentage string
  String get progressPercent => '${(progress * 100).toStringAsFixed(1)}%';

  /// Get downloaded size as formatted string
  String get downloadedSizeFormatted => _formatBytes(downloadedBytes);

  /// Get total size as formatted string
  String get totalSizeFormatted => _formatBytes(totalBytes);

  /// Check if task is active (queued or downloading)
  bool get isActive => status == TaskStatus.queued || status == TaskStatus.downloading;

  /// Check if task can be resumed
  bool get canResume => status == TaskStatus.paused || status == TaskStatus.failed;

  /// Check if task can be paused
  bool get canPause => status == TaskStatus.downloading;

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(2)} ${suffixes[i]}';
  }

  @override
  String toString() => 'DownloadTask(taskId: $taskId, anime: $animeTitle, ep: $episodeNumber, status: $status)';
}

/// Task status enum
enum TaskStatus {
  queued,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
}
