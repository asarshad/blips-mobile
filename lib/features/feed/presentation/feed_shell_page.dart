import 'package:blips_mobile/core/error/error.dart';
import 'package:blips_mobile/core/theme/theme.dart';
import 'package:blips_mobile/features/chat/presentation/chat_page.dart';
import 'package:blips_mobile/features/chat/providers/chat_providers.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/presentation/cards/cards.dart';
import 'package:blips_mobile/features/feed/presentation/optimized_reels_page.dart';
import 'package:blips_mobile/features/feed/presentation/tabs/tabs.dart';
import 'package:blips_mobile/features/feed/presentation/widgets/widgets.dart';
import 'package:blips_mobile/features/feed/providers/feed_providers.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager_base.dart';
import 'package:blips_mobile/features/settings/presentation/settings_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Root shell page that hosts all main app tabs.
///
/// Contains:
/// - Articles feed (index 0)
/// - Videos feed (index 1)
/// - Reels feed (index 2)
/// - Chat (index 3)
/// - Settings (index 4)
///
/// All tabs are swipeable horizontally for quick navigation.
class FeedShellPage extends HookConsumerWidget {
  const FeedShellPage({super.key});

  static const path = '/';
  static const name = 'feed';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = useState(0);
    final pageController = usePageController();

    // Watch providers for current view
    final articleFeed = ref.watch(filteredArticleFeedProvider);
    final videoFeed = ref.watch(filteredVideoFeedProvider);
    final videoManager = ref.watch(youtubePlayerManagerProvider);

    // Preload reels in background after first frame
    _useBackgroundReelsPreload(ref, videoManager);

    // Preload first videos in background after first frame
    _useBackgroundVideosPreload(videoFeed, videoManager);

    // Pause videos when navigating away from video tabs
    _useVideoPauseOnNavigate(currentIndex.value, videoManager);

    // Cleanup all video resources when shell page is disposed
    _useLifecycleCleanup(videoManager);

    // Sync page controller with bottom nav
    _usePageControllerSync(pageController, currentIndex.value);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          _buildBody(
            pageController: pageController,
            currentIndex: currentIndex,
            articleFeed: articleFeed,
            videoFeed: videoFeed,
            ref: ref,
          ),
          // Debug overlay for development builds
          if (kDebugMode) const DeviceDebugOverlay(),
        ],
      ),
      bottomNavigationBar: _BottomNavBar(
        currentIndex: currentIndex.value,
        onIndexChanged: (index) {
          currentIndex.value = index;
          if (index == 3) {
            // Refresh chat list when entering chat tab
            ref.invalidate(chatListProvider);
          }
        },
      ),
    );
  }

  void _useBackgroundReelsPreload(
    WidgetRef ref,
    YoutubePlayerManagerBase videoManager,
  ) {
    useEffect(() {
      // Defer reels loading until after first frame to avoid blocking UI
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.microtask(() async {
          try {
            // Read the reels provider and wait for data
            final reelsAsync = ref.read(reelsFeedProvider);
            reelsAsync.maybeWhen(
              data: (reels) => _preloadReels(reels, videoManager),
              orElse: () {
                // If loading/error, wait a bit then check again
                Future.delayed(const Duration(milliseconds: 500), () {
                  final reelsData = ref.read(reelsFeedProvider).valueOrNull;
                  if (reelsData != null) {
                    _preloadReels(reelsData, videoManager);
                  }
                });
              },
            );
          } catch (e, stack) {
            logger.warning(
              'Background reels preload failed',
              category: LogCategory.video,
              error: e,
              stackTrace: stack,
            );
          }
        });
      });
      return null;
    }, []);
  }

  /// Preload first 5 reels in background for instant playback.
  void _preloadReels(
      List<ReelFeedEntry> reels, YoutubePlayerManagerBase manager) {
    if (reels.isEmpty) return;

    // Preload first 5 reels in background
    final preloadCount = reels.length.clamp(0, 5);
    for (var i = 0; i < preloadCount; i++) {
      manager.initController(reels[i].link);
    }
    logger.debug(
      'Background preload: $preloadCount reels queued',
      category: LogCategory.video,
    );
  }

  void _useBackgroundVideosPreload(
    AsyncValue<List<VideoFeedEntry>> videoFeed,
    YoutubePlayerManagerBase videoManager,
  ) {
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.microtask(() {
          try {
            final entries = videoFeed.valueOrNull;
            if (entries == null || entries.isEmpty) return;

            // Warm the first 1–2 videos so playback is instant when user enters the tab.
            videoManager.initController(entries.first.link);
            if (entries.length > 1) {
              videoManager.initController(entries[1].link);
            }
            logger.debug(
              'Background preload: First videos queued',
              category: LogCategory.video,
            );
          } catch (e, stack) {
            logger.warning(
              'Background videos preload failed',
              category: LogCategory.video,
              error: e,
              stackTrace: stack,
            );
          }
        });
      });
      return null;
    }, [videoFeed.hasValue]);
  }

  void _useVideoPauseOnNavigate(
    int currentIndex,
    YoutubePlayerManagerBase videoManager,
  ) {
    useEffect(() {
      final isOnVideoTab = currentIndex == 1 || currentIndex == 2;
      if (!isOnVideoTab) {
        // Pause all videos when leaving video tabs (don't release - let pool manager handle it)
        // This prevents audio leaks while keeping controllers warm for faster resume
        videoManager.pauseAll();
        logger.debug(
          'Paused all videos: user left video tabs (index=$currentIndex)',
          category: LogCategory.video,
        );
      }
      return null;
    }, [currentIndex]);
  }

  void _useLifecycleCleanup(YoutubePlayerManagerBase videoManager) {
    useEffect(() {
      // Cleanup callback when the shell page is disposed
      return () {
        logger.debug(
          'FeedShellPage disposing: pausing all video resources',
          category: LogCategory.lifecycle,
        );
        // Just pause - don't release. The ChangeNotifierProvider will dispose the manager
        // which will properly clean up controllers when the app is actually closing
        videoManager.pauseAll();
      };
    }, []);
  }

  void _usePageControllerSync(PageController controller, int currentIndex) {
    useEffect(() {
      if (controller.hasClients && controller.page?.round() != currentIndex) {
        controller.animateToPage(
          currentIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      return null;
    }, [currentIndex]);
  }

  Widget _buildBody({
    required PageController pageController,
    required ValueNotifier<int> currentIndex,
    required AsyncValue<List<ArticleFeedEntry>> articleFeed,
    required AsyncValue<List<VideoFeedEntry>> videoFeed,
    required WidgetRef ref,
  }) {
    final allTabs = [
      // Articles tab
      FeedTab<ArticleFeedEntry>(
        feed: articleFeed,
        emptyLabel: 'Articles are warming up.',
        builder: (entry) => ArticleCard(entry: entry),
        onRefresh: () => ref.refresh(paginatedFeedProvider),
        onLoadMore: () => ref.read(paginatedFeedProvider.notifier).loadMore(),
        onPageChanged: (index) =>
            ref.read(paginatedFeedProvider.notifier).setCurrentViewIndex(index),
      ),
      // Videos tab
      FeedTab<VideoFeedEntry>(
        feed: videoFeed,
        emptyLabel: 'Videos are warming up.',
        builder: (entry) => VideoCard(
          entry: entry,
          isVisible: currentIndex.value == 1,
        ),
        onRefresh: () => ref.refresh(paginatedFeedProvider),
        onLoadMore: () => ref.read(paginatedFeedProvider.notifier).loadMore(),
        onPageChanged: (index) =>
            ref.read(paginatedFeedProvider.notifier).setCurrentViewIndex(index),
      ),
      // Reels tab
      OptimizedReelsPage(isVisible: currentIndex.value == 2),
      // Chat tab
      const ChatPage(),
      // Settings tab
      const SettingsPage(),
    ];

    return PageView(
      controller: pageController,
      onPageChanged: (index) => currentIndex.value = index,
      children: allTabs,
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.currentIndex,
    required this.onIndexChanged,
  });

  final int currentIndex;
  final ValueChanged<int> onIndexChanged;

  @override
  Widget build(BuildContext context) {
    // viewPadding includes system navigation insets (works for all devices):
    // - iPhone home indicator
    // - Android gesture navigation
    // - Android 3-button navigation
    // - Tablets and foldables
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      color: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
      // Add safe area padding below the nav content
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        // Use design system constant for nav height
        height: AppSizes.bottomNavHeight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            NavBarIcon(
              icon: Icons.article_outlined,
              selectedIcon: Icons.article,
              label: 'Feed',
              isSelected: currentIndex == 0,
              onTap: () => onIndexChanged(0),
            ),
            NavBarIcon(
              icon: Icons.play_circle_outline,
              selectedIcon: Icons.play_circle,
              label: 'Videos',
              isSelected: currentIndex == 1,
              onTap: () => onIndexChanged(1),
            ),
            NavBarIcon(
              icon: Icons.movie_filter_outlined,
              selectedIcon: Icons.movie_filter,
              label: 'Reels',
              isSelected: currentIndex == 2,
              onTap: () => onIndexChanged(2),
            ),
            NavBarIcon(
              icon: Icons.chat_bubble_outline,
              selectedIcon: Icons.chat_bubble,
              label: 'Chat',
              isSelected: currentIndex == 3,
              onTap: () => onIndexChanged(3),
            ),
            NavBarIcon(
              icon: Icons.settings_outlined,
              selectedIcon: Icons.settings,
              label: 'Settings',
              isSelected: currentIndex == 4,
              onTap: () => onIndexChanged(4),
            ),
          ],
        ),
      ),
    );
  }
}
