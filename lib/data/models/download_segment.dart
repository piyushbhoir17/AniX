import 'package:isar/isar.dart';

part 'download_segment.g.dart';

@collection
class DownloadSegment {
  Id id = Isar.autoIncrement;

  @Index()
  late String taskId; // Reference to parent DownloadTask

  @Index(composite: [CompositeIndex('taskId')])
  late int segmentIndex;

  late String segmentUrl;
  late String localPath; // Local file path where segment is saved

  // Segment info
  double? duration; // Duration in seconds
  int? fileSize; // Size in bytes
  int downloadedBytes = 0;

  // Status
  @enumerated
  SegmentStatus status = SegmentStatus.pending;

  String? errorMessage;
  int retryCount = 0;

  DownloadSegment();

  factory DownloadSegment.create({
    required String taskId,
    required int segmentIndex,
    required String segmentUrl,
    required String localPath,
    double? duration,
  }) {
    return DownloadSegment()
      ..taskId = taskId
      ..segmentIndex = segmentIndex
      ..segmentUrl = segmentUrl
      ..localPath = localPath
      ..duration = duration;
  }

  /// Check if segment download is complete
  bool get isComplete => status == SegmentStatus.completed;

  /// Check if segment can be retried
  bool get canRetry => status == SegmentStatus.failed && retryCount < 3;

  @override
  String toString() => 'DownloadSegment(taskId: $taskId, index: $segmentIndex, status: $status)';
}

/// Segment download status
enum SegmentStatus {
  pending,
  downloading,
  completed,
  failed,
}
