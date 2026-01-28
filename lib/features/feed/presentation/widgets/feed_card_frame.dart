import 'package:blips_mobile/core/theme/theme.dart';
import 'package:flutter/material.dart';

/// Shared card frame used by article and video cards.
///
/// Layout Strategy:
/// - Media section: 35% of card height (fixed ratio)
/// - Content section: 65% of card height (flexible text)
/// - Text scaling is clamped to 1.15x max to prevent layout overflow
/// - Summary uses gradient fade for graceful truncation
class FeedCardFrame extends StatelessWidget {
  const FeedCardFrame({
    super.key,
    required this.media,
    required this.category,
    required this.title,
    required this.summary,
    required this.source,
    required this.date,
    required this.readTime,
    this.onTap,
    this.onShare,
    this.onChat,
    this.onOpenLink,
    this.showActions = true,
  });

  final Widget media;
  final String category;
  final String title;
  final String summary;
  final String source;
  final String date;
  final String readTime;
  final VoidCallback? onTap;
  final VoidCallback? onShare;
  final VoidCallback? onChat;
  final VoidCallback? onOpenLink;
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
      onTap: onTap,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Media section (35%)
            Expanded(flex: 35, child: SizedBox.expand(child: media)),
            // Content section (65%) - clamp text scaling
            Expanded(
              flex: 65,
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: _maxTextScaleFactor,
                child: _ContentSection(
                  category: category,
                  title: title,
                  summary: summary,
                  source: source,
                  date: date,
                  readTime: readTime,
                  showActions: showActions,
                  onShare: onShare,
                  onChat: onChat,
                  onOpenLink: onOpenLink,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContentSection extends StatelessWidget {
  const _ContentSection({
    required this.category,
    required this.title,
    required this.summary,
    required this.source,
    required this.date,
    required this.readTime,
    required this.showActions,
    required this.colorScheme,
    required this.textTheme,
    this.onShare,
    this.onChat,
    this.onOpenLink,
  });

  final String category;
  final String title;
  final String summary;
  final String source;
  final String date;
  final String readTime;
  final bool showActions;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback? onShare;
  final VoidCallback? onChat;
  final VoidCallback? onOpenLink;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            category: category,
            source: source,
            showActions: showActions,
            onShare: onShare,
            onOpenLink: onOpenLink,
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
          const SizedBox(height: AppSpacing.sm),
          _Title(title: title, colorScheme: colorScheme, textTheme: textTheme),
          const SizedBox(height: AppSpacing.xs),
          Expanded(
            child: _Summary(
              summary: summary,
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
    required this.source,
    required this.showActions,
    required this.colorScheme,
    required this.textTheme,
    this.onShare,
    this.onOpenLink,
  });

  final String category;
  final String source;
  final bool showActions;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback? onShare;
  final VoidCallback? onOpenLink;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CategoryBadge(category: category, colorScheme: colorScheme),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            source,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        if (showActions) ...[
          _ActionIcon(Icons.open_in_new, onOpenLink, colorScheme),
          _ActionIcon(Icons.share_outlined, onShare, colorScheme),
        ],
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({
    required this.title,
    required this.colorScheme,
    required this.textTheme,
  });

  final String title;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      maxLines: 2, // Reduced from 3 to give summary more room
      overflow: TextOverflow.ellipsis,
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
    required this.colorScheme,
    required this.textTheme,
  });

  final String summary;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    // Use ShaderMask for smooth gradient fade at bottom
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white,
          Colors.white,
          Colors.white.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.8, 1.0],
      ).createShader(bounds),
      blendMode: BlendMode.dstIn,
      child: Text(
        summary,
        style: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          height: AppTypography.lineHeightNormal,
        ),
        // No maxLines - flows naturally, fades at bottom
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.date,
    required this.readTime,
    required this.showActions,
    required this.colorScheme,
    required this.textTheme,
    this.onChat,
  });

  final String date;
  final String readTime;
  final bool showActions;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback? onChat;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.calendar_today_outlined,
            size: AppSizes.iconXs, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            date,
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Icon(Icons.access_time,
            size: AppSizes.iconXs, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.xs),
        Text(
          readTime,
          style: textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
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
    return InkWell(
      onTap: onChat,
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
            Icons.bolt,
            color: colorScheme.onPrimary,
            size: AppSizes.iconSm,
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

class _ActionIcon extends StatelessWidget {
  const _ActionIcon(this.icon, this.onTap, this.colorScheme);

  final IconData icon;
  final VoidCallback? onTap;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: AppSpacing.allXs,
        child: Icon(icon,
            color: colorScheme.onSurfaceVariant, size: AppSizes.iconSm),
      ),
    );
  }
}
