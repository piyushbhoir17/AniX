import 'dart:convert';
import 'package:html/parser.dart' as parser;
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/logger.dart';
import '../models/anime.dart';

/// Service to scrape search results from watchanimeworld
class SearchService {
  SearchService._();
  static final SearchService instance = SearchService._();

  Future<List<Anime>> searchAnime(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final encodedQuery = Uri.encodeQueryComponent(query.trim());
      final url = '${AppConstants.baseUrl}/?s=$encodedQuery';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw NetworkException(message: 'Failed to load search results');
      }

      final document = parser.parse(utf8.decode(response.bodyBytes));
      final results = <Anime>[];
      final seen = <String>{};

      // Find all links to series pages
      final links = document.querySelectorAll('a');
      for (final link in links) {
        final href = link.attributes['href'] ?? '';
        if (!href.contains('/series/')) continue;

        final animeId = _extractAnimeId(href);
        if (animeId == null || seen.contains(animeId)) continue;

        final title = _extractTitle(link) ?? _extractTitleFromParent(link) ?? animeId.replaceAll('-', ' ');
        final coverUrl = _extractCoverUrl(link);

        seen.add(animeId);
        results.add(Anime.create(
          animeId: animeId,
          title: _normalizeTitle(title),
          coverUrl: coverUrl,
        )
          ..sourceUrl = href);
      }

      AppLogger.i('Search results for "$query": ${results.length}');
      return results;
    } catch (e, stack) {
      AppLogger.e('Search failed', e, stack);
      if (e is AppException) rethrow;
      throw NetworkException(message: 'Search failed: $e', originalError: e, stackTrace: stack);
    }
  }

  String? _extractCoverUrl(dynamic link) {
    final candidates = <dynamic>[link, link.parent, link.parent?.parent, link.parent?.parent?.parent];
    for (final node in candidates) {
      if (node == null) continue;
      final img = node.querySelector('img');
      if (img == null) continue;
      final url = img.attributes['data-src'] ??
          img.attributes['data-lazy-src'] ??
          img.attributes['data-lazy-srcset'] ??
          img.attributes['srcset'] ??
          img.attributes['src'];
      if (url != null && url.isNotEmpty) {
        return url.split(' ').first;
      }
    }
    return null;
  }

  String? _extractAnimeId(String href) {
    try {
      final uri = Uri.parse(href);
      final segments = uri.pathSegments;
      final seriesIndex = segments.indexOf('series');
      if (seriesIndex == -1 || segments.length <= seriesIndex + 1) return null;
      return segments[seriesIndex + 1].trim();
    } catch (_) {
      return null;
    }
  }

  String? _extractTitle(dynamic link) {
    final title = link.attributes['title'] ?? link.text;
    return title.trim().isEmpty ? null : title.trim();
  }

  String? _extractTitleFromParent(dynamic link) {
    final parent = link.parent;
    if (parent == null) return null;
    final heading = parent.querySelector('h2, h3, h4');
    if (heading == null) return null;
    final text = heading.text.trim();
    return text.isEmpty ? null : text;
  }

  String _normalizeTitle(String title) {
    return title.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
