import 'package:flutter/material.dart';

/// Temporary release-visible feed diagnostics overlay.
///
/// Keep this small and transparent so it does not obstruct content while still
/// surfacing the current position and a small amount of feed state.
class FeedStatusOverlay extends StatelessWidget {
  /// Creates the compact feed diagnostics overlay.
  const FeedStatusOverlay({
    required this.title,
    this.subtitle,
    this.dark = false,
    this.topInset = 0,
    super.key,
  });

  /// Set to `true` from integration/screenshot tests to hide the overlay.
  static bool suppress = false;

  /// Primary overlay text, usually the current position summary.
  final String title;

  /// Secondary overlay text, such as freshness or state details.
  final String? subtitle;

  /// Whether the overlay should use a dark-on-dark presentation.
  final bool dark;

  /// Extra top spacing when another top bar is already occupying the safe area.
  final double topInset;

  @override
  Widget build(BuildContext context) {
    if (suppress) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final background = dark
        ? Colors.black.withValues(alpha: 0.56)
        : colorScheme.surface.withValues(alpha: 0.76);
    final foreground = dark ? Colors.white : colorScheme.onSurface;

    return IgnorePointer(
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: EdgeInsets.only(
              top: 10 + topInset,
              right: 12,
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 168),
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: foreground.withValues(alpha: 0.14),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: dark ? 0.22 : 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: DefaultTextStyle(
                style: Theme.of(context).textTheme.labelSmall!.copyWith(
                      color: foreground,
                      height: 1.15,
                    ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: foreground.withValues(alpha: 0.88),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
