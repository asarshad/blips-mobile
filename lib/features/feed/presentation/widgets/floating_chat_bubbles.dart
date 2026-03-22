import 'dart:async';

import 'package:blips_mobile/core/error/error.dart';
import 'package:blips_mobile/core/theme/theme.dart';
import 'package:blips_mobile/features/chat/presentation/chat_detail_page.dart';
import 'package:blips_mobile/features/feed/data/feed_repository.dart';
import 'package:blips_mobile/features/feed/data/feed_session_store.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/providers/feed_providers.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Default fallback starters when inline data is unavailable.
const _defaultFallbackStarters = [
  'What are the key takeaways?',
  'Can you explain the main concepts?',
  'How does this affect everyday users?',
];

/// Floating chat bubble suggestions that appear when tapping the chat button.
/// Uses inline conversation starters from the feed response (pre-generated
/// during content ingestion). Falls back to static defaults if unavailable.
///
/// Layout Strategy:
/// - Right-aligned to connect visually with the chat button in the footer
/// - Max width of 85% screen width to prevent overflow on small screens
/// - Bottom-right corner has small radius to point toward the button
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxBubbleWidth = constraints.maxWidth * _maxWidthFraction;

        // Use inline starters from the feed response (pre-generated during
        // ingestion). Fall back to static defaults if unavailable.
        final starters = entry.conversationStarters.isNotEmpty
            ? entry.conversationStarters
            : _defaultFallbackStarters;

        return _buildBubbles(context, ref, starters, maxBubbleWidth);
      },
    );
  }

  Widget _buildBubbles(
    BuildContext context,
    WidgetRef ref,
    List<String> questions,
    double maxBubbleWidth,
  ) {
    // Filter out any empty/blank strings to prevent blank bubbles
    final validQuestions =
        questions.where((q) => q.trim().isNotEmpty).take(3).toList();

    // Fall back to defaults if all starters were empty
    final displayQuestions =
        validQuestions.isNotEmpty ? validQuestions : _defaultFallbackStarters;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...displayQuestions.map((q) => _ChatBubble(
              question: q,
              entry: entry,
              onClose: onClose,
              maxWidth: maxBubbleWidth,
              ref: ref,
            )),
        _AskCustomBubble(
          entry: entry,
          onClose: onClose,
          maxWidth: maxBubbleWidth,
          ref: ref,
        ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.question,
    required this.entry,
    required this.onClose,
    required this.maxWidth,
    required this.ref,
  });

  final String question;
  final FeedEntry entry;
  final VoidCallback onClose;
  final double maxWidth;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final primary = colorScheme.primary;
    final onPrimary = colorScheme.onPrimary;

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
              color: primary.withValues(alpha: 0.95),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppRadius.xl + 4),
                topRight: Radius.circular(AppRadius.xl + 4),
                bottomLeft: Radius.circular(AppRadius.xl + 4),
                bottomRight: Radius.circular(AppRadius.sm),
              ),
              border: Border.all(
                color: primary.withValues(alpha: 0.5),
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
                color: onPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToChat(BuildContext context) async {
    final navigator = Navigator.of(context);
    final articleEntry = _asChatArticleEntry(entry);
    onClose();
    unawaited(_recordChatStart(ref, entry));

    await navigator.push(
      MaterialPageRoute<void>(
        builder: (context) => ChatDetailPage(
          article: articleEntry,
          initialPrompt: question,
        ),
      ),
    );

    // Safety net: ensure bubbles are closed after returning from chat.
    onClose();
  }
}

/// Outline-style bubble that opens a free-form chat without a pre-set prompt.
class _AskCustomBubble extends StatelessWidget {
  const _AskCustomBubble({
    required this.entry,
    required this.onClose,
    required this.maxWidth,
    required this.ref,
  });

  final FeedEntry entry;
  final VoidCallback onClose;
  final double maxWidth;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final primary = Theme.of(context).colorScheme.primary;

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
                color: primary.withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 16,
                  color: primary.withValues(alpha: 0.9),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    'Ask something else...',
                    style: textTheme.bodyMedium?.copyWith(
                      color: primary.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToChat(BuildContext context) async {
    final navigator = Navigator.of(context);
    final articleEntry = _asChatArticleEntry(entry);
    onClose();
    unawaited(_recordChatStart(ref, entry));

    await navigator.push(
      MaterialPageRoute<void>(
        builder: (context) => ChatDetailPage(
          article: articleEntry,
        ),
      ),
    );

    // Safety net: ensure bubbles are closed after returning from chat.
    onClose();
  }
}

ArticleFeedEntry _asChatArticleEntry(FeedEntry entry) {
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
    imageUrl: video.thumbnailUrl,
    category: video.category,
    readTime: video.readTime,
  );
}

Future<void> _recordChatStart(WidgetRef ref, FeedEntry entry) async {
  final repository = ref.read(feedRepositoryProvider);
  final sessionStore = ref.read(feedSessionStoreProvider);
  final surface = switch (entry) {
    ArticleFeedEntry() => FeedSurface.articles,
    ReelFeedEntry() => FeedSurface.reels,
    VideoFeedEntry() => FeedSurface.videos,
    _ => FeedSurface.articles,
  };
  final surfaceName = surface.storageKey;

  await repository.recordInteraction(
    contentItemId: entry.id,
    eventType: FeedInteractionEvent.chatStart,
    extraData: {'surface': surfaceName},
  );
  try {
    await sessionStore.markConsumed(surface, entry.id);
  } catch (error, stackTrace) {
    logger.warning(
      'Failed to persist consumed state for chat start',
      category: LogCategory.app,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
