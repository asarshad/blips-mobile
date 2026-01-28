import 'package:blips_mobile/core/theme/theme.dart';
import 'package:blips_mobile/features/chat/presentation/chat_detail_page.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:flutter/material.dart';

/// Floating chat bubble suggestions that appear when tapping the chat button.
/// Shows pre-defined questions users can ask about the content.
class FloatingChatBubbles extends StatelessWidget {
  const FloatingChatBubbles({
    super.key,
    required this.entry,
    required this.onClose,
  });

  final FeedEntry entry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final questions = [
      'What implications might "${entry.title}" have?',
      'Can you explain the main points?',
      "What's your opinion on this topic?",
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: questions.map((q) => _ChatBubble(
        question: q,
        entry: entry,
        onClose: onClose,
      )).toList(),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.question,
    required this.entry,
    required this.onClose,
  });

  final String question;
  final FeedEntry entry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: () => _navigateToChat(context),
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
