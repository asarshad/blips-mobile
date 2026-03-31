import 'dart:async';

import 'package:blips_mobile/core/config/memory_config.dart';
import 'package:blips_mobile/core/diagnostics/app_diagnostics.dart';
import 'package:blips_mobile/core/error/error.dart';
import 'package:blips_mobile/core/network/offline_banner.dart';
import 'package:blips_mobile/core/theme/theme.dart';
import 'package:blips_mobile/features/ads/domain/feed_page_item.dart';
import 'package:blips_mobile/features/ads/presentation/native_ad_card.dart';
import 'package:blips_mobile/features/ads/providers/ads_providers.dart';
import 'package:blips_mobile/features/feed/data/feed_repository.dart';
import 'package:blips_mobile/features/feed/data/feed_session_store.dart';
import 'package:blips_mobile/features/ads/presentation/ad_card.dart';
import 'package:blips_mobile/features/chat/presentation/chat_page.dart';
import 'package:blips_mobile/features/chat/providers/chat_providers.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/presentation/cards/cards.dart';
import 'package:blips_mobile/features/feed/presentation/reels/reels.dart';
import 'package:blips_mobile/features/feed/presentation/saved/saved_items_page.dart';
import 'package:blips_mobile/features/feed/presentation/tabs/tabs.dart';
import 'package:blips_mobile/features/feed/presentation/widgets/widgets.dart';
import 'package:blips_mobile/features/feed/providers/feed_providers.dart';
import 'package:blips_mobile/features/feed/providers/video/playback_rearm.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager_base.dart';
import 'package:blips_mobile/features/notifications/data/push_notifications_controller.dart';
import 'package:blips_mobile/features/notifications/domain/notification_target.dart';
import 'package:blips_mobile/features/notifications/providers/push_notification_providers.dart';
import 'package:blips_mobile/features/settings/presentation/settings_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Root shell page that hosts all main app tabs.
///
/// Contains:
/// - Articles feed (index 0)
/// - Videos feed (index 1)
/// - Reels feed (index 2)
/// - Chat (index 3)
/// - Saved (index 4)
/// - Settings (index 5)
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
    final sessionStore = ref.watch(feedSessionStoreProvider);

    // Vertical page controllers for each feed surface
    final articleFeedController = usePageController();
    final videoFeedController = usePageController();
    final reelsFeedController = usePageController();

    // Watch providers for current view
    final articleFeed = ref.watch(articleFeedWithAdsProvider);
    final videoFeed = ref.watch(videoFeedWithAdsProvider);
    final videoManager = ref.watch(youtubePlayerManagerProvider);
    final articleUiState =
        ref.watch(feedSurfaceUiStateProvider(FeedSurface.articles));
    final videoUiState =
        ref.watch(feedSurfaceUiStateProvider(FeedSurface.videos));
    final pushController = ref.watch(pushNotificationsControllerProvider);

    ref.listen<NotificationTarget?>(pendingNotificationTargetProvider,
        (previous, next) {
      if (next == null || next == previous) return;
      Future.microtask(() async {
        final handled = await _handleNotificationTarget(
          target: next,
          ref: ref,
          currentIndex: currentIndex,
        );
        if (!handled) {
          logger.info(
            'Notification target fell back to surface head',
            category: LogCategory.lifecycle,
          );
        }
        pushController.consumePendingTarget(next);
      });
    });

    ref.listen<FeedSurfaceUiState>(
      feedSurfaceUiStateProvider(FeedSurface.articles),
      (_, next) {
        final message = next.unavailableTargetMessage;
        if (message == null || !context.mounted) return;
        _showInfoSnackbar(context, message);
        ref.read(articlesFeedProvider.notifier).clearUnavailableTargetMessage();
      },
    );
    ref.listen<FeedSurfaceUiState>(
      feedSurfaceUiStateProvider(FeedSurface.videos),
      (_, next) {
        final message = next.unavailableTargetMessage;
        if (message == null || !context.mounted) return;
        _showInfoSnackbar(context, message);
        ref.read(videosFeedProvider.notifier).clearUnavailableTargetMessage();
      },
    );

    // Warm reels data in background (controller warm-up is owned by Reels page).
    _useBackgroundReelsWarmup(ref);

    // Pause videos when navigating away from video tabs
    _useVideoPauseOnNavigate(currentIndex.value, videoManager);

    // Cleanup all video resources when shell page is disposed
    _useLifecycleCleanup(videoManager);

    // Sync page controller with bottom nav
    _usePageControllerSync(pageController, currentIndex.value);

    // Refresh the current surface when the app returns to foreground.
    _useResumeRefresh(ref, currentIndex.value, pushController);

    useEffect(() {
      unawaited(pushController.ensureStarted());
      unawaited(pushController.onEligibleShellEntered());
      return null;
    }, const []);

    useEffect(() {
      Future.microtask(() async {
        final lastSurface = await sessionStore.getLastSurface();
        if (lastSurface != null && currentIndex.value != lastSurface.tabIndex) {
          currentIndex.value = lastSurface.tabIndex;
        }
      });
      return null;
    }, const []);

    useEffect(() {
      if (currentIndex.value >= 0 && currentIndex.value <= 2) {
        final surface = FeedSurface.values[currentIndex.value];
        Future.microtask(() => sessionStore.setLastSurface(surface));
      }
      return null;
    }, [currentIndex.value]);

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
                  articleFeedController: articleFeedController,
                  videoFeedController: videoFeedController,
                  reelsFeedController: reelsFeedController,
                  articleUiState: articleUiState,
                  videoUiState: videoUiState,
                  ref: ref,
                  context: context,
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
          final isRetap = currentIndex.value == index;
          if (isRetap) {
            _refreshTabOnRetap(
              index,
              ref,
              context,
              articleFeedController,
              videoFeedController,
              reelsFeedController,
            );
            return;
          }
          _handleTabEntry(index, ref, currentIndex);
        },
      ),
    );
  }

  void _handleTabEntry(
    int index,
    WidgetRef ref,
    ValueNotifier<int> currentIndex,
  ) {
    final previousIndex = currentIndex.value;
    if (previousIndex == index) {
      return;
    }

    currentIndex.value = index;

    if (index == 3) {
      ref.invalidate(chatListProvider);
      return;
    }

    final diagnostics = ref.read(appDiagnosticsProvider);
    final surface = switch (index) {
      0 => 'articles',
      1 => 'videos',
      2 => 'reels',
      _ => null,
    };
    if (surface == null) {
      return;
    }

    diagnostics.record(
      scope: 'feed.shell',
      action: 'tabEntryRefresh',
      stage: 'start',
      surface: surface,
      data: <String, Object?>{
        'fromIndex': previousIndex,
        'toIndex': index,
      },
    );

    switch (index) {
      case 0:
        unawaited(ref.read(articlesFeedProvider.notifier).refreshSilently());
        break;
      case 1:
        unawaited(ref.read(videosFeedProvider.notifier).refreshSilently());
        break;
      case 2:
        unawaited(ref.read(reelsFeedProvider.notifier).refreshSilently());
        break;
      case 3:
      case 4:
      case 5:
        break;
    }
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

  void _useResumeRefresh(
    WidgetRef ref,
    int currentIndex,
    PushNotificationsController pushController,
  ) {
    final lastRefreshAt = useRef<DateTime?>(null);
    useEffect(() {
      final listener = AppLifecycleListener(
        onResume: () {
          final diagnostics = ref.read(appDiagnosticsProvider);
          final now = DateTime.now();
          final last = lastRefreshAt.value;
          if (last != null &&
              now.difference(last) < const Duration(seconds: 45)) {
            diagnostics.record(
              scope: 'feed.shell',
              action: 'resumeRefresh',
              stage: 'skipped',
              level: AppDiagnosticsLevel.info,
              data: <String, Object?>{
                'currentIndex': currentIndex,
                'reason': 'cooldown',
              },
            );
            return;
          }
          lastRefreshAt.value = now;

          if (ref.read(appConfigRepositoryProvider).isCacheStale) {
            ref.invalidate(remoteAppConfigProvider);
          }
          unawaited(pushController.handleAppResume());

          diagnostics.record(
            scope: 'feed.shell',
            action: 'resumeRefresh',
            stage: 'start',
            surface: switch (currentIndex) {
              0 => 'articles',
              1 => 'videos',
              2 => 'reels',
              _ => null,
            },
            data: <String, Object?>{'currentIndex': currentIndex},
          );

          switch (currentIndex) {
            case 0:
              unawaited(
                  ref.read(articlesFeedProvider.notifier).refreshSilently());
              break;
            case 1:
              unawaited(
                  ref.read(videosFeedProvider.notifier).refreshSilently());
              break;
            case 2:
              unawaited(ref.read(reelsFeedProvider.notifier).refreshSilently());
              break;
          }
        },
      );
      return listener.dispose;
    }, [currentIndex]);
  }

  Future<bool> _handleNotificationTarget({
    required NotificationTarget target,
    required WidgetRef ref,
    required ValueNotifier<int> currentIndex,
  }) async {
    currentIndex.value = target.surface.tabIndex;

    switch (target.surface) {
      case NotificationSurface.articles:
        return ref
            .read(articlesFeedProvider.notifier)
            .ensureNotificationTargetLoaded(target.contentId);
      case NotificationSurface.videos:
        return ref
            .read(videosFeedProvider.notifier)
            .ensureNotificationTargetLoaded(target.contentId);
    }
  }

  void _refreshTabOnRetap(
    int index,
    WidgetRef ref,
    BuildContext context,
    PageController articleFeedController,
    PageController videoFeedController,
    PageController reelsFeedController,
  ) {
    switch (index) {
      case 0:
        _showRetapRefreshFeedback(context, index);
        _refreshArticlesManually(
          ref,
          context,
          articleFeedController,
          fromTabRetap: true,
        );
        break;
      case 1:
        _showRetapRefreshFeedback(context, index);
        _refreshVideosManually(
          ref,
          context,
          videoFeedController,
          fromTabRetap: true,
        );
        break;
      case 2:
        _showRetapRefreshFeedback(context, index);
        _refreshReelsManually(
          ref,
          context,
          reelsFeedController,
          fromTabRetap: true,
        );
        break;
      case 3:
        _showRetapRefreshFeedback(context, index);
        ref.invalidate(chatListProvider);
        break;
      case 4:
        // No-op for saved.
        break;
      case 5:
        // No-op for settings.
        break;
    }
  }

  void _refreshArticlesManually(
    WidgetRef ref,
    BuildContext context,
    PageController controller, {
    bool fromNewItems = false,
    bool fromTabRetap = false,
  }) {
    final diagnostics = ref.read(appDiagnosticsProvider);
    final span = diagnostics.startSpan(
      scope: 'feed.shell',
      action: 'manualRefresh',
      surface: 'articles',
      data: <String, Object?>{
        'trigger': fromNewItems
            ? 'newContentPill'
            : (fromTabRetap ? 'tabRetap' : 'manualRefresh'),
      },
    );
    final notifier = ref.read(articlesFeedProvider.notifier);
    unawaited(
      (fromNewItems
              ? notifier.openPendingNewContent()
              : (fromTabRetap
                  ? notifier.refreshForRetap()
                  : notifier.manualRefresh()))
          .then((ok) async {
        if (fromTabRetap) {
          if (ok) {
            if (_isControllerAtTop(controller)) {
              await _rearmFirstReelPlayback(ref);
            }
            span.success(data: <String, Object?>{'jumpedToTop': false});
          } else {
            span.step(
              'uiFailure',
              level: AppDiagnosticsLevel.warning,
              message: 'Showing retry snackbar',
            );
            _showRetrySnackbar(context, 'Articles refresh failed.', () {
              _refreshArticlesManually(
                ref,
                context,
                controller,
                fromTabRetap: true,
              );
            });
          }
          return;
        }
        if (ok && controller.hasClients) {
          span.success(data: <String, Object?>{'jumpedToTop': true});
          await _animateFeedToTop(controller);
          await _rearmFirstReelPlayback(ref);
        } else if (!ok) {
          span.step(
            'uiFailure',
            level: AppDiagnosticsLevel.warning,
            message: 'Showing retry snackbar',
          );
          _showRetrySnackbar(context, 'Articles refresh failed.', () {
            _refreshArticlesManually(ref, context, controller);
          });
        } else {
          span.success(data: <String, Object?>{'jumpedToTop': false});
        }
      }).catchError((Object error, StackTrace stackTrace) {
        span.failure(error, stackTrace: stackTrace);
      }),
    );
  }

  void _refreshVideosManually(
    WidgetRef ref,
    BuildContext context,
    PageController controller, {
    bool fromNewItems = false,
    bool fromTabRetap = false,
  }) {
    final diagnostics = ref.read(appDiagnosticsProvider);
    final span = diagnostics.startSpan(
      scope: 'feed.shell',
      action: 'manualRefresh',
      surface: 'videos',
      data: <String, Object?>{
        'trigger': fromNewItems
            ? 'newContentPill'
            : (fromTabRetap ? 'tabRetap' : 'manualRefresh'),
      },
    );
    final notifier = ref.read(videosFeedProvider.notifier);
    unawaited(
      (fromNewItems
              ? notifier.openPendingNewContent()
              : (fromTabRetap
                  ? notifier.refreshForRetap()
                  : notifier.manualRefresh()))
          .then((ok) async {
        if (fromTabRetap) {
          if (ok) {
            if (_isControllerAtTop(controller)) {
              await _rearmFirstVideoPlayback(ref);
            }
            span.success(data: <String, Object?>{'jumpedToTop': false});
          } else {
            span.step(
              'uiFailure',
              level: AppDiagnosticsLevel.warning,
              message: 'Showing retry snackbar',
            );
            _showRetrySnackbar(context, 'Videos refresh failed.', () {
              _refreshVideosManually(
                ref,
                context,
                controller,
                fromTabRetap: true,
              );
            });
          }
          return;
        }
        if (ok && controller.hasClients) {
          span.success(data: <String, Object?>{'jumpedToTop': true});
          await _animateFeedToTop(controller);
          await _rearmFirstVideoPlayback(ref);
        } else if (!ok) {
          span.step(
            'uiFailure',
            level: AppDiagnosticsLevel.warning,
            message: 'Showing retry snackbar',
          );
          _showRetrySnackbar(context, 'Videos refresh failed.', () {
            _refreshVideosManually(ref, context, controller);
          });
        } else {
          span.success(data: <String, Object?>{'jumpedToTop': false});
        }
      }).catchError((Object error, StackTrace stackTrace) {
        span.failure(error, stackTrace: stackTrace);
      }),
    );
  }

  void _refreshReelsManually(
    WidgetRef ref,
    BuildContext context,
    PageController controller, {
    bool fromNewItems = false,
    bool fromTabRetap = false,
  }) {
    final diagnostics = ref.read(appDiagnosticsProvider);
    final span = diagnostics.startSpan(
      scope: 'feed.shell',
      action: 'manualRefresh',
      surface: 'reels',
      data: <String, Object?>{
        'trigger': fromNewItems
            ? 'newContentPill'
            : (fromTabRetap ? 'tabRetap' : 'manualRefresh'),
      },
    );
    final notifier = ref.read(reelsFeedProvider.notifier);
    unawaited(
      (fromNewItems
              ? notifier.openPendingNewContent()
              : (fromTabRetap
                  ? notifier.refreshForRetap()
                  : notifier.manualRefresh()))
          .then((ok) async {
        if (fromTabRetap) {
          if (ok) {
            span.success(data: <String, Object?>{'jumpedToTop': false});
          } else {
            span.step(
              'uiFailure',
              level: AppDiagnosticsLevel.warning,
              message: 'Showing retry snackbar',
            );
            _showRetrySnackbar(context, 'Reels refresh failed.', () {
              _refreshReelsManually(
                ref,
                context,
                controller,
                fromTabRetap: true,
              );
            });
          }
          return;
        }
        if (ok && controller.hasClients) {
          span.success(data: <String, Object?>{'jumpedToTop': true});
          await _animateFeedToTop(controller);
        } else if (!ok) {
          span.step(
            'uiFailure',
            level: AppDiagnosticsLevel.warning,
            message: 'Showing retry snackbar',
          );
          _showRetrySnackbar(context, 'Reels refresh failed.', () {
            _refreshReelsManually(ref, context, controller);
          });
        } else {
          span.success(data: <String, Object?>{'jumpedToTop': false});
        }
      }).catchError((Object error, StackTrace stackTrace) {
        span.failure(error, stackTrace: stackTrace);
      }),
    );
  }

  Future<void> _animateFeedToTop(PageController controller) async {
    await controller.animateToPage(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
    if (!controller.hasClients) return;
    final page = controller.page;
    if (page == null || (page - 0).abs() <= 0.001) {
      return;
    }
    controller.jumpToPage(0);
  }

  bool _isControllerAtTop(PageController controller) {
    if (!controller.hasClients) return true;
    final page = controller.page;
    if (page == null) return controller.initialPage == 0;
    return (page - 0).abs() <= 0.001;
  }

  Future<void> _rearmFirstVideoPlayback(WidgetRef ref) async {
    final entries = ref.read(videosFeedProvider).valueOrNull;
    if (entries == null || entries.isEmpty) return;

    final videoManager = ref.read(youtubePlayerManagerProvider);
    final urls = entries
        .map((entry) => _resolveVideoPlaybackUrl(entry, videoManager))
        .where((url) => url.isNotEmpty)
        .toList(growable: false);
    if (urls.isEmpty) return;

    final firstUrl = urls.first;
    videoManager.onPageChanged(
      currentIndex: 0,
      videoUrls: urls,
      preloadAhead: MemoryConfig.videoPreloadCount,
    );
    if (videoManager.getState(firstUrl) != YTPlayerState.loading) {
      await nudgePrimaryPlayback(videoManager, firstUrl);
    }
  }

  Future<void> _rearmFirstReelPlayback(WidgetRef ref) async {
    final entries = ref.read(reelsFeedProvider).valueOrNull;
    if (entries == null || entries.isEmpty) return;

    final videoManager = ref.read(youtubePlayerManagerProvider);
    final urls = entries.map((entry) => entry.link).toList(growable: false);
    final firstUrl = urls.first;
    videoManager.onPageChanged(
      currentIndex: 0,
      videoUrls: urls,
      preloadAhead: MemoryConfig.reelPreloadCount,
    );
    if (videoManager.getState(firstUrl) != YTPlayerState.loading) {
      await nudgePrimaryPlayback(videoManager, firstUrl);
    }
  }

  String _resolveVideoPlaybackUrl(
    VideoFeedEntry entry,
    YoutubePlayerManagerBase videoManager,
  ) {
    final preferred = entry.videoUrl.trim();
    if (preferred.isNotEmpty &&
        videoManager.extractVideoId(preferred) != null) {
      return preferred;
    }
    return entry.link.trim();
  }

  void _showRetrySnackbar(
      BuildContext context, String message, VoidCallback onRetry) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(label: 'Retry', onPressed: onRetry),
          duration: const Duration(seconds: 4),
        ),
      );
  }

  void _showInfoSnackbar(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  void _showRetapRefreshFeedback(BuildContext context, int index) {
    final message = switch (index) {
      0 => 'Refreshing feed...',
      1 => 'Refreshing videos...',
      2 => 'Refreshing reels...',
      3 => 'Refreshing chat...',
      _ => null,
    };
    if (message == null) return;
    HapticFeedback.selectionClick();
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 900),
        ),
      );
  }

  Widget _buildBody({
    required PageController pageController,
    required ValueNotifier<int> currentIndex,
    required AsyncValue<List<FeedPageItem>> articleFeed,
    required AsyncValue<List<FeedPageItem>> videoFeed,
    required PageController articleFeedController,
    required PageController videoFeedController,
    required PageController reelsFeedController,
    required FeedSurfaceUiState articleUiState,
    required FeedSurfaceUiState videoUiState,
    required WidgetRef ref,
    required BuildContext context,
  }) {
    final allTabs = [
      FeedTab<FeedPageItem>(
        feed: articleFeed,
        emptyLabel: 'Articles are warming up.',
        overlayLabel: 'ART',
        overlayHasMore: ref.read(articlesFeedProvider.notifier).hasMore,
        controller: articleFeedController,
        builder: (entry, isCurrentPage) {
          final notifier = ref.read(articlesFeedProvider.notifier);
          if (entry is NativeAdSlotFeedPageItem) {
            return NativeAdCard(slot: entry);
          }
          if (entry is SponsorCardFeedPageItem) {
            return AdCard(entry: entry.entry);
          }
          final organicEntry = entry.organicEntry;
          if (organicEntry is! ArticleFeedEntry) {
            return const SizedBox.shrink();
          }
          return ArticleCard(
            entry: organicEntry,
            isVisible: currentIndex.value == 0 && isCurrentPage,
            isNewSinceLastSeen:
                notifier.isEntryNewSinceLastSeen(organicEntry.id),
          );
        },
        onRefresh: () =>
            _refreshArticlesManually(ref, context, articleFeedController),
        onLoadMore: () => ref.read(articlesFeedProvider.notifier).loadMore(),
        onPageChanged: (index, entry) => ref
            .read(articlesFeedProvider.notifier)
            .setCurrentViewPosition(index, entry as ArticleFeedEntry?),
        onPrimaryVisibleEntrySettled: (entry) => unawaited(
          ref.read(articlesFeedProvider.notifier).markExposed(entry.id),
        ),
        isActive: currentIndex.value == 0,
        restoreEntryId: articleUiState.restoreItemId,
        restoreApproximateIndex: articleUiState.restoreApproximateIndex,
        onRestoreApplied:
            ref.read(articlesFeedProvider.notifier).consumeRestoreTarget,
        topActionLabel: articleUiState.pendingActionLabel,
        onTopAction: articleUiState.hasPendingAction
            ? () => _refreshArticlesManually(
                  ref,
                  context,
                  articleFeedController,
                  fromNewItems: true,
                )
            : null,
      ),
      FeedTab<FeedPageItem>(
        feed: videoFeed,
        emptyLabel: 'Videos are warming up.',
        overlayLabel: 'VID',
        overlayHasMore: ref.read(videosFeedProvider.notifier).hasMore,
        containsVideos: true,
        controller: videoFeedController,
        builder: (entry, isCurrentPage) {
          final notifier = ref.read(videosFeedProvider.notifier);
          if (entry is NativeAdSlotFeedPageItem) {
            return NativeAdCard(slot: entry);
          }
          if (entry is SponsorCardFeedPageItem) {
            return AdCard(entry: entry.entry);
          }
          final organicEntry = entry.organicEntry;
          if (organicEntry is! VideoFeedEntry) {
            return const SizedBox.shrink();
          }
          return VideoCard(
            entry: organicEntry,
            isVisible: currentIndex.value == 1 && isCurrentPage,
            isNewSinceLastSeen:
                notifier.isEntryNewSinceLastSeen(organicEntry.id),
          );
        },
        onRefresh: () =>
            _refreshVideosManually(ref, context, videoFeedController),
        onLoadMore: () => ref.read(videosFeedProvider.notifier).loadMore(),
        onPageChanged: (index, entry) => ref
            .read(videosFeedProvider.notifier)
            .setCurrentViewPosition(index, entry as VideoFeedEntry?),
        onPrimaryVisibleEntrySettled: (entry) => unawaited(
          ref.read(videosFeedProvider.notifier).markExposed(entry.id),
        ),
        isActive: currentIndex.value == 1,
        restoreEntryId: videoUiState.restoreItemId,
        restoreApproximateIndex: videoUiState.restoreApproximateIndex,
        onRestoreApplied:
            ref.read(videosFeedProvider.notifier).consumeRestoreTarget,
        topActionLabel: videoUiState.pendingActionLabel,
        onTopAction: videoUiState.hasPendingAction
            ? () => _refreshVideosManually(
                  ref,
                  context,
                  videoFeedController,
                  fromNewItems: true,
                )
            : null,
        isCaughtUp: ref.read(videosFeedProvider.notifier).isCaughtUp,
        caughtUpLabel: 'Caught up on videos for now.',
        onCaughtUp: (entry) => unawaited(
          ref.read(feedRepositoryProvider).recordInteraction(
            contentItemId: entry.id,
            eventType: FeedInteractionEvent.caughtUp,
            extraData: const {
              'surface': 'videos',
            },
          ),
        ),
      ),
      // Reels tab
      OptimizedReelsPage(
        isVisible: currentIndex.value == 2,
        controller: reelsFeedController,
        onManualRefresh: () => _refreshReelsManually(
          ref,
          context,
          reelsFeedController,
          fromNewItems: ref
              .read(feedSurfaceUiStateProvider(FeedSurface.reels))
              .hasPendingAction,
        ),
      ),
      // Chat tab
      const ChatPage(),
      // Saved tab
      const SavedItemsPage(),
      // Settings tab
      const SettingsPage(),
    ];

    return PageView(
      controller: pageController,
      onPageChanged: (index) => _handleTabEntry(index, ref, currentIndex),
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
    final isAndroidUi =
        !kIsWeb && Theme.of(context).platform == TargetPlatform.android;
    final navHeight = isAndroidUi ? 56.0 : AppSizes.bottomNavHeight;

    // Two-layer nav bar: icon row uses nav color, safe zone below uses
    // scaffold background — this makes the home indicator gap invisible,
    // matching how Inshorts and other native apps handle this area.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: navColor,
          child: SizedBox(
            height: navHeight,
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
                  icon: Icons.bookmark_border_rounded,
                  selectedIcon: Icons.bookmark_rounded,
                  label: 'Saved',
                  isSelected: currentIndex == 4,
                  onTap: () => onIndexChanged(4),
                ),
                NavBarIcon(
                  icon: Icons.settings_outlined,
                  selectedIcon: Icons.settings,
                  label: 'Settings',
                  isSelected: currentIndex == 5,
                  onTap: () => onIndexChanged(5),
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
