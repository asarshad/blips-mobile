import 'package:flutter/material.dart';

// Neon IDE theme colors (Dracula-inspired)
const _neonCyan = Color(0xFF80FFEA);
const _neonPink = Color(0xFFFF79C6);
const _neonGreen = Color(0xFF50FA7B);
const _neonPurple = Color(0xFFBD93F9);
const _neonOrange = Color(0xFFFFB86C);
const _neonYellow = Color(0xFFF1FA8C);
const _neonTextPrimary = Color(0xFFF8F8F2);
const _neonTextMuted = Color(0xFF6272A4);

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
    // Check if we're using neon theme
    final isNeon = colorScheme.primary == _neonPink;
    
    return Text(
      title,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: textTheme.headlineSmall?.copyWith(
        color: isNeon ? _neonCyan : colorScheme.onSurface,
        fontWeight: FontWeight.bold,
        height: 1.4,
        fontSize: 16,
        fontFamily: isNeon ? 'JetBrains Mono' : null, // Monospace for code feel
        letterSpacing: isNeon ? 0.3 : 0,
      ),
    );
  }

  Widget _buildSummary(TextTheme textTheme, ColorScheme colorScheme) {
    // Check if we're using neon theme
    final isNeon = colorScheme.primary == _neonPink;
    
    return Expanded(
      child: isNeon 
          ? _NeonSummaryText(summary: summary) 
          : Text(
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

/// Neon-themed summary text with code-like syntax highlighting.
/// 
/// Highlights:
/// - Tech terms and keywords in cyan
/// - Quoted text in green (strings)
/// - Numbers in orange
/// - Company names in purple
class _NeonSummaryText extends StatelessWidget {
  const _NeonSummaryText({required this.summary});
  
  final String summary;

  @override
  Widget build(BuildContext context) {
    return RichText(
      overflow: TextOverflow.fade,
      text: TextSpan(
        style: const TextStyle(
          color: _neonTextPrimary,
          fontSize: 13,
          height: 1.5,
          fontFamily: 'JetBrains Mono',
          letterSpacing: 0.2,
        ),
        children: _buildHighlightedSpans(summary),
      ),
    );
  }
  
  List<TextSpan> _buildHighlightedSpans(String text) {
    final spans = <TextSpan>[];
    
    // Keywords to highlight (tech terms)
    final techKeywords = RegExp(
      r'\b(AI|API|GPT|ML|LLM|GPU|CPU|iOS|Android|Flutter|React|Python|JavaScript|'
      r'TypeScript|Rust|Go|Swift|Kotlin|Java|C\+\+|AWS|Azure|Google|Apple|Microsoft|'
      r'Meta|OpenAI|Anthropic|Tesla|NVIDIA|AMD|Intel|Samsung|blockchain|crypto|'
      r'neural|machine learning|deep learning|cloud|server|database|algorithm|'
      r'quantum|robotics|autonomous|startup|tech)\b',
      caseSensitive: false,
    );
    
    // Numbers pattern
    final numbersPattern = RegExp(r'\b\d+(?:\.\d+)?%?|\$\d+(?:\.\d+)?[BMK]?\b');
    
    // Quoted strings pattern
    final quotedPattern = RegExp(r'"[^"]*"|"[^"]*"');
    
    int lastEnd = 0;
    final allMatches = <_HighlightMatch>[];
    
    // Collect all matches
    for (final match in techKeywords.allMatches(text)) {
      allMatches.add(_HighlightMatch(match.start, match.end, _neonCyan, text.substring(match.start, match.end)));
    }
    for (final match in numbersPattern.allMatches(text)) {
      allMatches.add(_HighlightMatch(match.start, match.end, _neonOrange, text.substring(match.start, match.end)));
    }
    for (final match in quotedPattern.allMatches(text)) {
      allMatches.add(_HighlightMatch(match.start, match.end, _neonGreen, text.substring(match.start, match.end)));
    }
    
    // Sort by position
    allMatches.sort((a, b) => a.start.compareTo(b.start));
    
    // Remove overlapping matches (keep first)
    final filteredMatches = <_HighlightMatch>[];
    for (final match in allMatches) {
      if (filteredMatches.isEmpty || match.start >= filteredMatches.last.end) {
        filteredMatches.add(match);
      }
    }
    
    // Build spans
    for (final match in filteredMatches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      spans.add(TextSpan(
        text: match.text,
        style: TextStyle(color: match.color, fontWeight: FontWeight.w500),
      ));
      lastEnd = match.end;
    }
    
    // Add remaining text
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }
    
    return spans.isEmpty ? [TextSpan(text: text)] : spans;
  }
}

class _HighlightMatch {
  _HighlightMatch(this.start, this.end, this.color, this.text);
  final int start;
  final int end;
  final Color color;
  final String text;
}
