import 'dart:io';
import 'package:blips_mobile/features/chat/presentation/chat_detail_page.dart';
import 'package:blips_mobile/features/chat/presentation/chat_page.dart';
import 'package:blips_mobile/features/chat/providers/chat_providers.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/providers/feed_providers.dart';
import 'package:blips_mobile/features/settings/presentation/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

const _videoFallbackImage =
    'https://images.unsplash.com/photo-1504384308090-c894fdcc538d?w=800';

/// Root shell that now mirrors the native tab experience.
class FeedShellPage extends HookConsumerWidget {
  /// Creates the feed shell.
  const FeedShellPage({super.key});

  /// Router path for the tab scaffold.
  static const path = '/';

  /// Router name for the tab scaffold.
  static const name = 'feed';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = useState(0);
    final articleFeed = ref.watch(articleFeedProvider);
    final videoFeed = ref.watch(videoFeedProvider);

    final tabs = [
      _FeedTab<ArticleFeedEntry>(
        feed: articleFeed,
        emptyLabel: 'Articles are warming up.',
        builder: (entry) => _ArticleCard(entry: entry),
        onRefresh: () => ref.invalidate(feedItemsProvider),
      ),
      _FeedTab<VideoFeedEntry>(
        feed: videoFeed,
        emptyLabel: 'Videos are warming up.',
        builder: (entry) => _VideoCard(entry: entry),
        onRefresh: () => ref.invalidate(feedItemsProvider),
      ),
      const ChatPage(),
      const SettingsPage(),
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      body: IndexedStack(
        index: currentIndex.value,
        children: tabs,
      ),
      bottomNavigationBar: Container(
        color: const Color(0xFF020817),
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom,
        ),
        child: SizedBox(
          height: 35,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavBarIcon(
                icon: Icons.article_outlined,
                selectedIcon: Icons.article,
                label: 'Feed',
                isSelected: currentIndex.value == 0,
                onTap: () => currentIndex.value = 0,
              ),
              _NavBarIcon(
                icon: Icons.play_circle_outline,
                selectedIcon: Icons.play_circle,
                label: 'Videos',
                isSelected: currentIndex.value == 1,
                onTap: () => currentIndex.value = 1,
              ),
              _NavBarIcon(
                icon: Icons.chat_bubble_outline,
                selectedIcon: Icons.chat_bubble,
                label: 'Chat',
                isSelected: currentIndex.value == 2,
                onTap: () {
                  currentIndex.value = 2;
                  // Refresh chat list when entering the tab
                  ref.invalidate(chatListProvider);
                },
              ),
              _NavBarIcon(
                icon: Icons.settings_outlined,
                selectedIcon: Icons.settings,
                label: 'Settings',
                isSelected: currentIndex.value == 3,
                onTap: () => currentIndex.value = 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavBarIcon extends StatelessWidget {
  const _NavBarIcon({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(
          isSelected ? selectedIcon : icon,
          size: 26,
          color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFF9CA3AF),
        ),
      ),
    );
  }
}

class _FeedTab<T extends FeedEntry> extends HookWidget {
  const _FeedTab({
    required this.feed,
    required this.builder,
    required this.emptyLabel,
    required this.onRefresh,
  });

  final AsyncValue<List<T>> feed;
  final Widget Function(T entry) builder;
  final String emptyLabel;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final controller = usePageController();

    return SafeArea(
      bottom: false,
      child: feed.when(
        data: (entries) {
          if (entries.isEmpty) {
            return _FeedMessageState(
              message: emptyLabel,
              actionLabel: 'Refresh',
              onAction: onRefresh,
            );
          }

          return PageView.builder(
            controller: controller,
            scrollDirection: Axis.vertical,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            itemCount: entries.length,
            itemBuilder: (context, index) => SizedBox.expand(
              child: builder(entries[index]),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _FeedMessageState(
          message: 'Unable to load this feed right now.',
          actionLabel: 'Try again',
          onAction: onRefresh,
        ),
      ),
    );
  }
}

class _FeedMessageState extends StatelessWidget {
  const _FeedMessageState({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onAction,
            style: FilledButton.styleFrom(backgroundColor: Colors.white),
            child: Text(
              actionLabel,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArticleCard extends HookWidget {
  const _ArticleCard({required this.entry});

  final ArticleFeedEntry entry;

  @override
  Widget build(BuildContext context) {
    final screenshotController = useMemoized(() => ScreenshotController());
    final showBubbles = useState(false);
    final dateLabel =
        DateFormat('MMM d, yyyy').format(entry.publishedAt.toLocal());

    Widget buildFrame({bool showActions = true}) {
      return Stack(
        children: [
          _FeedCardFrame(
            media: Image.network(
              entry.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey.shade900,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined,
                    size: 32, color: Colors.white54),
              ),
            ),
            category: entry.category,
            title: entry.title,
            summary: entry.summary,
            source: entry.source,
            date: dateLabel,
            readTime: '${entry.readTime} min read',
            showActions: showActions,
            onTap: showActions
                ? () async {
                    // Close bubbles if open when tapping elsewhere
                    if (showBubbles.value) {
                      showBubbles.value = false;
                      return;
                    }
                    final uri = Uri.parse(entry.url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  }
                : null,
            onChat: showActions
                ? () {
                    showBubbles.value = !showBubbles.value;
                  }
                : null,
            onShare: showActions
                ? () async {
                    try {
                      // Hide bubbles before screenshot
                      showBubbles.value = false;
                      
                      final image = await screenshotController.captureFromWidget(
                        Theme(
                          data: Theme.of(context),
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width,
                            height: MediaQuery.of(context).size.height * 0.8,
                            child: buildFrame(showActions: false),
                          ),
                        ),
                        delay: const Duration(milliseconds: 10),
                        context: context,
                      );
                      final directory = await getTemporaryDirectory();
                      final file = File('${directory.path}/share.png');
                      await file.writeAsBytes(image);
                      await Share.shareXFiles(
                        [XFile(file.path)],
                        text: 'Check out this article: ${entry.url}',
                      );
                    } catch (e) {
                      debugPrint('Error sharing: $e');
                    }
                  }
                : null,
          ),
          if (showBubbles.value && showActions)
            Positioned(
              bottom: 70,
              right: 20,
              left: 40,
              child: _FloatingChatBubbles(
                entry: entry,
                onClose: () => showBubbles.value = false,
              ),
            ),
        ],
      );
    }

    return buildFrame();
  }
}

class _FloatingChatBubbles extends StatelessWidget {
  const _FloatingChatBubbles({
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
      children: questions
          .map((q) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () {
                    onClose();
                    
                    ArticleFeedEntry articleEntry;
                    if (entry is ArticleFeedEntry) {
                      articleEntry = entry as ArticleFeedEntry;
                    } else {
                      final video = entry as VideoFeedEntry;
                      articleEntry = ArticleFeedEntry(
                        id: video.id,
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

                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ChatDetailPage(
                          article: articleEntry,
                          initialPrompt: q,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D4ED8).withOpacity(0.95),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(4),
                      ),
                      border: Border.all(
                        color: const Color(0xFF1D4ED8).withOpacity(0.5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      q,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _VideoCard extends HookWidget {
  const _VideoCard({required this.entry});

  final VideoFeedEntry entry;

  @override
  Widget build(BuildContext context) {
    final screenshotController = useMemoized(() => ScreenshotController());
    final showBubbles = useState(false);
    final preview = entry.thumbnailUrl ?? _videoFallbackImage;
    final dateLabel =
        DateFormat('MMM d, yyyy').format(entry.publishedAt.toLocal());

    Widget buildFrame({bool showActions = true}) {
      return Stack(
        children: [
          _FeedCardFrame(
            media: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  preview,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade900,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined,
                        size: 32, color: Colors.white54),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black54],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                const Align(
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.white24,
                    child: Icon(
                      Icons.play_arrow_rounded,
                      size: 42,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            category: entry.category,
            title: entry.title,
            summary: entry.summary,
            source: entry.source,
            date: dateLabel,
            readTime: '${entry.readTime} min watch',
            showActions: showActions,
            onTap: showActions
                ? () async {
                    if (showBubbles.value) {
                      showBubbles.value = false;
                      return;
                    }
                    final uri = Uri.parse(entry.link);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  }
                : null,
            onChat: showActions
                ? () {
                    showBubbles.value = !showBubbles.value;
                  }
                : null,
            onShare: showActions
                ? () async {
                    try {
                      showBubbles.value = false;
                      final image = await screenshotController.captureFromWidget(
                        Theme(
                          data: Theme.of(context),
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width,
                            height: MediaQuery.of(context).size.height * 0.8,
                            child: buildFrame(showActions: false),
                          ),
                        ),
                        delay: const Duration(milliseconds: 10),
                        context: context,
                      );
                      final directory = await getTemporaryDirectory();
                      final file = File('${directory.path}/share.png');
                      await file.writeAsBytes(image);
                      await Share.shareXFiles(
                        [XFile(file.path)],
                        text: 'Check out this video: ${entry.link}',
                      );
                    } catch (e) {
                      debugPrint('Error sharing: $e');
                    }
                  }
                : null,
          ),
          if (showBubbles.value && showActions)
            Positioned(
              bottom: 70,
              right: 20,
              left: 40,
              child: _FloatingChatBubbles(
                entry: entry,
                onClose: () => showBubbles.value = false,
              ),
            ),
        ],
      );
    }

    return buildFrame();
  }
}

class _FeedCardFrame extends StatelessWidget {
  const _FeedCardFrame({
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
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(12),
        ),
        width: double.infinity,
        height: double.infinity,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 35,
              child: SizedBox.expand(child: media),
            ),
            Expanded(
              flex: 65,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(15, 10, 15, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0E7490).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            category.toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF22D3EE),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          source,
                          style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        if (showActions)
                          InkWell(
                            onTap: onShare,
                            customBorder: const CircleBorder(),
                            child: const Padding(
                              padding: EdgeInsets.fromLTRB(8, 8, 4, 8),
                              child: Icon(
                                Icons.share_outlined,
                                color: Color(0xFF9CA3AF),
                                size: 20,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.headlineSmall?.copyWith(
                        color: const Color(0xFFF8FAFC),
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Text(
                        summary,
                        style: textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFFD1D5DB),
                          height: 1.4,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFF374151), height: 1),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 14, color: Color(0xFF9CA3AF)),
                        const SizedBox(width: 6),
                        Text(
                          date,
                          style: const TextStyle(
                              color: Color(0xFF9CA3AF), fontSize: 13),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.access_time,
                            size: 14, color: Color(0xFF9CA3AF)),
                        const SizedBox(width: 6),
                        Text(
                          readTime,
                          style: const TextStyle(
                              color: Color(0xFF9CA3AF), fontSize: 13),
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
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1D4ED8),
                                  shape: BoxShape.circle,
                                ),
                                child:
                                    const Icon(Icons.bolt, color: Colors.white),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
