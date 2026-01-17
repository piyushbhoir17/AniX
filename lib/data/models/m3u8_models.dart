/// Models for M3U8/HLS parsing (not Isar - just plain Dart classes)

/// Represents a master M3U8 playlist
class MasterPlaylist {
  final String originalUrl;
  final List<VideoStream> videoStreams;
  final List<AudioTrack> audioTracks;
  final String? baseDomain;

  MasterPlaylist({
    required this.originalUrl,
    required this.videoStreams,
    required this.audioTracks,
    this.baseDomain,
  });

  /// Get available qualities (resolutions)
  List<String> get availableQualities {
    return videoStreams
        .map((v) => v.resolution ?? 'Unknown')
        .toSet()
        .toList();
  }

  /// Get available languages
  List<String> get availableLanguages {
    return audioTracks
        .map((a) => a.name ?? a.language ?? 'Unknown')
        .toSet()
        .toList();
  }

  /// Find video stream by resolution
  VideoStream? findStreamByResolution(String resolution) {
    return videoStreams.firstWhere(
      (v) => v.resolution == resolution,
      orElse: () => videoStreams.first,
    );
  }

  /// Find audio track by name/language
  AudioTrack? findAudioByName(String name) {
    try {
      return audioTracks.firstWhere(
        (a) => a.name == name || a.language == name,
      );
    } catch (_) {
      return audioTracks.isNotEmpty ? audioTracks.first : null;
    }
  }

  /// Get compatible audio tracks for a video stream
  List<AudioTrack> getCompatibleAudio(VideoStream stream) {
    if (stream.audioGroupId == null) return [];
    return audioTracks
        .where((a) => a.groupId == stream.audioGroupId)
        .toList();
  }
}

/// Represents a video stream variant in master playlist
class VideoStream {
  final String url;
  final String? resolution;
  final int? bandwidth;
  final String? codecs;
  final String? audioGroupId;
  final String rawLine; // Original #EXT-X-STREAM-INF line

  VideoStream({
    required this.url,
    this.resolution,
    this.bandwidth,
    this.codecs,
    this.audioGroupId,
    required this.rawLine,
  });

  /// Get formatted bandwidth string
  String get bandwidthFormatted {
    if (bandwidth == null) return 'Unknown';
    final kbps = bandwidth! / 1000;
    if (kbps >= 1000) {
      return '${(kbps / 1000).toStringAsFixed(1)} Mbps';
    }
    return '${kbps.toStringAsFixed(0)} Kbps';
  }

  /// Get quality label (e.g., "1080p", "720p")
  String get qualityLabel {
    if (resolution == null) return 'Auto';
    final parts = resolution!.split('x');
    if (parts.length == 2) {
      return '${parts[1]}p';
    }
    return resolution!;
  }

  @override
  String toString() => 'VideoStream(resolution: $resolution, bandwidth: $bandwidthFormatted)';
}

/// Represents an audio track in master playlist
class AudioTrack {
  final String? groupId;
  final String? name;
  final String? language;
  final String? uri;
  final bool isDefault;
  final String rawLine; // Original #EXT-X-MEDIA line

  AudioTrack({
    this.groupId,
    this.name,
    this.language,
    this.uri,
    this.isDefault = false,
    required this.rawLine,
  });

  /// Get display name
  String get displayName => name ?? language ?? 'Unknown';

  @override
  String toString() => 'AudioTrack(name: $name, language: $language, default: $isDefault)';
}

/// Represents a media playlist (contains segments)
class MediaPlaylist {
  final String url;
  final List<Segment> segments;
  final double? targetDuration;
  final int? mediaSequence;
  final bool isEndList;

  MediaPlaylist({
    required this.url,
    required this.segments,
    this.targetDuration,
    this.mediaSequence,
    this.isEndList = true,
  });

  /// Get total duration in seconds
  double get totalDuration {
    return segments.fold(0.0, (sum, seg) => sum + (seg.duration ?? 0.0));
  }

  /// Get total segment count
  int get segmentCount => segments.length;

  @override
  String toString() => 'MediaPlaylist(segments: $segmentCount, duration: ${totalDuration.toStringAsFixed(1)}s)';
}

/// Represents a segment in media playlist
class Segment {
  final int index;
  final String url;
  final double? duration;
  final String? title;
  final bool isEncrypted;
  final String? keyUrl;
  final String? iv;

  Segment({
    required this.index,
    required this.url,
    this.duration,
    this.title,
    this.isEncrypted = false,
    this.keyUrl,
    this.iv,
  });

  @override
  String toString() => 'Segment(index: $index, duration: ${duration?.toStringAsFixed(2)}s)';
}

/// Stream selection result (user's choice)
class StreamSelection {
  final VideoStream videoStream;
  final AudioTrack? audioTrack;
  final bool saveAsDefault;

  StreamSelection({
    required this.videoStream,
    this.audioTrack,
    this.saveAsDefault = false,
  });
}
