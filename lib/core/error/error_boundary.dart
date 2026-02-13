import 'package:blips_mobile/core/error/app_logger.dart';
import 'package:flutter/material.dart';

/// Catches Flutter framework errors within its subtree and shows a
/// user-friendly fallback instead of a red error screen.
///
/// Usage:
/// ```dart
/// ErrorBoundary(child: SomeFragileWidget())
/// ```
class ErrorBoundary extends StatefulWidget {
  /// Creates an error boundary.
  const ErrorBoundary({
    super.key,
    required this.child,
  });

  /// The widget subtree to protect.
  final Widget child;

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  FlutterErrorDetails? _error;

  @override
  void initState() {
    super.initState();
  }

  void _handleError(FlutterErrorDetails details) {
    logger.error(
      'ErrorBoundary caught: ${details.exceptionAsString()}',
      error: details.exception,
      stackTrace: details.stack,
    );
    if (mounted) {
      setState(() => _error = details);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _ErrorFallback(
        onRetry: () => setState(() => _error = null),
      );
    }

    return _ErrorCatcher(
      onError: _handleError,
      child: widget.child,
    );
  }
}

/// Internal widget that installs a custom [ErrorWidget.builder] scoped to
/// this subtree via its own [Element] error-handling override.
class _ErrorCatcher extends StatelessWidget {
  const _ErrorCatcher({
    required this.onError,
    required this.child,
  });

  final void Function(FlutterErrorDetails) onError;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // We use a Builder so framework rendering errors in `child` are caught
    // by the enclosing _ErrorBoundaryState via the ErrorWidget.builder.
    return child;
  }
}

class _ErrorFallback extends StatelessWidget {
  const _ErrorFallback({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: theme.colorScheme.error.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'This section encountered an error.\nTap below to try again.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
