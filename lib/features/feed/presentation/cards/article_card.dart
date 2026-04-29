import 'dart:async';

import 'package:blips_mobile/core/error/error.dart';
import 'package:blips_mobile/features/feed/data/feed_repository.dart';
import 'package:blips_mobile/features/feed/data/feed_session_store.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/presentation/widgets/widgets.dart';
import 'package:blips_mobile/features/feed/providers/blocked_sources_provider.dart';
import 'package:blips_mobile/features/feed/providers/feed_providers.dart';
import 'package:blips_mobile/features/feed/providers/saved_items_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

enum _ArticleCardAction { lessFromCreator, report }

/// Card widget for displaying article feed entries.
/// Includes media preview, metadata, and action buttons.
class ArticleCard extends HookConsumerWidget {
  const ArticleCard({
    super.key,
    required this.entry,
    this.isVisible = true,
    this.isNewSinceLastSeen = false,
  });

  final ArticleFeedEntry entry;
  final bool isVisible;
  final bool isNewSinceLastSeen;

  String get _imageHeroTag => 'article-image-${entry.id}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showBubbles = useState(false);
    final repository = ref.read(feedRepositoryProvider);
    final sessionStore = ref.read(feedSessionStoreProvider);
    final isSaved = ref.watch(savedArticleIdsProvider).contains(entry.id);

    // Collapse bubbles when card scrolls out of view or outer tab changes
    useEffect(() {
      if (!isVisible) showBubbles.value = false;
      return null;
    }, [isVisible]);

    return Stack(
      children: [
        FeedCardFrame(
          media: Hero(
            tag: _imageHeroTag,
            child: ArticleImage.hero(
              imageUrl: entry.imageUrl,
              category: entry.category,
              source: entry.source,
            ),
          ),
          category: entry.category,
          title: entry.title,
          titleMaxLines: 2,
          summary: entry.summary,
          source: entry.source,
          freshnessInfo: FreshnessInfo(
            publishedAt: entry.publishedAt,
            addedAt: entry.addedAt,
            tier: entry.freshnessTier,
            isNewSinceLastSeen: isNewSinceLastSeen,
          ),
          readTime: '${entry.readTime} min read',
          onMediaTap: () => _handleMediaTap(
            context,
            showBubbles,
            repository,
            sessionStore,
          ),
          onContentTap: () => _openInBrowser(
            entry.url,
            repository,
            sessionStore,
          ),
          onLongPress: () =>
              _showActionsSheet(context, ref, repository),
          onChat: () => showBubbles.value = !showBubbles.value,
          onShare: () => _shareArticle(context, repository, sessionStore),
          onSaveToggle: () => unawaited(
            ref.read(savedArticlesProvider.notifier).toggle(entry),
          ),
          isSaved: isSaved,
        ),
        if (showBubbles.value)
          Positioned(
            bottom: 60,
            right: 16,
            left: 16,
            child: FloatingChatBubbles(
              entry: entry,
              onClose: () => showBubbles.value = false,
            ),
          ),
      ],
    );
  }

  Future<void> _handleMediaTap(
    BuildContext context,
    ValueNotifier<bool> showBubbles,
    FeedRepository repository,
    FeedSessionStore sessionStore,
  ) async {
    if (showBubbles.value) {
      showBubbles.value = false;
      return;
    }

    final mediaUrl = entry.imageUrl?.trim();
    if (mediaUrl != null && mediaUrl.isNotEmpty) {
      await ArticleImageViewer.show(
        context,
        imageUrl: mediaUrl,
        heroTag: _imageHeroTag,
      );
      return;
    }

    unawaited(_recordOpenSourceIntent(repository, sessionStore));
    final uri = Uri.parse(entry.url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      logger.warning(
        'Failed to launch article URL from image tap fallback',
        category: LogCategory.app,
        error: entry.url,
      );
    }
  }

  Future<void> _openInBrowser(
    String url,
    FeedRepository repository,
    FeedSessionStore sessionStore,
  ) async {
    unawaited(_recordOpenSourceIntent(repository, sessionStore));
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      logger.warning(
        'Failed to launch article URL from action button',
        category: LogCategory.app,
        error: url,
      );
    }
  }

  Future<void> _recordOpenSourceIntent(
    FeedRepository repository,
    FeedSessionStore sessionStore,
  ) async {
    await repository.recordInteraction(
      contentItemId: entry.id,
      eventType: FeedInteractionEvent.openSource,
      extraData: const {'surface': 'articles'},
    );
    try {
      await sessionStore.markConsumed(FeedSurface.articles, entry.id);
    } catch (error, stackTrace) {
      logger.warning(
        'Failed to persist article consumed state',
        category: LogCategory.app,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _shareArticle(
    BuildContext context,
    FeedRepository repository,
    FeedSessionStore sessionStore,
  ) async {
    unawaited(_recordShareIntent(repository, sessionStore));
    await ShareService.instance.shareArticle(
      context: context,
      title: entry.title,
      summary: entry.summary,
      source: entry.source,
      category: entry.category,
      date: _formatDate(entry.publishedAt),
      readTime: '${entry.readTime} min read',
      imageUrl: entry.imageUrl,
      articleUrl: entry.url,
    );
  }

  Future<void> _recordShareIntent(
    FeedRepository repository,
    FeedSessionStore sessionStore,
  ) async {
    await repository.recordInteraction(
      contentItemId: entry.id,
      eventType: FeedInteractionEvent.share,
      extraData: const {'surface': 'articles'},
    );
    try {
      await sessionStore.markConsumed(FeedSurface.articles, entry.id);
    } catch (error, stackTrace) {
      logger.warning(
        'Failed to persist article consumed state after share',
        category: LogCategory.app,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now().toLocal();
    final local = date.toLocal();
    final days =
        DateUtils.dateOnly(now).difference(DateUtils.dateOnly(local)).inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (days < 7) return '${days}d ago';
    return '${local.month}/${local.day}/${local.year}';
  }

  Future<void> _showActionsSheet(
    BuildContext context,
    WidgetRef ref,
    FeedRepository repository,
  ) async {
    final action = await showModalBottomSheet<_ArticleCardAction>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.block_outlined),
              title: Text('Block ${entry.source}'),
              subtitle: const Text(
                  'Remove all content from this source immediately.'),
              onTap: () => Navigator.of(ctx)
                  .pop(_ArticleCardAction.lessFromCreator),
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Report'),
              subtitle: const Text('Flag this article for review.'),
              onTap: () =>
                  Navigator.of(ctx).pop(_ArticleCardAction.report),
            ),
          ],
        ),
      ),
    );

    if (action == null || !context.mounted) return;

    switch (action) {
      case _ArticleCardAction.lessFromCreator:
        await ref.read(blockedSourcesProvider.notifier).block(entry.source);
        unawaited(repository.recordInteraction(
          contentItemId: entry.id,
          eventType: FeedInteractionEvent.lessFromCreator,
          extraData: {'surface': 'articles', 'source': entry.source},
        ));
        if (context.mounted) {
          _showFeedback(
              context, '${entry.source} blocked and removed from your feed.');
        }
      case _ArticleCardAction.report:
        if (!context.mounted) return;
        final reason = await ContentReportSheet.show(context);
        if (reason == null || !context.mounted) return;
        final ok = await repository.reportContent(
          contentItemId: entry.id,
          surface: 'articles',
          reason: reason,
        );
        if (context.mounted) {
          _showFeedback(
            context,
            ok
                ? 'Thanks — we\'ll review this content.'
                : 'Couldn\'t submit your report. Please try again.',
          );
        }
    }
  }

  void _showFeedback(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
