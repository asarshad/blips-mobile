import 'package:flutter/material.dart';

enum FeedActionPillPlacement { top, bottom }

/// Compact tappable pill shown on feed surfaces for freshness actions, such as
/// loading newly available items.
class FeedActionPill extends StatelessWidget {
  const FeedActionPill({
    super.key,
    required this.label,
    required this.onTap,
    this.dark = false,
    this.placement = FeedActionPillPlacement.top,
  });

  final String label;
  final VoidCallback onTap;
  final bool dark;
  final FeedActionPillPlacement placement;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = dark
        ? Colors.black.withValues(alpha: 0.82)
        : colorScheme.surface.withValues(alpha: 0.96);
    final foreground = dark ? Colors.white : colorScheme.onSurface;

    final verticalPadding = switch (placement) {
      FeedActionPillPlacement.top => const EdgeInsets.only(top: 12),
      FeedActionPillPlacement.bottom => const EdgeInsets.only(bottom: 72),
    };

    return SafeArea(
      top: placement == FeedActionPillPlacement.top,
      bottom: placement == FeedActionPillPlacement.bottom,
      child: Center(
        child: Padding(
          padding: verticalPadding,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: foreground.withValues(alpha: 0.14),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: dark ? 0.3 : 0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
