import 'dart:async';
import 'dart:developer' as developer;

import 'package:blips_mobile/core/error/app_exception.dart';
import 'package:flutter/foundation.dart';

/// Log categories for filtering and organization
enum LogCategory {
  app('APP'),
  network('NET'),
  video('VID'),
  ui('UI'),
  lifecycle('LIFE'),
  error('ERR');

  const LogCategory(this.prefix);
  final String prefix;
}

/// Structured logger for the application.
///
/// Provides:
/// - Categorized logging with prefixes
/// - Debug-only console output
/// - Structured error logging
/// - Production-safe logging (no sensitive data in release)
class AppLogger {
  AppLogger._();

  static final instance = AppLogger._();

  /// Log an info message
  void info(String message, {LogCategory category = LogCategory.app}) {
    _log(message, category: category, level: 800);
  }

  /// Log a debug message (only in debug mode)
  void debug(String message, {LogCategory category = LogCategory.app}) {
    if (kDebugMode) {
      _log(message, category: category, level: 500);
    }
  }

  /// Log a warning
  void warning(
    String message, {
    LogCategory category = LogCategory.app,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      message,
      category: category,
      level: 900,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log an error
  void error(
    String message, {
    LogCategory category = LogCategory.error,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      message,
      category: category,
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log an AppException with full context
  void logException(AppException exception) {
    final category = switch (exception) {
      NetworkException() => LogCategory.network,
      FeatureException(feature: final f) when f == 'video' => LogCategory.video,
      _ => LogCategory.error,
    };

    final level = switch (exception.severity) {
      ExceptionSeverity.warning => 900,
      ExceptionSeverity.error => 1000,
      ExceptionSeverity.critical => 1200,
    };

    _log(
      exception.technicalMessage,
      category: category,
      level: level,
      error: exception.originalError,
      stackTrace: exception.stackTrace,
    );
  }

  /// Record a fatal error for crash reporting
  void fatal(
    String message, {
    required Object error,
    required StackTrace stackTrace,
  }) {
    _log(
      'FATAL: $message',
      category: LogCategory.error,
      level: 1200,
      error: error,
      stackTrace: stackTrace,
    );

    // In production, this would send to crash reporting service
    // e.g., Sentry.captureException(error, stackTrace: stackTrace);
  }

  void _log(
    String message, {
    required LogCategory category,
    required int level,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    final prefix = '[${category.prefix}]';
    final logMessage = '$timestamp $prefix $message';

    if (kDebugMode) {
      // Use dart:developer for better IDE integration
      developer.log(
        logMessage,
        level: level,
        error: error,
        stackTrace: stackTrace,
        name: 'Blips',
      );
    } else {
      // In release, use debugPrint which respects Flutter's logging config
      // This ensures nothing sensitive leaks but critical logs are available
      if (level >= 1000) {
        debugPrint(logMessage);
      }
    }
  }
}

/// Global logger instance for convenience
final logger = AppLogger.instance;

/// Zone error handler for async errors
void handleZoneError(Object error, StackTrace stackTrace) {
  if (error is AppException) {
    logger.logException(error);
  } else {
    logger.fatal(
      'Unhandled zone error: $error',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

/// Run a zone with error handling.
///
/// Note: This catches synchronous errors within the action.
/// Returns null if an error was caught by the zone.
Future<T?> runWithErrorHandling<T>(Future<T> Function() action) async {
  T? result;
  await runZonedGuarded(
    () async {
      result = await action();
    },
    handleZoneError,
  );
  return result;
}
