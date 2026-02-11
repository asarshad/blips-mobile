import 'package:blips_mobile/core/theme/theme.dart';
import 'package:blips_mobile/features/chat/presentation/chat_detail_page.dart';
import 'package:blips_mobile/features/feed/data/starters_repository.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/providers/starters_providers.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Floating chat bubble suggestions that appear when tapping the chat button.
/// Fetches AI-generated questions from the backend API.
///
/// Layout Strategy:
/// - Right-aligned to connect visually with the chat button in the footer
/// - Max width of 85% screen width to prevent overflow on small screens
/// - Bottom-right corner has small radius to point toward the button
/// - Shows loading shimmer while fetching from API
class FloatingChatBubbles extends ConsumerWidget {
  const FloatingChatBubbles({
    super.key,
    required this.entry,
    required this.onClose,
  });

  final FeedEntry entry;
  final VoidCallback onClose;

  /// Maximum width as fraction of available width
  static const double _maxWidthFraction = 0.85;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentId = _getContentId(entry);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxBubbleWidth = constraints.maxWidth * _maxWidthFraction;

        // Use inline starters from the feed response if available,
        // otherwise fall back to the separate API call.
        if (entry.conversationStarters.isNotEmpty) {
          return _buildBubbles(
            entry.conversationStarters,
            maxBubbleWidth,
          );
        }

        final startersAsync = ref.watch(startersProvider(contentId));

        return startersAsync.when(
          loading: () => _buildLoadingState(maxBubbleWidth),
          error: (_, __) => _buildBubbles(
            defaultFallbackStarters.starters,
            maxBubbleWidth,
          ),
          data: (starters) => _buildBubbles(
            starters.starters.isNotEmpty
                ? starters.starters
                : defaultFallbackStarters.starters,
            maxBubbleWidth,
          ),
        );
      },
    );
  }

  /// Get the content ID for the API call.
  /// Articles use positive IDs, videos use their actual ID (backend handles both).
  int _getContentId(FeedEntry entry) {
    if (entry is ArticleFeedEntry) {
      return entry.id;
    } else if (entry is VideoFeedEntry) {
      return entry.id;
    }
    return 0;
  }

  Widget _buildLoadingState(double maxBubbleWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (index) => _LoadingBubble(maxWidth: maxBubbleWidth),
      ),
    );
  }

  Widget _buildBubbles(List<String> questions, double maxBubbleWidth) {
    // Filter out any empty/blank strings to prevent blank bubbles
    final validQuestions = questions
        .where((q) => q.trim().isNotEmpty)
        .take(3)
        .toList();

    // Fall back to defaults if all starters were empty
    final displayQuestions = validQuestions.isNotEmpty
        ? validQuestions
        : defaultFallbackStarters.starters.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...displayQuestions
            .map((q) => _ChatBubble(
                  question: q,
                  entry: entry,
                  onClose: onClose,
                  maxWidth: maxBubbleWidth,
                )),
        _AskCustomBubble(
          entry: entry,
          onClose: onClose,
          maxWidth: maxBubbleWidth,
        ),
      ],
    );
  }
}

/// Loading placeholder bubble with shimmer effect.
class _LoadingBubble extends StatelessWidget {
  const _LoadingBubble({required this.maxWidth});

  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth * 0.7),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF1D4ED8).withValues(alpha: 0.5),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(AppRadius.xl + 4),
              topRight: Radius.circular(AppRadius.xl + 4),
              bottomLeft: Radius.circular(AppRadius.xl + 4),
              bottomRight: Radius.circular(AppRadius.sm),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Thinking...',
                style: textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.question,
    required this.entry,
    required this.onClose,
    required this.maxWidth,
  });

  final String question;
  final FeedEntry entry;
  final VoidCallback onClose;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: InkWell(
          onTap: () => _navigateToChat(context),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(AppRadius.xl + 4),
            topRight: Radius.circular(AppRadius.xl + 4),
            bottomLeft: Radius.circular(AppRadius.xl + 4),
            bottomRight: Radius.circular(AppRadius.sm),
          ),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF1D4ED8).withValues(alpha: 0.95),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppRadius.xl + 4),
                topRight: Radius.circular(AppRadius.xl + 4),
                bottomLeft: Radius.circular(AppRadius.xl + 4),
                bottomRight: Radius.circular(AppRadius.sm),
              ),
              border: Border.all(
                color: const Color(0xFF1D4ED8).withValues(alpha: 0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              question,
              style: textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToChat(BuildContext context) {
    onClose();

    final articleEntry = _convertToArticleEntry(entry);

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ChatDetailPage(
          article: articleEntry,
          initialPrompt: question,
        ),
      ),
    );
  }

  /// Converts any FeedEntry to ArticleFeedEntry for the chat page.
  /// Videos use negative IDs to distinguish from articles.
  ArticleFeedEntry _convertToArticleEntry(FeedEntry entry) {
    if (entry is ArticleFeedEntry) {
      return entry;
    }

    final video = entry as VideoFeedEntry;
    return ArticleFeedEntry(
      id: -video.id, // Negative ID indicates video
      title: video.title,
      summary: video.summary,
      source: video.source,
      publishedAt: video.publishedAt,
      url: video.link,
      imageUrl: video.thumbnailUrl ?? '',
      category: video.category,
      readTime: video.readTime,
    );
  }
}

/// Outline-style bubble that opens a free-form chat without a pre-set prompt.
class _AskCustomBubble extends StatelessWidget {
  const _AskCustomBubble({
    required this.entry,
    required this.onClose,
    required this.maxWidth,
  });

  final FeedEntry entry;
  final VoidCallback onClose;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: InkWell(
          onTap: () => _navigateToChat(context),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(AppRadius.xl + 4),
            topRight: Radius.circular(AppRadius.xl + 4),
            bottomLeft: Radius.circular(AppRadius.xl + 4),
            bottomRight: Radius.circular(AppRadius.sm),
          ),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppRadius.xl + 4),
                topRight: Radius.circular(AppRadius.xl + 4),
                bottomLeft: Radius.circular(AppRadius.xl + 4),
                bottomRight: Radius.circular(AppRadius.sm),
              ),
              border: Border.all(
                color: const Color(0xFF1D4ED8).withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.edit_outlined,
                  size: 16,
                  color: const Color(0xFF1D4ED8).withValues(alpha: 0.9),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Ask something else...',
                  style: textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF1D4ED8).withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToChat(BuildContext context) {
    onClose();

    final articleEntry = _convertToArticleEntry(entry);

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ChatDetailPage(
          article: articleEntry,
        ),
      ),
    );
  }

  ArticleFeedEntry _convertToArticleEntry(FeedEntry entry) {
    if (entry is ArticleFeedEntry) {
      return entry;
    }

    final video = entry as VideoFeedEntry;
    return ArticleFeedEntry(
      id: -video.id,
      title: video.title,
      summary: video.summary,
      source: video.source,
      publishedAt: video.publishedAt,
      url: video.link,
      imageUrl: video.thumbnailUrl ?? '',
      category: video.category,
      readTime: video.readTime,
    );
  }
}
