import 'package:flutter/material.dart';

/// Compact banner used for feed terminal states like "caught up".
class FeedStateBanner extends StatelessWidget {
  const FeedStateBanner({
    super.key,
    required this.message,
    this.dark = false,
  });

  final String message;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = dark
        ? Colors.black.withValues(alpha: 0.78)
        : colorScheme.surface.withValues(alpha: 0.94);
    final foreground = dark ? Colors.white : colorScheme.onSurface;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: foreground.withValues(alpha: 0.16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.28 : 0.12),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}
