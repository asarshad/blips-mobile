import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:blips_mobile/core/error/app_exception.dart';
import 'package:blips_mobile/core/error/app_logger.dart';
import 'package:flutter/foundation.dart';

/// Centralized error handler for the application.
///
/// Captures:
/// - Flutter framework errors
/// - Platform dispatcher errors
/// - Async zone errors
///
/// Provides hooks for crash reporting services.
class ErrorHandler {
  ErrorHandler._();

  static final instance = ErrorHandler._();

  /// Initialize global error handling
  void initialize() {
    // Handle Flutter framework errors
    FlutterError.onError = _handleFlutterError;

    // Handle platform errors (native crashes, etc.)
    PlatformDispatcher.instance.onError = _handlePlatformError;
  }

  /// Handle Flutter framework errors
  void _handleFlutterError(FlutterErrorDetails details) {
    final exception = details.exception;

    // Log the error
    logger.error(
      'Flutter error: ${details.exceptionAsString()}',
      error: exception,
      stackTrace: details.stack,
    );

    // In debug mode, show the red error screen
    if (kDebugMode) {
      FlutterError.dumpErrorToConsole(details);
    }

    // Report to crash analytics
    _reportToCrashlytics(exception, details.stack);
  }

  /// Handle platform-level errors
  bool _handlePlatformError(Object error, StackTrace stackTrace) {
    logger.fatal(
      'Platform error: $error',
      error: error,
      stackTrace: stackTrace,
    );

    // Report to crash analytics
    _reportToCrashlytics(error, stackTrace);

    // Return true to prevent the error from propagating
    return true;
  }

  /// Handle errors from async operations in zones
  void handleZoneError(Object error, StackTrace stackTrace) {
    if (error is AppException) {
      logger.logException(error);
    } else {
      logger.error(
        'Uncaught async error: $error',
        error: error,
        stackTrace: stackTrace,
      );
    }

    // Report non-trivial errors
    if (error is! AppException ||
        error.severity == ExceptionSeverity.critical) {
      _reportToCrashlytics(error, stackTrace);
    }
  }

  /// Convert any error to an AppException
  AppException wrapError(Object error, [StackTrace? stackTrace]) {
    if (error is AppException) return error;

    return DataException(
      userMessage: 'Something went wrong. Please try again.',
      technicalMessage: 'Wrapped error: $error',
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  /// Report error to crash analytics service
  void _reportToCrashlytics(Object error, StackTrace? stackTrace) {
    // TODO: Integrate with crash reporting service
    // Options:
    // - Sentry: Sentry.captureException(error, stackTrace: stackTrace)
    // - Firebase Crashlytics: FirebaseCrashlytics.instance.recordError(error, stackTrace)
    //
    // For now, just log in release mode
    if (!kDebugMode) {
      debugPrint('CRASH REPORT: $error');
    }
  }
}

/// Global error handler instance
final errorHandler = ErrorHandler.instance;

/// Run the app with global error handling
Future<void> runWithGlobalErrorHandling(
    Future<void> Function() appRunner) async {
  // Initialize error handling first
  errorHandler.initialize();

  // Run the app in an error-handling zone
  await runZonedGuarded(
    appRunner,
    errorHandler.handleZoneError,
  );
}
