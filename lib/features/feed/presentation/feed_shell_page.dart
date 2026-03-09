import 'package:blips_mobile/core/error/error.dart';
import 'package:blips_mobile/core/error/error_boundary.dart';
import 'package:blips_mobile/core/network/offline_banner.dart';
import 'package:blips_mobile/core/theme/theme.dart';
import 'package:blips_mobile/features/ads/domain/ad_entry.dart';
import 'package:blips_mobile/features/ads/presentation/ad_card.dart';
import 'package:blips_mobile/features/chat/presentation/chat_page.dart';
import 'package:blips_mobile/features/chat/providers/chat_providers.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/presentation/cards/cards.dart';
import 'package:blips_mobile/features/feed/presentation/reels/reels.dart';
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
    final articleFeed = ref.watch(articleFeedWithAdsProvider);
    final videoFeed = ref.watch(videoFeedWithAdsProvider);
    final videoManager = ref.watch(youtubePlayerManagerProvider);

    // Warm reels data in background (controller warm-up is owned by Reels page).
    _useBackgroundReelsWarmup(ref);

    // Pause videos when navigating away from video tabs
    _useVideoPauseOnNavigate(currentIndex.value, videoManager);

    // Cleanup all video resources when shell page is disposed
    _useLifecycleCleanup(videoManager);

    // Sync page controller with bottom nav
    _usePageControllerSync(pageController, currentIndex.value);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: Stack(
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
          ),
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

  void _useBackgroundReelsWarmup(WidgetRef ref) {
    useEffect(() {
      var mounted = true;
      // Defer reels feed warm-up until after first frame to avoid blocking UI.
      // Reels controller warm-up runs only in OptimizedReelsPage so there is a
      // single owner for player lifecycle and pool pressure.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.microtask(() async {
          try {
            // Start provider load eagerly for better first-open latency.
            final reelsAsync = ref.read(reelsFeedProvider);
            reelsAsync.maybeWhen(
              data: (_) => null,
              orElse: () {
                // If loading/error, wait a bit then check again
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (!mounted) return;
                  ref.read(reelsFeedProvider);
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
      return () => mounted = false;
    }, []);
  }

  void _useVideoPauseOnNavigate(
    int currentIndex,
    YoutubePlayerManagerBase videoManager,
  ) {
    // useRef persists a flag across rebuilds without triggering a rebuild.
    // We skip the very first run so that mounting the shell (currentIndex=0)
    // does not call pauseAll() and wipe _currentActiveUrl before preloads land.
    final hasMounted = useRef(false);
    useEffect(() {
      if (!hasMounted.value) {
        hasMounted.value = true;
        return null;
      }
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
    required AsyncValue<List<FeedEntry>> articleFeed,
    required AsyncValue<List<FeedEntry>> videoFeed,
    required WidgetRef ref,
  }) {
    final allTabs = [
      // Articles tab (may contain interleaved ad entries)
      FeedTab<FeedEntry>(
        feed: articleFeed,
        emptyLabel: 'Articles are warming up.',
        builder: (entry, isCurrentPage) {
          final feedNotifier = ref.read(paginatedFeedProvider.notifier);
          if (entry is AdFeedEntry) return AdCard(entry: entry);
          return ArticleCard(
            entry: entry as ArticleFeedEntry,
            isVisible: currentIndex.value == 0 && isCurrentPage,
            isNewSinceLastSeen: feedNotifier.isEntryNewSinceLastSeen(entry.id),
          );
        },
        onRefresh: () => ref.refresh(paginatedFeedProvider),
        onLoadMore: () => ref.read(paginatedFeedProvider.notifier).loadMore(),
        onPageChanged: (index) =>
            ref.read(paginatedFeedProvider.notifier).setCurrentViewIndex(index),
      ),
      // Videos tab (may contain interleaved ad entries)
      FeedTab<FeedEntry>(
        feed: videoFeed,
        emptyLabel: 'Videos are warming up.',
        containsVideos: true,
        builder: (entry, isCurrentPage) {
          final feedNotifier = ref.read(paginatedFeedProvider.notifier);
          if (entry is AdFeedEntry) return AdCard(entry: entry);
          return VideoCard(
            entry: entry as VideoFeedEntry,
            isVisible: currentIndex.value == 1 && isCurrentPage,
            isNewSinceLastSeen: feedNotifier.isEntryNewSinceLastSeen(entry.id),
          );
        },
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
      children: allTabs
          .map((tab) => _KeepAliveWrapper(child: ErrorBoundary(child: tab)))
          .toList(),
    );
  }
}

/// Wraps a widget with [AutomaticKeepAliveClientMixin] so that [PageView]
/// keeps it alive even when scrolled off-screen.
///
/// Without this, swiping between tabs would destroy each tab's widget tree
/// (including its [PageController]), resetting scroll position to 0.
class _KeepAliveWrapper extends StatefulWidget {
  const _KeepAliveWrapper({required this.child});

  final Widget child;

  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
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
    final navColor = Theme.of(context).bottomNavigationBarTheme.backgroundColor;
    final scaffoldColor = Theme.of(context).scaffoldBackgroundColor;

    // Two-layer nav bar: icon row uses nav color, safe zone below uses
    // scaffold background — this makes the home indicator gap invisible,
    // matching how Inshorts and other native apps handle this area.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: navColor,
          child: SizedBox(
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
        ),
        // Safe zone — scaffold background so it blends with the phone bezel,
        // making the home indicator gap visually invisible (same as Inshorts).
        Container(color: scaffoldColor, height: bottomInset),
      ],
    );
  }
}
