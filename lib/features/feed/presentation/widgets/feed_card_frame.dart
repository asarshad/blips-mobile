import 'package:flutter/material.dart';

/// Shared card frame used by article and video cards.
/// Provides consistent layout with media, metadata, and action buttons.
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
          borderRadius: BorderRadius.circular(12),
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
            Expanded(
              flex: 35,
              child: SizedBox.expand(child: media),
            ),
            // Content section (65%)
            Expanded(
              flex: 65,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(15, 10, 15, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(colorScheme),
                    const SizedBox(height: 10),
                    _buildTitle(textTheme, colorScheme),
                    const SizedBox(height: 8),
                    _buildSummary(textTheme, colorScheme),
                    Divider(
                      color: colorScheme.onSurface.withValues(alpha: 0.1),
                      height: 1,
                    ),
                    _buildFooter(colorScheme),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Row(
      children: [
        _CategoryBadge(category: category, colorScheme: colorScheme),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            source,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (showActions) ...[
          _ActionIcon(
            icon: Icons.open_in_new,
            onTap: onOpenLink,
            color: colorScheme.onSurfaceVariant,
          ),
          _ActionIcon(
            icon: Icons.share_outlined,
            onTap: onShare,
            color: colorScheme.onSurfaceVariant,
          ),
        ],
      ],
    );
  }

  Widget _buildTitle(TextTheme textTheme, ColorScheme colorScheme) {
    return Text(
      title,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: textTheme.headlineSmall?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.bold,
        height: 1.4,
        fontSize: 16,
      ),
    );
  }

  Widget _buildSummary(TextTheme textTheme, ColorScheme colorScheme) {
    return Expanded(
      child: Text(
        summary,
        style: textTheme.bodyLarge?.copyWith(
          color: colorScheme.onSurfaceVariant,
          height: 1.4,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildFooter(ColorScheme colorScheme) {
    return Row(
      children: [
        Icon(
          Icons.calendar_today_outlined,
          size: 14,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Text(
          date,
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 16),
        Icon(
          Icons.access_time,
          size: 14,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Text(
          readTime,
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
        const Spacer(),
        if (showActions)
          InkWell(
            onTap: onChat,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.bolt, color: colorScheme.onPrimary),
              ),
            ),
          ),
      ],
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({
    required this.category,
    required this.colorScheme,
  });

  final String category;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final displayCategory =
        category == 'Artificial Intelligence' ? 'AI' : category;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        displayCategory.toUpperCase(),
        style: TextStyle(
          color: colorScheme.primary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}
