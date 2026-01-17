import 'package:dio/dio.dart';

/// Severity level for exceptions
enum ExceptionSeverity {
  /// User-recoverable errors (network timeout, validation)
  warning,

  /// Application errors that need attention
  error,

  /// Critical failures (unhandled crashes)
  critical,
}

/// Base exception class for all app-specific exceptions.
///
/// Provides structured error information with:
/// - User-friendly messages
/// - Technical details for logging
/// - Severity classification
/// - Optional recovery actions
sealed class AppException implements Exception {
  const AppException({
    required this.userMessage,
    required this.technicalMessage,
    required this.severity,
    this.originalError,
    this.stackTrace,
  });

  /// Message suitable for display to users
  final String userMessage;

  /// Technical details for logging/debugging
  final String technicalMessage;

  /// Severity level for error handling
  final ExceptionSeverity severity;

  /// Original error that caused this exception
  final Object? originalError;

  /// Stack trace from original error
  final StackTrace? stackTrace;

  @override
  String toString() => 'AppException: $technicalMessage';
}

/// Network-related exceptions
class NetworkException extends AppException {
  const NetworkException({
    required super.userMessage,
    required super.technicalMessage,
    super.severity = ExceptionSeverity.warning,
    super.originalError,
    super.stackTrace,
    this.statusCode,
    this.isRetryable = true,
  });

  /// HTTP status code if available
  final int? statusCode;

  /// Whether the request can be retried
  final bool isRetryable;

  /// Create a copy with optional overrides
  NetworkException copyWith({
    String? userMessage,
    String? technicalMessage,
    ExceptionSeverity? severity,
    Object? originalError,
    StackTrace? stackTrace,
    int? statusCode,
    bool? isRetryable,
  }) {
    return NetworkException(
      userMessage: userMessage ?? this.userMessage,
      technicalMessage: technicalMessage ?? this.technicalMessage,
      severity: severity ?? this.severity,
      originalError: originalError ?? this.originalError,
      stackTrace: stackTrace ?? this.stackTrace,
      statusCode: statusCode ?? this.statusCode,
      isRetryable: isRetryable ?? this.isRetryable,
    );
  }

  /// Creates from a Dio error
  factory NetworkException.fromDioError(DioException error) {
    final statusCode = error.response?.statusCode;

    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        NetworkException(
          userMessage: 'Connection timed out. Please check your internet.',
          technicalMessage: 'Timeout: ${error.type.name}',
          statusCode: statusCode,
          originalError: error,
          stackTrace: error.stackTrace,
        ),
      DioExceptionType.connectionError => NetworkException(
          userMessage: 'Unable to connect. Please check your internet.',
          technicalMessage: 'Connection error: ${error.message}',
          originalError: error,
          stackTrace: error.stackTrace,
        ),
      DioExceptionType.badResponse => _fromBadResponse(error, statusCode),
      DioExceptionType.cancel => NetworkException(
          userMessage: 'Request was cancelled.',
          technicalMessage: 'Request cancelled',
          isRetryable: false,
          originalError: error,
          stackTrace: error.stackTrace,
        ),
      _ => NetworkException(
          userMessage: 'Something went wrong. Please try again.',
          technicalMessage: 'Unknown network error: ${error.message}',
          originalError: error,
          stackTrace: error.stackTrace,
        ),
    };
  }

  static NetworkException _fromBadResponse(
    DioException error,
    int? statusCode,
  ) {
    final code = statusCode ?? 0;
    final (userMessage, severity, isRetryable) = switch (code) {
      400 => (
          'Invalid request. Please try again.',
          ExceptionSeverity.warning,
          false,
        ),
      401 => (
          'Session expired. Please sign in again.',
          ExceptionSeverity.warning,
          false,
        ),
      403 => ('Access denied.', ExceptionSeverity.warning, false),
      404 => ('Content not found.', ExceptionSeverity.warning, false),
      >= 500 && < 600 => (
          'Server is having issues. Please try later.',
          ExceptionSeverity.error,
          true,
        ),
      _ => ('Something went wrong.', ExceptionSeverity.warning, true),
    };

    return NetworkException(
      userMessage: userMessage,
      technicalMessage: 'HTTP $statusCode: ${error.response?.data}',
      severity: severity,
      statusCode: statusCode,
      isRetryable: isRetryable,
      originalError: error,
      stackTrace: error.stackTrace,
    );
  }
}

/// Data parsing/validation exceptions
class DataException extends AppException {
  const DataException({
    required super.userMessage,
    required super.technicalMessage,
    super.severity = ExceptionSeverity.error,
    super.originalError,
    super.stackTrace,
  });

  /// Creates from a JSON parsing error
  factory DataException.fromParseError(Object error, [StackTrace? stack]) {
    return DataException(
      userMessage: 'Unable to load content. Please try again.',
      technicalMessage: 'Parse error: $error',
      originalError: error,
      stackTrace: stack,
    );
  }
}

/// Platform/device exceptions
class PlatformException extends AppException {
  const PlatformException({
    required super.userMessage,
    required super.technicalMessage,
    super.severity = ExceptionSeverity.error,
    super.originalError,
    super.stackTrace,
  });
}

/// Feature-specific exceptions
class FeatureException extends AppException {
  const FeatureException({
    required super.userMessage,
    required super.technicalMessage,
    super.severity = ExceptionSeverity.warning,
    super.originalError,
    super.stackTrace,
    required this.feature,
  });

  /// The feature that encountered the error
  final String feature;
}
