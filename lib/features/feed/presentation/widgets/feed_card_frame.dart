import 'package:blips_mobile/core/theme/theme.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/presentation/widgets/freshness_label.dart';
import 'package:blips_mobile/features/feed/presentation/widgets/press_feedback_tap.dart';
import 'package:flutter/material.dart';

/// Information about content freshness for display.
class FreshnessInfo {
  const FreshnessInfo({
    required this.publishedAt,
    this.addedAt,
    this.tier = FreshnessTier.fresh,
    this.isNewSinceLastSeen = false,
  });

  final DateTime publishedAt;
  final DateTime? addedAt;
  final FreshnessTier tier;
  final bool isNewSinceLastSeen;
}

/// Shared card frame used by article and video cards.
///
/// Layout Strategy:
/// - If [mediaAspectRatio] is provided, media height = cardWidth / aspectRatio
///   (pixel-perfect fit, eliminates letterboxing — required for 16:9 video).
/// - If null, media section uses flex 39% of card height
///   (correct for article images with BoxFit.cover).
/// - Content section fills remaining height via Expanded.
/// - Text scaling is clamped to 1.2x max to prevent layout overflow.
class FeedCardFrame extends StatelessWidget {
  const FeedCardFrame({
    super.key,
    required this.media,
    required this.category,
    required this.title,
    this.titleMaxLines,
    required this.summary,
    required this.source,
    this.date,
    this.freshnessInfo,
    required this.readTime,
    this.onMediaTap,
    this.onContentTap,
    this.onLongPress,
    this.onShare,
    this.onChat,
    this.onSaveToggle,
    this.isSaved = false,
    this.showActions = true,
    this.mediaAspectRatio,
  });

  final Widget media;

  /// When set, the media section height = cardWidth / mediaAspectRatio.
  /// Pass [16 / 9] for YouTube videos to eliminate letterboxing.
  /// Leave null for articles — BoxFit.cover adapts to any flex height.
  final double? mediaAspectRatio;
  final String category;
  final String title;
  final int? titleMaxLines;
  final String summary;
  final String source;

  /// Legacy date field for backward compatibility.
  final String? date;

  /// New freshness info with tier and timestamps.
  final FreshnessInfo? freshnessInfo;
  final String readTime;
  final VoidCallback? onMediaTap;
  final VoidCallback? onContentTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onShare;
  final VoidCallback? onChat;
  final VoidCallback? onSaveToggle;
  final bool isSaved;
  final bool showActions;

  /// Max text scale factor for card content.
  /// Allows some accessibility scaling while preventing overflow.
  static const double _maxTextScaleFactor = 1.2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: AppRadius.borderLg,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        width: double.infinity,
        height: double.infinity,
        clipBehavior: Clip.antiAlias,
        child: mediaAspectRatio != null
            ? _AspectRatioLayout(
                media: media,
                aspectRatio: mediaAspectRatio!,
                onMediaTap: onMediaTap,
                onContentTap: onContentTap,
                contentSection: _buildContent(colorScheme, textTheme),
              )
            : _FlexLayout(
                media: media,
                onMediaTap: onMediaTap,
                onContentTap: onContentTap,
                contentSection: _buildContent(colorScheme, textTheme),
              ),
      ),
    );
  }

  Widget _buildContent(ColorScheme colorScheme, TextTheme textTheme) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: _maxTextScaleFactor,
      child: _ContentSection(
        category: category,
        title: title,
        titleMaxLines: titleMaxLines,
        summary: summary,
        source: source,
        date: date,
        freshnessInfo: freshnessInfo,
        readTime: readTime,
        showActions: showActions,
        onShare: onShare,
        onChat: onChat,
        onSaveToggle: onSaveToggle,
        isSaved: isSaved,
        colorScheme: colorScheme,
        textTheme: textTheme,
      ),
    );
  }
}

/// Layout for aspect-ratio-driven media (e.g. 16:9 YouTube video).
/// Media height = cardWidth / aspectRatio — zero letterboxing guaranteed.
class _AspectRatioLayout extends StatelessWidget {
  const _AspectRatioLayout({
    required this.media,
    required this.aspectRatio,
    this.onMediaTap,
    this.onContentTap,
    required this.contentSection,
  });

  final Widget media;
  final double aspectRatio;
  final VoidCallback? onMediaTap;
  final VoidCallback? onContentTap;
  final Widget contentSection;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaHeight = constraints.maxWidth / aspectRatio;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              height: mediaHeight,
              child: _TapSection(
                onTap: onMediaTap,
                child: media,
              ),
            ),
            Expanded(
              child: _TapSection(
                onTap: onContentTap,
                child: contentSection,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Layout for flex-based media (e.g. article images with BoxFit.cover).
/// Media = 39% of card height; content = 61%.
class _FlexLayout extends StatelessWidget {
  const _FlexLayout({
    required this.media,
    this.onMediaTap,
    this.onContentTap,
    required this.contentSection,
  });

  final Widget media;
  final VoidCallback? onMediaTap;
  final VoidCallback? onContentTap;
  final Widget contentSection;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 39,
          child: SizedBox.expand(
            child: _TapSection(
              onTap: onMediaTap,
              child: media,
            ),
          ),
        ),
        Expanded(
          flex: 61,
          child: _TapSection(
            onTap: onContentTap,
            child: contentSection,
          ),
        ),
      ],
    );
  }
}

class _TapSection extends StatelessWidget {
  const _TapSection({
    required this.child,
    this.onTap,
  });

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) {
      return child;
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.deferToChild,
      child: child,
    );
  }
}

class _ContentSection extends StatelessWidget {
  const _ContentSection({
    required this.category,
    required this.title,
    this.titleMaxLines,
    required this.summary,
    required this.source,
    this.date,
    this.freshnessInfo,
    required this.readTime,
    required this.showActions,
    required this.colorScheme,
    required this.textTheme,
    this.onShare,
    this.onChat,
    this.onSaveToggle,
    required this.isSaved,
  });

  final String category;
  final String title;
  final int? titleMaxLines;
  final String summary;
  final String source;
  final String? date;
  final FreshnessInfo? freshnessInfo;
  final String readTime;
  final bool showActions;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback? onShare;
  final VoidCallback? onChat;
  final VoidCallback? onSaveToggle;
  final bool isSaved;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0, // _ChatButton's own AppSpacing.allSm provides 8px below — no double-padding
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            category: category,
            showActions: showActions,
            onShare: onShare,
            onSaveToggle: onSaveToggle,
            isSaved: isSaved,
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
          const SizedBox(height: AppSpacing.sm),
          _Title(
            title: title,
            titleMaxLines: titleMaxLines,
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
          const SizedBox(height: AppSpacing.xs),
          Expanded(
            child: _Summary(
              summary: summary,
              source: source,
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
          ),
          Divider(
            color: colorScheme.onSurface.withValues(alpha: 0.1),
            height: AppSizes.dividerHeight,
          ),
          _Footer(
            date: date,
            freshnessInfo: freshnessInfo,
            readTime: readTime,
            showActions: showActions,
            onChat: onChat,
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.category,
    required this.showActions,
    required this.colorScheme,
    required this.textTheme,
    this.onShare,
    this.onSaveToggle,
    required this.isSaved,
  });

  final String category;
  final bool showActions;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback? onShare;
  final VoidCallback? onSaveToggle;
  final bool isSaved;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CategoryBadge(category: category, colorScheme: colorScheme),
        const Spacer(),
        if (showActions) ...[
          const SizedBox(width: AppSpacing.sm),
          _HeaderActions(
            colorScheme: colorScheme,
            onShare: onShare,
            onSaveToggle: onSaveToggle,
            isSaved: isSaved,
          ),
        ],
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({
    required this.title,
    this.titleMaxLines,
    required this.colorScheme,
    required this.textTheme,
  });

  final String title;
  final int? titleMaxLines;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      maxLines: titleMaxLines,
      overflow: titleMaxLines == null ? null : TextOverflow.ellipsis,
      style: textTheme.titleLarge?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.bold,
        height: AppTypography.lineHeightNormal,
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.summary,
    required this.source,
    required this.colorScheme,
    required this.textTheme,
  });

  final String summary;
  final String source;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  static const Key _summaryKey = Key('feed-card-summary-text');
  static const Key _sourceKey = Key('feed-card-source-label');

  @override
  Widget build(BuildContext context) {
    final summaryText = summary.trim();
    final sourceText = source.trim();
    final summaryStyle = textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
      height: AppTypography.lineHeightNormal,
    );
    final sourceStyle = textTheme.labelSmall?.copyWith(
      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.38),
      fontWeight: FontWeight.w400,
      height: AppTypography.lineHeightNormal,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (summaryText.isNotEmpty)
            Text(
              summaryText,
              key: _summaryKey,
              style: summaryStyle,
            ),
          if (summaryText.isNotEmpty && sourceText.isNotEmpty)
            const SizedBox(height: AppSpacing.xs),
          if (sourceText.isNotEmpty)
            Text(
              sourceText,
              key: _sourceKey,
              style: sourceStyle,
            ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    this.date,
    this.freshnessInfo,
    required this.readTime,
    required this.showActions,
    required this.colorScheme,
    required this.textTheme,
    this.onChat,
  });

  final String? date;
  final FreshnessInfo? freshnessInfo;
  final String readTime;
  final bool showActions;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback? onChat;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Metadata section takes all available space
        Expanded(
          child: Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: AppSizes.iconXs,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
              if (freshnessInfo != null)
                Flexible(
                  child: FreshnessLabel(
                    publishedAt: freshnessInfo!.publishedAt,
                    addedAt: freshnessInfo!.addedAt,
                    freshnessTier: freshnessInfo!.tier,
                    isNewSinceLastSeen: freshnessInfo!.isNewSinceLastSeen,
                  ),
                )
              else if (date != null)
                Flexible(
                  child: Text(
                    date!,
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              const SizedBox(width: AppSpacing.md),
              Icon(
                Icons.access_time,
                size: AppSizes.iconXs,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                readTime,
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (showActions) _ChatButton(onChat: onChat, colorScheme: colorScheme),
      ],
    );
  }
}

class _ChatButton extends StatelessWidget {
  const _ChatButton({required this.onChat, required this.colorScheme});

  final VoidCallback? onChat;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return PressFeedbackTap(
      onTap: onChat,
      builder: (context, pressState) => AnimatedScale(
        scale: pressState.scale,
        duration: pressState.duration,
        curve: pressState.curve,
        child: InkWell(
          onTap: pressState.onTap,
          onHighlightChanged: pressState.onHighlightChanged,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: AppSpacing.allSm,
            child: Container(
              width: AppSizes.avatarSm,
              height: AppSizes.avatarSm,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: colorScheme.onPrimary,
                size: AppSizes.iconSm,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category, required this.colorScheme});

  final String category;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final display = category == 'Artificial Intelligence' ? 'AI' : category;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: AppRadius.borderSm,
      ),
      child: Text(
        display.toUpperCase(),
        style: textTheme.labelSmall?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _HeaderActions extends StatelessWidget {
  const _HeaderActions({
    required this.colorScheme,
    this.onShare,
    this.onSaveToggle,
    required this.isSaved,
  });

  final ColorScheme colorScheme;
  final VoidCallback? onShare;
  final VoidCallback? onSaveToggle;
  final bool isSaved;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxs),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionIcon(Icons.share_outlined, onShare, colorScheme),
          const SizedBox(width: AppSpacing.xs),
          _ActionIcon(
            isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            onSaveToggle,
            colorScheme,
            isActive: isSaved,
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon(
    this.icon,
    this.onTap,
    this.colorScheme, {
    this.isActive = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final ColorScheme colorScheme;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return PressFeedbackTap(
      onTap: onTap,
      builder: (context, pressState) => AnimatedScale(
        scale: pressState.scale,
        duration: pressState.duration,
        curve: pressState.curve,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: pressState.onTap,
            onHighlightChanged: pressState.onHighlightChanged,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isActive
                    ? colorScheme.primary.withValues(alpha: 0.14)
                    : colorScheme.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: isActive
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                size: AppSizes.iconSm,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
