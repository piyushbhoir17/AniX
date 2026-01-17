/// Base exception class for the app
class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  final StackTrace? stackTrace;

  AppException({
    required this.message,
    this.code,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() => 'AppException: $message (code: $code)';
}

/// Network-related exceptions
class NetworkException extends AppException {
  NetworkException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });
}

/// Scraper-related exceptions
class ScraperException extends AppException {
  ScraperException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });
}

/// Download-related exceptions
class DownloadException extends AppException {
  DownloadException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });
}

/// Storage-related exceptions
class StorageException extends AppException {
  StorageException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });
}

/// Permission-related exceptions
class PermissionException extends AppException {
  PermissionException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });
}

/// Parser-related exceptions (M3U8, etc.)
class ParserException extends AppException {
  ParserException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });
}
