import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/presentation/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

/// Card widget for displaying article feed entries.
/// Includes media preview, metadata, and action buttons.
class ArticleCard extends HookWidget {
  const ArticleCard({super.key, required this.entry});

  final ArticleFeedEntry entry;

  @override
  Widget build(BuildContext context) {
    final showBubbles = useState(false);
    final dateLabel =
        DateFormat('MMM d, yyyy').format(entry.publishedAt.toLocal());

    return Stack(
      children: [
        FeedCardFrame(
          media: _ArticleMedia(imageUrl: entry.imageUrl),
          category: entry.category,
          title: entry.title,
          summary: entry.summary,
          source: entry.source,
          date: dateLabel,
          readTime: '${entry.readTime} min read',
          onTap: () => _handleTap(showBubbles),
          onOpenLink: () => _openInBrowser(entry.url),
          onChat: () => showBubbles.value = !showBubbles.value,
          onShare: () => _shareArticle(context),
        ),
        if (showBubbles.value)
          Positioned(
            bottom: 70,
            right: 20,
            left: 40,
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
    final dateLabel =
        DateFormat('MMM d, yyyy').format(entry.publishedAt.toLocal());

    await ShareService.instance.shareArticle(
      context: context,
      title: entry.title,
      summary: entry.summary,
      source: entry.source,
      category: entry.category,
      date: dateLabel,
      readTime: '${entry.readTime} min read',
      imageUrl: entry.imageUrl,
      articleUrl: entry.url,
    );
  }
}

class _ArticleMedia extends StatelessWidget {
  const _ArticleMedia({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey.shade900,
        alignment: Alignment.center,
        child: const Icon(
          Icons.broken_image_outlined,
          size: 32,
          color: Colors.white54,
        ),
      ),
    );
  }
}
