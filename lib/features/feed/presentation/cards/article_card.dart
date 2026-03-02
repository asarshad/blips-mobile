import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/presentation/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:url_launcher/url_launcher.dart';

/// Card widget for displaying article feed entries.
/// Includes media preview, metadata, and action buttons.
class ArticleCard extends HookWidget {
  const ArticleCard({super.key, required this.entry, this.isVisible = true});

  final ArticleFeedEntry entry;
  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    final showBubbles = useState(false);

    // Collapse bubbles when card scrolls out of view or outer tab changes
    useEffect(() {
      if (!isVisible) showBubbles.value = false;
      return null;
    }, [isVisible]);

    return Stack(
      children: [
        FeedCardFrame(
          media: _ArticleMedia(imageUrl: entry.imageUrl),
          category: entry.category,
          title: entry.title,
          summary: entry.summary,
          source: entry.source,
          freshnessInfo: FreshnessInfo(
            publishedAt: entry.publishedAt,
            addedAt: entry.addedAt,
            tier: entry.freshnessTier,
          ),
          readTime: '${entry.readTime} min read',
          onTap: () => _handleTap(showBubbles),
          onOpenLink: () => _openInBrowser(entry.url),
          onChat: () => showBubbles.value = !showBubbles.value,
          onShare: () => _shareArticle(context),
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

  Future<void> _handleTap(ValueNotifier<bool> showBubbles) async {
    if (showBubbles.value) {
      showBubbles.value = false;
      return;
    }

    final uri = Uri.parse(entry.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openInBrowser(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _shareArticle(BuildContext context) async {
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
  const _ArticleMedia({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    // Guard against empty or whitespace-only URLs that slip through
    if (imageUrl.trim().isEmpty) {
      return _placeholder();
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return _placeholder(loading: true);
      },
      errorBuilder: (_, __, ___) => _placeholder(),
    );
  }

  /// Gradient placeholder shown while loading or when the image is unavailable.
  static Widget _placeholder({bool loading = false}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blueGrey.shade800,
            Colors.blueGrey.shade900,
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        loading ? Icons.image_outlined : Icons.article_outlined,
        size: 36,
        color: Colors.white30,
      ),
    );
  }
}
