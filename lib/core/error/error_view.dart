import 'package:blips_mobile/core/error/app_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A user-friendly error view that extracts messages from [AppException].
///
/// Shows:
/// - An appropriate icon based on error type
/// - User-friendly error message
/// - Retry button for retryable errors
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.error,
    this.onRetry,
    this.compact = false,
  });

  /// The error to display. Can be [AppException] or any other type.
  final Object error;

  /// Called when the user taps the retry button.
  final VoidCallback? onRetry;

  /// Whether to show a compact version (for inline usage).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (icon, message, canRetry) = _extractErrorInfo(error);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (compact) {
      return _buildCompact(context, icon, message, canRetry, colorScheme);
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 56,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (canRetry && onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Try Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompact(
    BuildContext context,
    IconData icon,
    String message,
    bool canRetry,
    ColorScheme colorScheme,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: colorScheme.error),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            message,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ),
        if (canRetry && onRetry != null) ...[
          const SizedBox(width: 8),
          IconButton(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 20),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ],
    );
  }

  (IconData, String, bool) _extractErrorInfo(Object error) {
    if (error is NetworkException) {
      final icon = switch (error.statusCode) {
        null => Icons.wifi_off_rounded,
        404 => Icons.search_off_rounded,
        >= 500 => Icons.cloud_off_rounded,
        _ => Icons.error_outline_rounded,
      };
      return (icon, error.userMessage, error.isRetryable);
    }

    if (error is DataException) {
      return (
        Icons.broken_image_rounded,
        error.userMessage,
        true,
      );
    }

    if (error is AppException) {
      return (Icons.error_outline_rounded, error.userMessage, true);
    }

    // Fallback for non-AppException errors
    return (
      Icons.error_outline_rounded,
      'Something went wrong. Please try again.',
      true,
    );
  }
}

/// Extension to build an error view from any AsyncValue
extension AsyncValueErrorExt<T> on AsyncValue<T> {
  /// Builds an error view when this AsyncValue is in error state.
  Widget buildErrorView({
    VoidCallback? onRetry,
    bool compact = false,
  }) {
    return maybeWhen(
      error: (error, _) => ErrorView(
        error: error,
        onRetry: onRetry,
        compact: compact,
      ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}
