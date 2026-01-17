import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/logger.dart';
import '../models/m3u8_models.dart';
import 'm3u8_parser.dart';

/// Service for scraping anime episode URLs using WebView
class ScraperService {
  ScraperService._();
  static final ScraperService instance = ScraperService._();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: AppConstants.networkTimeout,
    receiveTimeout: AppConstants.networkTimeout,
    headers: {
      'User-Agent': AppConstants.userAgent,
    },
  ));

  HeadlessInAppWebView? _webView;
  Completer<String?>? _m3u8Completer;
  String? _capturedM3u8Url;
  String? _capturedReferer;
  String? _capturedCookies;

  /// Sniff M3U8 URL from episode page
  Future<ScraperResult> sniffM3u8Url(String episodeUrl) async {
    AppLogger.i('Starting to sniff M3U8 from: $episodeUrl');
    
    _m3u8Completer = Completer<String?>();
    _capturedM3u8Url = null;
    _capturedReferer = null;
    _capturedCookies = null;

    try {
      // Create headless WebView
      _webView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(
          url: WebUri(episodeUrl),
          headers: {'User-Agent': AppConstants.userAgent},
        ),
        initialSettings: InAppWebViewSettings(
          userAgent: AppConstants.userAgent,
          javaScriptEnabled: true,
          mediaPlaybackRequiresUserGesture: false,
          allowsInlineMediaPlayback: true,
          useShouldInterceptRequest: true,
        ),
        onLoadStop: (controller, url) async {
          AppLogger.d('Page loaded: $url');
          _capturedReferer = url?.toString();

          // Try to find and click on iframe if zephyrflick
          try {
            final iframeSrc = await controller.evaluateJavascript(source: '''
              (function() {
                var iframe = document.querySelector('iframe');
                return iframe ? iframe.src : null;
              })();
            ''');

            if (iframeSrc != null && iframeSrc.toString().contains('zephyrflick')) {
              AppLogger.d('Found zephyrflick iframe, navigating...');
              await controller.loadUrl(urlRequest: URLRequest(url: WebUri(iframeSrc.toString())));
            }
          } catch (e) {
            AppLogger.w('Failed to check for iframe: $e');
          }

          // Try to click play button after a delay
          Future.delayed(const Duration(seconds: 2), () async {
            try {
              await controller.evaluateJavascript(source: '''
                (function() {
                  var playBtn = document.querySelector('.jw-display-icon-container');
                  if (playBtn) playBtn.click();
                  else {
                    var video = document.querySelector('video');
                    if (video) video.play();
                  }
                })();
              ''');
            } catch (e) {
              AppLogger.w('Failed to click play: $e');
            }
          });

          // Get cookies
          final cookies = await CookieManager.instance().getCookies(url: url!);
          _capturedCookies = _cookiesToNetscapeString(cookies);
        },
        shouldInterceptRequest: (controller, request) async {
          final url = request.url.toString();
          
          // Check for M3U8 or master.txt
          if ((url.contains('.m3u8') || url.contains('master.txt')) && 
              !url.contains('cdn-cgi')) {
            AppLogger.i('Captured M3U8 URL: $url');
            _capturedM3u8Url = url;
            
            if (!_m3u8Completer!.isCompleted) {
              _m3u8Completer!.complete(url);
            }
          }
          
          return null; // Continue with request
        },
        onReceivedError: (controller, request, error) {
          AppLogger.w('WebView error: ${error.description}');
        },
      );

      // Start WebView
      await _webView!.run();

      // Wait for M3U8 with timeout
      final result = await _m3u8Completer!.future.timeout(
        AppConstants.sniffTimeout,
        onTimeout: () => null,
      );

      // Dispose WebView
      await _disposeWebView();

      if (result == null) {
        throw ScraperException(message: 'Timeout: Could not find M3U8 URL');
      }

      return ScraperResult(
        m3u8Url: result,
        referer: _capturedReferer,
        cookies: _capturedCookies,
      );
    } catch (e, stack) {
      await _disposeWebView();
      AppLogger.e('Scraper error', e, stack);
      
      if (e is ScraperException) rethrow;
      throw ScraperException(
        message: 'Failed to scrape episode: $e',
        originalError: e,
        stackTrace: stack,
      );
    }
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
    // Build custom master playlist
    final customM3u8 = M3U8Parser.buildCustomMasterPlaylist(
      videoStream: selection.videoStream,
      audioTrack: selection.audioTrack,
      baseDomain: masterPlaylist.baseDomain ?? '',
    );

    // For streaming, we return the video stream URL directly
    // The player will handle the M3U8 parsing
    return selection.videoStream.url;
  }

  /// Convert cookies to Netscape format string
  String _cookiesToNetscapeString(List<Cookie> cookies) {
    final buffer = StringBuffer();
    for (final cookie in cookies) {
      final domain = cookie.domain?.startsWith('.') == true 
          ? cookie.domain! 
          : '.${cookie.domain ?? ''}';
      buffer.write('${cookie.name}=${cookie.value}; ');
    }
    return buffer.toString().trim();
  }

  /// Dispose WebView
  Future<void> _disposeWebView() async {
    try {
      await _webView?.dispose();
      _webView = null;
    } catch (e) {
      AppLogger.w('Failed to dispose WebView: $e');
    }
  }

  /// Dispose service
  void dispose() {
    _disposeWebView();
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
