import 'package:blips_mobile/core/theme/theme.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:flutter/material.dart';

/// Displays truthful freshness information for feed items.
///
/// Shows "Published X ago" for fresh content and "Added Y ago" for recently added
/// or evergreen content. Optionally shows a tier indicator like "New to you" or
/// "Highlights" for non-fresh tiers.
class FreshnessLabel extends StatelessWidget {
  const FreshnessLabel({
    super.key,
    required this.publishedAt,
    this.addedAt,
    this.freshnessTier = FreshnessTier.fresh,
    this.isNewSinceLastSeen = false,
    this.showTierIndicator = true,
    this.now,
  });

  /// When the content was originally published.
  final DateTime publishedAt;

  /// When the content was added to our system (optional).
  final DateTime? addedAt;

  /// The freshness tier for this content.
  final FreshnessTier freshnessTier;

  /// Whether the entry was added after the user's last seen timestamp.
  final bool isNewSinceLastSeen;

  /// Whether to show tier indicator badge for non-fresh content.
  final bool showTierIndicator;

  /// Override clock for deterministic tests.
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final reference = (now ?? DateTime.now)();
    final publishedAge = _formatAge(publishedAt, reference);
    final addedAge = addedAt != null ? _formatAge(addedAt!, reference) : null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isNewSinceLastSeen) ...[
          _NewBadge(colorScheme: colorScheme),
          const SizedBox(width: AppSpacing.sm),
        ],
        // Tier indicator badge (only for non-fresh content)
        if (showTierIndicator && freshnessTier != FreshnessTier.fresh) ...[
          _TierBadge(tier: freshnessTier, colorScheme: colorScheme),
          const SizedBox(width: AppSpacing.sm),
        ],
        // Freshness text
        Flexible(
          child: Text(
            _buildFreshnessText(publishedAge, addedAge),
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _buildFreshnessText(String publishedAge, String? addedAge) {
    switch (freshnessTier) {
      case FreshnessTier.fresh:
        // Just show "Published X ago"
        return 'Published $publishedAge';
      case FreshnessTier.recentlyAdded:
        // Emphasize when it was added
        if (addedAge != null) {
          return 'Added $addedAge · Published $publishedAge';
        }
        return 'Published $publishedAge';
      case FreshnessTier.evergreen:
        // Just show published, tier badge explains why it's here
        return 'Published $publishedAge';
    }
  }

  /// Formats a duration into a human-readable age string.
  String _formatAge(DateTime timestamp, DateTime reference) {
    final localTimestamp = timestamp.toLocal();
    final localReference = reference.toLocal();
    final days = DateUtils.dateOnly(localReference)
        .difference(DateUtils.dateOnly(localTimestamp))
        .inDays;

    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (days < 7) return '${days}d ago';

    if (days < 30) {
      final weeks = days ~/ 7;
      return '${weeks}w ago';
    }

    final months = days ~/ 30;
    return '${months}mo ago';
  }
}

class _NewBadge extends StatelessWidget {
  const _NewBadge({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        'New',
        style: textTheme.labelSmall?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }
}

/// Badge showing tier indicator for non-fresh content.
class _TierBadge extends StatelessWidget {
  const _TierBadge({required this.tier, required this.colorScheme});

  final FreshnessTier tier;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final (label, color) = _tierInfo;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }

  (String, Color) get _tierInfo {
    switch (tier) {
      case FreshnessTier.fresh:
        return ('', colorScheme.primary);
      case FreshnessTier.recentlyAdded:
        return ('New to you', colorScheme.tertiary);
      case FreshnessTier.evergreen:
        return ('Highlight', colorScheme.secondary);
    }
  }
}
