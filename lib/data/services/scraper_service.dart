import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/logger.dart';
import '../models/anime.dart';
import '../models/anime_detail.dart';
import '../models/episode.dart';
import '../models/m3u8_models.dart';
import 'm3u8_parser.dart';

/// Service for scraping anime episode URLs using Dio HTTP requests
class ScraperService {
  ScraperService._();
  static final ScraperService instance = ScraperService._();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: AppConstants.networkTimeout,
    receiveTimeout: AppConstants.networkTimeout,
    headers: {
      'User-Agent': AppConstants.userAgent,
    },
    followRedirects: true,
    maxRedirects: 5,
  ));

  /// Sniff M3U8 URL from episode page using HTTP requests (no WebView)
  Future<ScraperResult> sniffM3u8Url(String episodeUrl) async {
    AppLogger.i('Starting to extract M3U8 from: $episodeUrl');

    try {
      // Step 1: Get episode page and extract iframe URL
      AppLogger.d('Step 1: Fetching episode page...');
      final epResponse = await _dio.get(
        episodeUrl,
        options: Options(headers: {'User-Agent': AppConstants.userAgent}),
      );
      final epHtml = epResponse.data.toString();

      // Extract iframe URL (zephyr or watchanimeworld)
      final iframeUrl = _extractIframeUrl(epHtml);
      if (iframeUrl == null) {
        throw ScraperException(message: 'No video iframe found on episode page');
      }
      AppLogger.i('Found iframe URL: $iframeUrl');

      // Step 2: Get iframe page content
      AppLogger.d('Step 2: Fetching iframe page...');
      final iframeResponse = await _dio.get(
        iframeUrl,
        options: Options(headers: {
          'User-Agent': AppConstants.userAgent,
          'Referer': episodeUrl,
        }),
      );
      final iframeHtml = iframeResponse.data.toString();

      // Step 3: Unpack JavaScript if packed and extract Video ID
      AppLogger.d('Step 3: Extracting video ID...');
      final unpackedHtml = _unpackJavaScript(iframeHtml);
      final videoId = _extractVideoId(unpackedHtml.isNotEmpty ? unpackedHtml : iframeHtml);
      
      if (videoId == null) {
        throw ScraperException(message: 'Failed to extract video ID from iframe');
      }
      AppLogger.i('Found video ID: $videoId');

      // Step 4: Call API to get M3U8 URL
      AppLogger.d('Step 4: Calling video API...');
      final iframeRoot = _getUrlRoot(iframeUrl);
      final apiUrl = '$iframeRoot/player/index.php?data=$videoId&do=getVideo';
      
      final apiResponse = await _dio.post(
        apiUrl,
        data: 'hash=$videoId&r=$iframeUrl',
        options: Options(
          headers: {
            'User-Agent': AppConstants.userAgent,
            'Referer': iframeUrl,
            'X-Requested-With': 'XMLHttpRequest',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        ),
      );

      // Parse JSON response
      final jsonData = apiResponse.data is String 
          ? json.decode(apiResponse.data) 
          : apiResponse.data;
      
      final m3u8Url = jsonData['videoSource'] ?? jsonData['file'];
      if (m3u8Url == null || m3u8Url.toString().isEmpty) {
        AppLogger.e('API response: $jsonData');
        throw ScraperException(message: 'API returned no video URL');
      }
      
      AppLogger.i('Got M3U8 URL: $m3u8Url');

      return ScraperResult(
        m3u8Url: m3u8Url.toString(),
        referer: iframeUrl,
        cookies: null,
      );
    } catch (e, stack) {
      AppLogger.e('Scraper error', e, stack);
      
      if (e is ScraperException) rethrow;
      throw ScraperException(
        message: 'Failed to scrape episode: $e',
        originalError: e,
        stackTrace: stack,
      );
    }
  }

  /// Extract iframe URL from episode page HTML
  String? _extractIframeUrl(String html) {
    // Pattern: <iframe src="..." or <iframe src='...'
    final pattern = RegExp(r'<iframe[^>]+src=["\x27]([^"\x27]+)["\x27]', caseSensitive: false);
    final matches = pattern.allMatches(html);
    
    for (final match in matches) {
      final url = match.group(1);
      if (url != null && (url.contains('zephyr') || url.contains('watchanimeworld') || url.contains('player') || url.contains('embed'))) {
        return url;
      }
    }

    // Fallback: get first iframe
    final fallbackMatch = pattern.firstMatch(html);
    return fallbackMatch?.group(1);
  }

  /// Unpack JavaScript (p,a,c,k,e,d) obfuscation
  String _unpackJavaScript(String html) {
    // Match the packed JavaScript pattern
    final packedRegex = RegExp(
      r"return p\}\s*\(\s*'(.*?)'\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*'([^']+)'\.split\('\|'\)",
      dotAll: true,
    );

    final match = packedRegex.firstMatch(html);
    if (match == null) {
      AppLogger.d('No packed JavaScript found');
      return '';
    }

    try {
      final p = match.group(1)!;
      final a = int.parse(match.group(2)!);
      final c = int.parse(match.group(3)!);
      final k = match.group(4)!.split('|');

      // Base conversion function
      String baseN(int value, int radix) {
        if (value < radix) {
          return value < 36 
              ? value.toRadixString(36) 
              : String.fromCharCode(value + 29);
        }
        return baseN(value ~/ radix, radix) + baseN(value % radix, radix);
      }

      // Build replacement dictionary
      final dict = <String, String>{};
      for (var i = 0; i < c; i++) {
        final key = baseN(i, a);
        if (i < k.length && k[i].isNotEmpty) {
          dict[key] = k[i];
        } else {
          dict[key] = key;
        }
      }

      // Replace all words
      var result = p;
      for (final entry in dict.entries) {
        result = result.replaceAll(RegExp('\\b${entry.key}\\b'), entry.value);
      }

      AppLogger.d('Successfully unpacked JavaScript');
      return result;
    } catch (e) {
      AppLogger.w('Failed to unpack JavaScript: $e');
      return '';
    }
  }

  /// Extract video ID from FirePlayer call
  String? _extractVideoId(String html) {
    // Pattern: FirePlayer("VIDEO_ID") or FirePlayer('VIDEO_ID')
    final patterns = [
      RegExp(r'FirePlayer\s*\(\s*["\x27]([^"\x27]+)["\x27]'),
      RegExp(r'data-id\s*=\s*["\x27]([^"\x27]+)["\x27]'),
      RegExp(r'video_id\s*[=:]\s*["\x27]([^"\x27]+)["\x27]'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      if (match != null) {
        return match.group(1);
      }
    }

    return null;
  }

  /// Get root URL (protocol + domain)
  String _getUrlRoot(String url) {
    final uri = Uri.parse(url);
    return '${uri.scheme}://${uri.host}';
  }

  /// Fetch anime details + episode list from series page
  Future<AnimeDetail> fetchAnimeDetail(String seriesUrl, String animeId) async {
    try {
      final response = await _dio.get(
        seriesUrl,
        options: Options(headers: {'User-Agent': AppConstants.userAgent}),
      );

      if (response.statusCode != 200) {
        throw ScraperException(message: 'Failed to fetch series page: HTTP ${response.statusCode}');
      }

      final html = response.data.toString();
      final document = html_parser.parse(html);
      final title = _extractSeriesTitle(document) ?? animeId.replaceAll('-', ' ');
      final description = _extractDescription(document);
      final coverUrl = _extractCoverUrl(document);
      final bannerUrl = _extractBannerUrl(document);
      final status = _extractMetaValue(document, ['status', 'status:']);
      final type = _extractMetaValue(document, ['type', 'type:']);
      final releaseYear = _extractMetaValue(document, ['year', 'released', 'release']);
      final totalEpisodes = _extractTotalEpisodes(document);
      final genres = _extractGenres(document);

      final anime = Anime.create(
        animeId: animeId,
        title: title,
        coverUrl: coverUrl,
        bannerUrl: bannerUrl,
        description: description,
        status: status,
        type: type,
        releaseYear: releaseYear,
        totalEpisodes: totalEpisodes,
        genres: genres,
      )
        ..sourceUrl = seriesUrl;

      // Extract post ID and seasons for AJAX fetching
      final postId = _extractPostId(html);
      final seasonNumbers = _extractSeasonNumbers(html);
      
      Map<String, List<Episode>> episodesBySeason;
      
      if (postId != null && seasonNumbers.isNotEmpty) {
        // Fetch all seasons via AJAX
        AppLogger.i('Found post ID: $postId, seasons: $seasonNumbers');
        episodesBySeason = await _fetchAllSeasons(seriesUrl, postId, seasonNumbers, animeId, html);
      } else {
        // Fallback to scraping from main page
        AppLogger.w('No post ID or seasons found, falling back to main page scrape');
        episodesBySeason = _extractEpisodesBySeason(document, animeId);
      }

      return AnimeDetail(anime: anime, episodesBySeason: episodesBySeason);
    } catch (e, stack) {
      AppLogger.e('Failed to fetch anime detail', e, stack);
      if (e is ScraperException) rethrow;
      throw ScraperException(
        message: 'Failed to fetch anime detail: $e',
        originalError: e,
        stackTrace: stack,
      );
    }
  }

  /// Extract the WordPress post ID from HTML
  String? _extractPostId(String html) {
    final regex = RegExp(r'data-post="(\d+)"');
    final match = regex.firstMatch(html);
    return match?.group(1);
  }

  /// Extract all available season numbers from HTML
  List<int> _extractSeasonNumbers(String html) {
    final regex = RegExp(r'data-season="(\d+)"');
    final matches = regex.allMatches(html);
    final seasons = matches.map((m) => int.tryParse(m.group(1) ?? '') ?? 0).where((s) => s > 0).toSet().toList();
    seasons.sort();
    return seasons;
  }

  /// Fetch all seasons via AJAX endpoint
  Future<Map<String, List<Episode>>> _fetchAllSeasons(
    String seriesUrl,
    String postId,
    List<int> seasonNumbers,
    String animeId,
    String mainPageHtml,
  ) async {
    final baseDomain = Uri.parse(seriesUrl).origin;
    final ajaxUrl = '$baseDomain/wp-admin/admin-ajax.php';
    final allEpisodeUrls = <String>{};

    // Fetch each season via AJAX
    for (final seasonNum in seasonNumbers) {
      try {
        AppLogger.i('Fetching Season $seasonNum...');
        final response = await _dio.post(
          ajaxUrl,
          data: 'action=action_select_season&season=$seasonNum&post=$postId',
          options: Options(
            headers: {
              'User-Agent': AppConstants.userAgent,
              'Content-Type': 'application/x-www-form-urlencoded',
            },
          ),
        );

        if (response.statusCode == 200) {
          final seasonHtml = response.data.toString();
          final urls = _extractEpisodeUrls(seasonHtml);
          allEpisodeUrls.addAll(urls);
          AppLogger.i('Season $seasonNum: found ${urls.length} episode URLs');
        }

        // Brief delay to be nice to the server
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        AppLogger.w('Failed to fetch season $seasonNum: $e');
      }
    }

    // Also extract from main page (may contain latest season)
    final mainPageUrls = _extractEpisodeUrls(mainPageHtml);
    allEpisodeUrls.addAll(mainPageUrls);

    AppLogger.i('Total unique episode URLs: ${allEpisodeUrls.length}');

    // Parse all URLs into episodes grouped by season
    return _parseEpisodeUrls(allEpisodeUrls, animeId);
  }

  /// Extract episode URLs from HTML content
  List<String> _extractEpisodeUrls(String html) {
    final regex = RegExp(r'href="([^"]*\/episode\/[^"]*-\d+x\d+\/?)"');
    final matches = regex.allMatches(html);
    return matches.map((m) => m.group(1) ?? '').where((url) => url.isNotEmpty).toList();
  }

  /// Parse episode URLs into structured episodes by season
  Map<String, List<Episode>> _parseEpisodeUrls(Set<String> urls, String animeId) {
    final seasons = <String, List<Episode>>{};
    final seasonEpisodeRegex = RegExp(r'-(\d+)x(\d+)\/?$');

    for (final url in urls) {
      final normalizedUrl = url.replaceAll(RegExp(r'/$'), '');
      final match = seasonEpisodeRegex.firstMatch(normalizedUrl);

      if (match != null) {
        final seasonNum = int.tryParse(match.group(1) ?? '1') ?? 1;
        final episodeNum = int.tryParse(match.group(2) ?? '1') ?? 1;
        final seasonKey = 'Season $seasonNum';

        // Generate title from URL
        final title = 'Episode $episodeNum';

        // Ensure absolute URL
        final absoluteUrl = url.startsWith('http')
            ? url
            : url.startsWith('/')
                ? '${AppConstants.baseUrl}$url'
                : '${AppConstants.baseUrl}/$url';

        final episode = Episode.create(
          animeId: animeId,
          episodeNumber: episodeNum,
          title: title,
          sourceUrl: absoluteUrl,
        );

        seasons.putIfAbsent(seasonKey, () => []).add(episode);
      }
    }

    // Sort and deduplicate episodes within each season
    for (final seasonKey in seasons.keys) {
      final episodeList = seasons[seasonKey]!;
      final uniqueEpisodes = <int, Episode>{};
      for (final ep in episodeList) {
        uniqueEpisodes.putIfAbsent(ep.episodeNumber, () => ep);
      }
      seasons[seasonKey] = uniqueEpisodes.values.toList()
        ..sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
    }

    // Log results
    for (final entry in seasons.entries) {
      AppLogger.i('${entry.key}: ${entry.value.length} episodes');
    }

    return seasons;
  }

  /// Fetch and parse master playlist
  Future<MasterPlaylist> fetchMasterPlaylist(ScraperResult scraperResult) async {
    try {
      final response = await _dio.get(
        scraperResult.m3u8Url,
        options: Options(
          headers: {
            'User-Agent': AppConstants.userAgent,
            if (scraperResult.referer != null) 'Referer': scraperResult.referer!,
            if (scraperResult.cookies != null) 'Cookie': scraperResult.cookies!,
          },
        ),
      );

      if (response.statusCode != 200) {
        throw ScraperException(
          message: 'Failed to fetch playlist: HTTP ${response.statusCode}',
        );
      }

      final content = response.data.toString();
      return M3U8Parser.parseMasterPlaylist(content, scraperResult.m3u8Url);
    } catch (e, stack) {
      AppLogger.e('Failed to fetch master playlist', e, stack);
      if (e is ScraperException) rethrow;
      throw ScraperException(
        message: 'Failed to fetch master playlist: $e',
        originalError: e,
        stackTrace: stack,
      );
    }
  }

  String? _extractSeriesTitle(dynamic document) {
    final title = document.querySelector('h1')?.text ??
        document.querySelector('h2')?.text ??
        document.querySelector('.entry-title')?.text ??
        document.querySelector('title')?.text;
    return title?.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String? _extractDescription(dynamic document) {
    final candidates = [
      document.querySelector('.entry-content p'),
      document.querySelector('.anime-details p'),
      document.querySelector('.description'),
    ];
    for (final node in candidates) {
      final text = node?.text?.trim();
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  String? _extractCoverUrl(dynamic document) {
    final img = document.querySelector('img');
    if (img == null) return null;
    final raw = img.attributes['data-src'] ??
        img.attributes['data-lazy-src'] ??
        img.attributes['src'] ??
        img.attributes['srcset'];
    return _normalizeImageUrl(raw);
  }

  String? _extractBannerUrl(dynamic document) {
    final banner = document.querySelector('.cover img') ?? document.querySelector('.banner img');
    if (banner == null) return null;
    final raw = banner.attributes['data-src'] ?? banner.attributes['src'];
    return _normalizeImageUrl(raw);
  }

  String? _extractMetaValue(dynamic document, List<String> labels) {
    final text = document.body?.text ?? '';
    for (final label in labels) {
      final regex = RegExp('$label\\s*:?\\s*([^\\n]+)', caseSensitive: false);
      final match = regex.firstMatch(text);
      if (match != null) {
        return match.group(1)?.trim();
      }
    }
    return null;
  }

  int? _extractTotalEpisodes(dynamic document) {
    final text = document.body?.text ?? '';
    final regex = RegExp(r'Episodes?\s*:?\s*(\d+)', caseSensitive: false);
    final match = regex.firstMatch(text);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '');
    }
    return null;
  }

  List<String> _extractGenres(dynamic document) {
    final genres = <String>[];
    final nodes = document.querySelectorAll('a');
    for (final node in nodes) {
      final href = node.attributes['href'] ?? '';
      if (!href.contains('/genre/')) continue;
      final text = node.text.trim();
      if (text.isNotEmpty && !genres.contains(text)) {
        genres.add(text);
      }
    }
    return genres;
  }

  Map<String, List<Episode>> _extractEpisodesBySeason(dynamic document, String animeId) {
    final seasons = <String, List<Episode>>{};
    final seenUrls = <String>{};
    
    // Get all links on the page
    final allLinks = document.querySelectorAll('a');

    // Pattern: /episode/$series-name-$seasonx$episode/
    // Examples:
    //   /episode/naruto-1x5/     -> Season 1, Episode 5
    //   /episode/naruto-2x10/    -> Season 2, Episode 10
    //   /episode/naruto-shippuden-3x15/ -> Season 3, Episode 15
    //   /episode/naruto-5/       -> Season 1, Episode 5 (no season prefix)
    final seasonEpisodeRegex = RegExp(r'-(\d+)x(\d+)/?$');
    final episodeOnlyRegex = RegExp(r'-(\d+)/?$');

    for (final link in allLinks) {
      final href = link.attributes['href'] ?? '';
      
      // Skip if not an episode link
      if (!href.contains('/episode/')) continue;
      
      // Skip if we've already processed this URL (avoid duplicates)
      final normalizedHref = href.replaceAll(RegExp(r'/$'), ''); // Remove trailing slash
      if (seenUrls.contains(normalizedHref)) continue;
      seenUrls.add(normalizedHref);

      // Get title from link text or generate from URL
      var title = link.text.trim();
      if (title.isEmpty || title.length > 100) {
        // Extract episode info from URL for title
        final urlParts = normalizedHref.split('/');
        title = urlParts.isNotEmpty ? urlParts.last.replaceAll('-', ' ') : 'Episode';
      }

      int seasonNum = 1;
      int episodeNum = 1;

      // Try to match season x episode pattern first (e.g., -2x5)
      final seasonMatch = seasonEpisodeRegex.firstMatch(normalizedHref);
      if (seasonMatch != null) {
        seasonNum = int.tryParse(seasonMatch.group(1) ?? '1') ?? 1;
        episodeNum = int.tryParse(seasonMatch.group(2) ?? '1') ?? 1;
      } else {
        // Fall back to episode-only pattern (e.g., -5)
        final episodeMatch = episodeOnlyRegex.firstMatch(normalizedHref);
        if (episodeMatch != null) {
          episodeNum = int.tryParse(episodeMatch.group(1) ?? '1') ?? 1;
        }
      }

      final seasonKey = 'Season $seasonNum';

      // Ensure the URL is absolute
      final absoluteUrl = href.startsWith('http') 
          ? href 
          : href.startsWith('/') 
              ? '${AppConstants.baseUrl}$href'
              : '${AppConstants.baseUrl}/$href';

      final episode = Episode.create(
        animeId: animeId,
        episodeNumber: episodeNum,
        title: title,
        sourceUrl: absoluteUrl,
      );

      seasons.putIfAbsent(seasonKey, () => []).add(episode);
    }

    // Sort episodes within each season by episode number
    for (final seasonKey in seasons.keys) {
      seasons[seasonKey]!.sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
    }

    // Remove duplicate episodes (same episode number in same season)
    for (final seasonKey in seasons.keys) {
      final episodeList = seasons[seasonKey]!;
      final uniqueEpisodes = <int, Episode>{};
      for (final ep in episodeList) {
        // Keep first occurrence of each episode number
        uniqueEpisodes.putIfAbsent(ep.episodeNumber, () => ep);
      }
      seasons[seasonKey] = uniqueEpisodes.values.toList()
        ..sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
    }

    AppLogger.i('Extracted ${seasons.entries.map((e) => '${e.key}: ${e.value.length} eps').join(', ')}');

    return seasons;
  }

  String? _normalizeImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final trimmed = url.trim();
    if (trimmed.startsWith('data:image')) return null;

    final parts = trimmed.split(',');
    final candidate = parts.first.trim();
    final candidateParts = candidate.split(' ');
    final rawUrl = candidateParts.first.trim();

    if (rawUrl.startsWith('//')) {
      return 'https:$rawUrl';
    }
    if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
      return rawUrl;
    }
    if (rawUrl.startsWith('/')) {
      return '${AppConstants.baseUrl}$rawUrl';
    }
    return '${AppConstants.baseUrl}/$rawUrl';
  }

  /// Fetch and parse media playlist (segment list)
  Future<MediaPlaylist> fetchMediaPlaylist(
    String url, {
    String? referer,
    String? cookies,
  }) async {
    try {
      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            'User-Agent': AppConstants.userAgent,
            if (referer != null) 'Referer': referer,
            if (cookies != null) 'Cookie': cookies,
          },
        ),
      );

      if (response.statusCode != 200) {
        throw ScraperException(
          message: 'Failed to fetch media playlist: HTTP ${response.statusCode}',
        );
      }

      final content = response.data.toString();
      return M3U8Parser.parseMediaPlaylist(content, url);
    } catch (e, stack) {
      AppLogger.e('Failed to fetch media playlist', e, stack);
      if (e is ScraperException) rethrow;
      throw ScraperException(
        message: 'Failed to fetch media playlist: $e',
        originalError: e,
        stackTrace: stack,
      );
    }
  }

  /// Build streaming URL with selected quality/language
  Future<String> buildStreamUrl({
    required ScraperResult scraperResult,
    required MasterPlaylist masterPlaylist,
    required StreamSelection selection,
  }) async {
    // For streaming, we return the video stream URL directly
    // The player will handle the M3U8 parsing
    return selection.videoStream.url;
  }

  /// Convert cookies to Netscape format string
  String _cookiesToNetscapeString(List<Cookie> cookies) {
    final buffer = StringBuffer();
    for (final cookie in cookies) {
      buffer.write('${cookie.name}=${cookie.value}; ');
    }
    return buffer.toString().trim();
  }

  /// Dispose service
  void dispose() {
    _dio.close();
  }
}

/// Result from scraper containing M3U8 URL and auth info
class ScraperResult {
  final String m3u8Url;
  final String? referer;
  final String? cookies;

  ScraperResult({
    required this.m3u8Url,
    this.referer,
    this.cookies,
  });

  @override
  String toString() => 'ScraperResult(m3u8Url: $m3u8Url)';
}
