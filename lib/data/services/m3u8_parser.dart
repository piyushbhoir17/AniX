import '../models/m3u8_models.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/logger.dart';

/// Parser for M3U8/HLS playlists
class M3U8Parser {
  M3U8Parser._();

  /// Parse master playlist content
  static MasterPlaylist parseMasterPlaylist(String content, String url) {
    try {
      final lines = content.split('\n').map((l) => l.trim()).toList();
      
      if (!lines.any((l) => l.startsWith('#EXTM3U'))) {
        throw ParserException(message: 'Invalid M3U8: Missing #EXTM3U header');
      }

      final audioTracks = <AudioTrack>[];
      final videoStreams = <VideoStream>[];
      String? lastStreamInfoLine;
      Map<String, String>? lastStreamAttrs;

      // Extract base domain from URL
      final uri = Uri.parse(url);
      final baseDomain = '${uri.scheme}://${uri.host}';
      final basePath = url.substring(0, url.lastIndexOf('/') + 1);

      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.isEmpty) continue;

        // Parse audio tracks
        if (line.startsWith('#EXT-X-MEDIA:TYPE=AUDIO')) {
          final attrs = _parseAttributes(line);
          audioTracks.add(AudioTrack(
            groupId: attrs['GROUP-ID'],
            name: attrs['NAME'],
            language: attrs['LANGUAGE'],
            uri: _resolveUrl(attrs['URI'], baseDomain, basePath),
            isDefault: attrs['DEFAULT'] == 'YES',
            rawLine: line,
          ));
        }
        // Parse video stream info
        else if (line.startsWith('#EXT-X-STREAM-INF')) {
          lastStreamInfoLine = line;
          lastStreamAttrs = _parseAttributes(line);
        }
        // Stream URL (follows #EXT-X-STREAM-INF)
        else if (!line.startsWith('#') && lastStreamAttrs != null) {
          final streamUrl = _resolveUrl(line, baseDomain, basePath);
          videoStreams.add(VideoStream(
            url: streamUrl,
            resolution: lastStreamAttrs['RESOLUTION'],
            bandwidth: int.tryParse(lastStreamAttrs['BANDWIDTH'] ?? ''),
            codecs: lastStreamAttrs['CODECS'],
            audioGroupId: lastStreamAttrs['AUDIO'],
            rawLine: lastStreamInfoLine!,
          ));
          lastStreamInfoLine = null;
          lastStreamAttrs = null;
        }
      }

      AppLogger.i('Parsed master playlist: ${videoStreams.length} streams, ${audioTracks.length} audio tracks');

      return MasterPlaylist(
        originalUrl: url,
        videoStreams: videoStreams,
        audioTracks: audioTracks,
        baseDomain: baseDomain,
      );
    } catch (e, stack) {
      AppLogger.e('Failed to parse master playlist', e, stack);
      if (e is ParserException) rethrow;
      throw ParserException(
        message: 'Failed to parse master playlist: $e',
        originalError: e,
        stackTrace: stack,
      );
    }
  }

  /// Parse media playlist (segment list)
  static MediaPlaylist parseMediaPlaylist(String content, String url) {
    try {
      final lines = content.split('\n').map((l) => l.trim()).toList();
      
      if (!lines.any((l) => l.startsWith('#EXTM3U'))) {
        throw ParserException(message: 'Invalid M3U8: Missing #EXTM3U header');
      }

      final segments = <Segment>[];
      double? targetDuration;
      int? mediaSequence;
      bool isEndList = false;
      
      double? currentDuration;
      String? currentTitle;
      bool isEncrypted = false;
      String? keyUrl;
      String? iv;
      int segmentIndex = 0;

      // Extract base path from URL
      final uri = Uri.parse(url);
      final baseDomain = '${uri.scheme}://${uri.host}';
      final basePath = url.substring(0, url.lastIndexOf('/') + 1);

      for (final line in lines) {
        if (line.isEmpty) continue;

        if (line.startsWith('#EXT-X-TARGETDURATION')) {
          targetDuration = double.tryParse(line.split(':').last);
        } else if (line.startsWith('#EXT-X-MEDIA-SEQUENCE')) {
          mediaSequence = int.tryParse(line.split(':').last);
        } else if (line.startsWith('#EXT-X-ENDLIST')) {
          isEndList = true;
        } else if (line.startsWith('#EXT-X-KEY')) {
          final attrs = _parseAttributes(line);
          isEncrypted = attrs['METHOD'] != 'NONE';
          keyUrl = _resolveUrl(attrs['URI'], baseDomain, basePath);
          iv = attrs['IV'];
        } else if (line.startsWith('#EXTINF')) {
          // Parse duration and optional title
          final parts = line.substring(8).split(',');
          currentDuration = double.tryParse(parts[0]);
          currentTitle = parts.length > 1 ? parts[1] : null;
        } else if (!line.startsWith('#') && currentDuration != null) {
          // Segment URL
          final segmentUrl = _resolveUrl(line, baseDomain, basePath);
          segments.add(Segment(
            index: segmentIndex++,
            url: segmentUrl,
            duration: currentDuration,
            title: currentTitle,
            isEncrypted: isEncrypted,
            keyUrl: keyUrl,
            iv: iv,
          ));
          currentDuration = null;
          currentTitle = null;
        }
      }

      AppLogger.i('Parsed media playlist: ${segments.length} segments');

      return MediaPlaylist(
        url: url,
        segments: segments,
        targetDuration: targetDuration,
        mediaSequence: mediaSequence,
        isEndList: isEndList,
      );
    } catch (e, stack) {
      AppLogger.e('Failed to parse media playlist', e, stack);
      if (e is ParserException) rethrow;
      throw ParserException(
        message: 'Failed to parse media playlist: $e',
        originalError: e,
        stackTrace: stack,
      );
    }
  }

  /// Build custom master playlist with selected quality and audio
  static String buildCustomMasterPlaylist({
    required VideoStream videoStream,
    AudioTrack? audioTrack,
    required String baseDomain,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('#EXTM3U');
    buffer.writeln('#EXT-X-VERSION:3');

    // Add selected audio track if present
    if (audioTrack != null) {
      var audioLine = audioTrack.rawLine;
      // Fix relative URIs
      if (audioLine.contains('URI="/')) {
        audioLine = audioLine.replaceAll('URI="/', 'URI="$baseDomain/');
      }
      buffer.writeln(audioLine);
    }

    // Add selected video stream
    buffer.writeln(videoStream.rawLine);
    
    // Add video URL (fix if relative)
    var videoUrl = videoStream.url;
    if (videoUrl.startsWith('/')) {
      videoUrl = '$baseDomain$videoUrl';
    }
    buffer.writeln(videoUrl);

    return buffer.toString();
  }

  /// Generate local master.m3u8 for offline playback
  static String generateLocalMasterPlaylist(List<String> segmentPaths) {
    final buffer = StringBuffer();
    buffer.writeln('#EXTM3U');
    buffer.writeln('#EXT-X-VERSION:3');
    buffer.writeln('#EXT-X-TARGETDURATION:10');
    buffer.writeln('#EXT-X-MEDIA-SEQUENCE:0');

    for (var i = 0; i < segmentPaths.length; i++) {
      buffer.writeln('#EXTINF:10.0,');
      buffer.writeln(segmentPaths[i]);
    }

    buffer.writeln('#EXT-X-ENDLIST');
    return buffer.toString();
  }

  /// Parse attributes from M3U8 tag line
  static Map<String, String> _parseAttributes(String line) {
    final attrs = <String, String>{};
    final regex = RegExp(r'([A-Z0-9-]+)=(".*?"|[^,]+)');
    
    for (final match in regex.allMatches(line)) {
      var value = match.group(2) ?? '';
      // Remove quotes
      if (value.startsWith('"') && value.endsWith('"')) {
        value = value.substring(1, value.length - 1);
      }
      attrs[match.group(1)!] = value;
    }
    
    return attrs;
  }

  /// Resolve relative URLs
  static String _resolveUrl(String? url, String baseDomain, String basePath) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('/')) return '$baseDomain$url';
    return '$basePath$url';
  }
}
