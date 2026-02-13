/// Error handling infrastructure for the app.
///
/// Provides:
/// - [AppException] - Structured exception types
/// - [AppLogger] - Categorized logging
/// - [ErrorHandler] - Global error capture
/// - [ErrorBoundary] - Catches framework errors per-section
/// - [ErrorView] - User-friendly error widgets
library;

export 'app_exception.dart';
export 'app_logger.dart';
export 'error_boundary.dart';
export 'error_handler.dart';
export 'error_view.dart';
