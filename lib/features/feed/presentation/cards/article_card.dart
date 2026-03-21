import 'dart:async';

import 'package:blips_mobile/core/error/error.dart';
import 'package:blips_mobile/features/feed/data/feed_repository.dart';
import 'package:blips_mobile/features/feed/data/feed_session_store.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/presentation/widgets/widgets.dart';
import 'package:blips_mobile/features/feed/providers/feed_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showBubbles = useState(false);
    final repository = ref.read(feedRepositoryProvider);
    final sessionStore = ref.read(feedSessionStoreProvider);

    // Collapse bubbles when card scrolls out of view or outer tab changes
    useEffect(() {
      if (!isVisible) showBubbles.value = false;
      return null;
    }, [isVisible]);

    return Stack(
      children: [
        FeedCardFrame(
          media: _ArticleMedia(
            imageUrl: entry.imageUrl,
            category: entry.category,
            source: entry.source,
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
          onTap: () => _handleTap(showBubbles, repository, sessionStore),
          onOpenLink: () => _openInBrowser(entry.url, repository, sessionStore),
          onChat: () => showBubbles.value = !showBubbles.value,
          onShare: () => _shareArticle(context, repository, sessionStore),
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

  Future<void> _handleTap(
    ValueNotifier<bool> showBubbles,
    FeedRepository repository,
    FeedSessionStore sessionStore,
  ) async {
    if (showBubbles.value) {
      showBubbles.value = false;
      return;
    }

    unawaited(_recordOpenSourceIntent(repository, sessionStore));
    final uri = Uri.parse(entry.url);
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      logger.warning(
        'Failed to launch article URL from card tap',
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
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.month}/${date.day}/${date.year}';
  }
}

class _ArticleMedia extends StatelessWidget {
  const _ArticleMedia({
    required this.imageUrl,
    required this.category,
    required this.source,
  });

  final String? imageUrl;
  final String category;
  final String source;

  @override
  Widget build(BuildContext context) {
    final mediaUrl = imageUrl?.trim();
    if (mediaUrl == null || mediaUrl.isEmpty) {
      return _CategoryPlaceholder(category: category, source: source);
    }

    return Image.network(
      mediaUrl,
      fit: BoxFit.cover,
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return _CategoryPlaceholder(
          category: category,
          source: source,
          loading: true,
        );
      },
      errorBuilder: (_, __, ___) =>
          _CategoryPlaceholder(category: category, source: source),
    );
  }
}

/// Category-aware placeholder displayed when an article has no image.
///
/// Uses a gradient and icon matched to the article's category so the card
/// still looks intentional rather than broken.
class _CategoryPlaceholder extends StatelessWidget {
  const _CategoryPlaceholder({
    required this.category,
    required this.source,
    this.loading = false,
  });

  final String category;
  final String source;
  final bool loading;

  static const _gradients = {
    'artificial intelligence': [Color(0xFF4F46E5), Color(0xFF7C3AED)],
    'ai': [Color(0xFF4F46E5), Color(0xFF7C3AED)],
    'technology': [Color(0xFF1D4ED8), Color(0xFF0369A1)],
    'science': [Color(0xFF0F766E), Color(0xFF0369A1)],
    'business': [Color(0xFF15803D), Color(0xFF0F766E)],
    'finance': [Color(0xFF15803D), Color(0xFF166534)],
    'health': [Color(0xFFBE185D), Color(0xFF9D174D)],
    'politics': [Color(0xFF475569), Color(0xFF1E293B)],
    'sports': [Color(0xFFEA580C), Color(0xFFB45309)],
    'entertainment': [Color(0xFFD97706), Color(0xFFB45309)],
  };

  static const _icons = {
    'artificial intelligence': Icons.smart_toy_outlined,
    'ai': Icons.smart_toy_outlined,
    'technology': Icons.devices_outlined,
    'science': Icons.science_outlined,
    'business': Icons.trending_up_outlined,
    'finance': Icons.attach_money_outlined,
    'health': Icons.favorite_outline,
    'politics': Icons.account_balance_outlined,
    'sports': Icons.sports_outlined,
    'entertainment': Icons.movie_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final key = category.toLowerCase();
    final colors =
        _gradients[key] ?? [const Color(0xFF334155), const Color(0xFF1E293B)];
    final icon = _icons[key] ?? Icons.article_outlined;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        children: [
          // Large faded icon as background texture
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              icon,
              size: 160,
              color: Colors.white.withValues(alpha: 0.07),
            ),
          ),
          // Centred content
          Center(
            child: loading
                ? const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white54,
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 48, color: Colors.white70),
                      const SizedBox(height: 12),
                      Text(
                        category.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
          ),
          // Source badge at bottom-left
          if (!loading)
            Positioned(
              left: 16,
              bottom: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  source,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
