import 'dart:io';
import 'package:flutter/foundation.dart';
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
import 'package:blips_mobile/features/feed/presentation/optimized_reels_page.dart';
import 'package:blips_mobile/features/feed/providers/optimized_video_provider.dart';
import 'package:video_player/video_player.dart';

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
    final horizontalPageController = usePageController();
    final articleFeed = ref.watch(filteredArticleFeedProvider);
    final videoFeed = ref.watch(filteredVideoFeedProvider);
    final videoManager = ref.watch(optimizedVideoManagerProvider);
    final reelsFeed = ref.watch(reelsFeedProvider);

    // Preload first reel when app opens (regardless of current tab)
    useEffect(() {
      if (reelsFeed.hasValue && reelsFeed.value!.isNotEmpty) {
        final firstReelUrl = reelsFeed.value!.first.link;
        videoManager.preload(firstReelUrl);
        debugPrint('Preloading first reel on app start: $firstReelUrl');
      }
      return null;
    }, [reelsFeed.hasValue]);

    // Pause all videos when navigating away from video tabs (1=Videos, 2=Reels)
    useEffect(() {
      final isOnVideoTab = currentIndex.value == 1 || currentIndex.value == 2;
      if (!isOnVideoTab) {
        videoManager.pauseAll();
      }
      return null;
    }, [currentIndex.value]);

    // Sync page controller with bottom nav
    useEffect(() {
      if (horizontalPageController.hasClients &&
          horizontalPageController.page?.round() != currentIndex.value) {
        horizontalPageController.animateToPage(
          currentIndex.value,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      return null;
    }, [currentIndex.value]);

    // All tabs in one swipeable PageView
    final allTabs = [
      _FeedTab<ArticleFeedEntry>(
        feed: articleFeed,
        emptyLabel: 'Articles are warming up.',
        builder: (entry) => _ArticleCard(entry: entry),
        onRefresh: () => ref.invalidate(paginatedFeedProvider),
        onLoadMore: () => ref.read(paginatedFeedProvider.notifier).loadMore(),
      ),
      _FeedTab<VideoFeedEntry>(
        feed: videoFeed,
        emptyLabel: 'Videos are warming up.',
        builder: (entry) => _VideoCard(entry: entry, isVisible: currentIndex.value == 1),
        onRefresh: () => ref.invalidate(paginatedFeedProvider),
        onLoadMore: () => ref.read(paginatedFeedProvider.notifier).loadMore(),
      ),
      OptimizedReelsPage(isVisible: currentIndex.value == 2),
      const ChatPage(),
      const SettingsPage(),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: PageView(
        controller: horizontalPageController,
        onPageChanged: (index) {
          currentIndex.value = index;
        },
        children: allTabs,
      ),
      bottomNavigationBar: Container(
        color: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom,
        ),
        child: SizedBox(
          height: 30,
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
                icon: Icons.movie_filter_outlined,
                selectedIcon: Icons.movie_filter,
                label: 'Reels',
                isSelected: currentIndex.value == 2,
                onTap: () => currentIndex.value = 2,
              ),
              _NavBarIcon(
                icon: Icons.chat_bubble_outline,
                selectedIcon: Icons.chat_bubble,
                label: 'Chat',
                isSelected: currentIndex.value == 3,
                onTap: () {
                  currentIndex.value = 3;
                  // Refresh chat list when entering the tab
                  ref.invalidate(chatListProvider);
                },
              ),
              _NavBarIcon(
                icon: Icons.settings_outlined,
                selectedIcon: Icons.settings,
                label: 'Settings',
                isSelected: currentIndex.value == 4,
                onTap: () => currentIndex.value = 4,
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
    final theme = Theme.of(context).bottomNavigationBarTheme;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(
          isSelected ? selectedIcon : icon,
          size: 26,
          color: isSelected
              ? theme.selectedItemColor
              : theme.unselectedItemColor,
        ),
      ),
    );
  }
}

class _FeedTab<T extends FeedEntry> extends HookConsumerWidget {
  const _FeedTab({
    required this.feed,
    required this.builder,
    required this.emptyLabel,
    required this.onRefresh,
    this.onLoadMore,
  });

  final AsyncValue<List<T>> feed;
  final Widget Function(T entry) builder;
  final String emptyLabel;
  final VoidCallback onRefresh;
  final VoidCallback? onLoadMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = usePageController();
    final videoManager = ref.watch(optimizedVideoManagerProvider);

    useEffect(() {
      if (feed.hasValue && feed.value!.isNotEmpty && T == VideoFeedEntry) {
        final entries = feed.value!;
        // Preload first video
        final firstEntry = entries[0] as VideoFeedEntry;
        videoManager.preload(firstEntry.link);
        
        // Preload second
        if (entries.length > 1) {
          final secondEntry = entries[1] as VideoFeedEntry;
          videoManager.preload(secondEntry.link);
        }
      }
      return null;
    }, [feed.hasValue]);

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
            onPageChanged: (index) {
              // Only handle preloading for videos
              if (T == VideoFeedEntry) {
                // 1. Preload current
                final currentEntry = entries[index] as VideoFeedEntry;
                videoManager.preload(currentEntry.link);

                // 2. Pause previous and next (not current)
                if (index > 0) {
                  final prevEntry = entries[index - 1] as VideoFeedEntry;
                  videoManager.pauseVideo(prevEntry.link);
                }
                if (index < entries.length - 1) {
                  final nextEntry = entries[index + 1] as VideoFeedEntry;
                  videoManager.pauseVideo(nextEntry.link);
                }

                // 3. Preload next 2
                if (index + 1 < entries.length) {
                  final nextEntry = entries[index + 1] as VideoFeedEntry;
                  videoManager.preload(nextEntry.link);
                }
                if (index + 2 < entries.length) {
                  final nextNextEntry = entries[index + 2] as VideoFeedEntry;
                  videoManager.preload(nextNextEntry.link);
                }

                // 4. Release old (keep previous one for smooth back swipe)
                if (index > 1) {
                  final oldEntry = entries[index - 2] as VideoFeedEntry;
                  videoManager.releaseVideo(oldEntry.link);
                }
              }

              // Pagination
              if (onLoadMore != null && index >= entries.length - 3) {
                Future.microtask(() => onLoadMore!());
              }
            },
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
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onAction,
            child: Text(actionLabel),
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
            onOpenLink: showActions
                ? () async {
                    final uri = Uri.parse(entry.url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  }
                : null,
            onChat: showActions
                ? () {
                    showBubbles.value = !showBubbles.value;
                  }
                : null,
            onShare: showActions
                ? () {
                    Share.share(
                      'Check out this article: ${entry.url}',
                      subject: entry.title,
                    );
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
                      // Use negative ID to indicate it's a video
                      articleEntry = ArticleFeedEntry(
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
                      color: const Color(0xFF1D4ED8).withValues(alpha: 0.95),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(4),
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

class _VideoCard extends HookConsumerWidget {
  const _VideoCard({
    required this.entry,
    this.isVisible = true,
  });

  final VideoFeedEntry entry;
  final bool isVisible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showBubbles = useState(false);
    final preview = entry.thumbnailUrl ?? _videoFallbackImage;
    final dateLabel =
        DateFormat('MMM d, yyyy').format(entry.publishedAt.toLocal());

    final videoManager = ref.watch(optimizedVideoManagerProvider);
    final controller = videoManager.getController(entry.link);
    final playerState = videoManager.getPlayerState(entry.link);
    
    // Listen to controller changes to update UI (play/pause icon)
    final dummyListenable = useMemoized(ChangeNotifier.new);
    useListenable(controller ?? dummyListenable);

    final isPlayerReady = playerState == PlayerState.ready ||
        playerState == PlayerState.playing ||
        playerState == PlayerState.paused;
    final isLoading = playerState == PlayerState.loading || playerState == null;

    // Handle visibility
    useEffect(() {
      if (!isVisible) {
        videoManager.pauseVideo(entry.link);
      }
      return null;
    }, [isVisible]);

    // Preload video when card appears
    useEffect(() {
      videoManager.preload(entry.link);
      return null;
    }, [entry.link]);

    Widget buildFrame({bool showActions = true}) {
      return Stack(
        children: [
          _FeedCardFrame(
            media: Stack(
              alignment: Alignment.center,
              children: [
                // Always show thumbnail as background/placeholder
                Positioned.fill(
                  child: Image.network(
                    preview,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade900,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined,
                          size: 32, color: Colors.white54),
                    ),
                  ),
                ),
                
                // Show video when ready
                if (controller != null && controller.value.isInitialized)
                  Positioned.fill(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: controller.value.size.width,
                        height: controller.value.size.height,
                        child: VideoPlayer(controller),
                      ),
                    ),
                  ),

                // Gradient overlay
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black54],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),

                // Play button overlay
                if (controller != null && !controller.value.isPlaying && isPlayerReady)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        size: 72,
                        color: Colors.white,
                      ),
                    ),
                  ),

                // Loading indicator
                if (isLoading)
                  const Center(
                    child: CircularProgressIndicator(color: Colors.white),
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
                    
                    if (controller != null && controller.value.isInitialized) {
                      if (controller.value.isPlaying) {
                        videoManager.pauseVideo(entry.link);
                      } else {
                        videoManager.playVideo(entry.link);
                      }
                    } else {
                      // Fallback to opening URL if video failed
                      final uri = Uri.parse(entry.link);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    }
                  }
                : null,
            onOpenLink: showActions
                ? () async {
                    final uri = Uri.parse(entry.link);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  }
                : null,
            onChat: showActions
                ? () {
                    showBubbles.value = !showBubbles.value;
                  }
                : null,
            onShare: showActions
                ? () {
                    Share.share(
                      'Check out this video: ${entry.link}',
                      subject: entry.title,
                    );
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

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white70),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({
    required this.icon,
    required this.onTap,
    this.color = Colors.black45,
    this.iconColor = Colors.white,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
    );
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
          color: theme.cardColor, // Use theme card color
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
            Expanded(
              flex: 35,
              child: SizedBox.expand(child: media),
            ),
            Expanded(
              flex: 65,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(15, 10, 15, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            (category == 'Artificial Intelligence' ? 'AI' : category).toUpperCase(),
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
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
                          InkWell(
                            onTap: onOpenLink,
                            customBorder: const CircleBorder(),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Icon(
                                Icons.open_in_new,
                                color: colorScheme.onSurfaceVariant,
                                size: 20,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: onShare,
                            customBorder: const CircleBorder(),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Icon(
                                Icons.share_outlined,
                                color: colorScheme.onSurfaceVariant,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.headlineSmall?.copyWith(
                        color: colorScheme.onSurface,
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
                          color: colorScheme.onSurfaceVariant,
                          height: 1.4,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 0),
                    Divider(color: theme.colorScheme.onSurface.withValues(alpha: 0.1), height: 1),
                    const SizedBox(height: 0),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 14, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text(
                          date,
                          style: TextStyle(
                              color: colorScheme.onSurfaceVariant, fontSize: 13),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.access_time,
                            size: 14, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text(
                          readTime,
                          style: TextStyle(
                              color: colorScheme.onSurfaceVariant, fontSize: 13),
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
                                child:
                                    Icon(Icons.bolt, color: colorScheme.onPrimary),
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
