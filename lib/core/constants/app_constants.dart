/// App-wide constants
class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'AniX';
  static const String appVersion = '1.0.0';
  static const String packageName = 'com.sleepy.anix';

  // Scraper
  static const String baseUrl = 'https://watchanimeworld.net';
  static const String userAgent =
      'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';
  static const Duration networkTimeout = Duration(seconds: 30);
  static const Duration sniffTimeout = Duration(seconds: 30);

  // Download
  static const int parallelSegments = 4;
  static const String downloadFolderName = 'AniX';
  static const int maxRetries = 3;

  // Cache
  static const Duration cacheExpiry = Duration(days: 7);
  static const int maxCachedImages = 200;

  // UI
  static const double cardBorderRadius = 16.0;
  static const double defaultPadding = 16.0;
  static const Duration animationDuration = Duration(milliseconds: 300);
}
