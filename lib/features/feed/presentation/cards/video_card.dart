import 'dart:async';

import 'package:blips_mobile/core/error/error.dart';
import 'package:blips_mobile/features/feed/data/feed_repository.dart';
import 'package:blips_mobile/features/feed/data/feed_session_store.dart';
import 'package:blips_mobile/features/feed/domain/external_video_url.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/presentation/widgets/widgets.dart';
import 'package:blips_mobile/features/feed/providers/blocked_sources_provider.dart';
import 'package:blips_mobile/features/feed/providers/feed_providers.dart';
import 'package:blips_mobile/features/feed/providers/saved_items_providers.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager_base.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

/// Fallback image when video thumbnail is unavailable.
const _videoFallbackImage =
    'https://images.unsplash.com/photo-1504384308090-c894fdcc538d?w=800';

enum _VideoCardAction { lessFromCreator, report }

/// Card widget for displaying video feed entries.
/// Includes inline video playback with thumbnail fallback.
class VideoCard extends HookConsumerWidget {
  const VideoCard({
    super.key,
    required this.entry,
    this.isVisible = true,
    this.isNewSinceLastSeen = false,
  });

  final VideoFeedEntry entry;
  final bool isVisible;
  final bool isNewSinceLastSeen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showBubbles = useState(false);
    final preview = entry.thumbnailUrl ?? _videoFallbackImage;

    final feedRepository = ref.read(feedRepositoryProvider);
    final sessionStore = ref.read(feedSessionStoreProvider);
    final videoManager = ref.watch(youtubePlayerManagerProvider);
    final isSaved = ref.watch(savedVideoIdsProvider).contains(entry.id);
    // When a share sheet is in flight, iOS doesn't block taps on the
    // exposed area above the page sheet. Absorb any leaked taps /
    // long-presses so the underlying card can't fire play/pause, open
    // actions menus, or open the browser behind the share sheet.
    final isSharing = useValueListenable(ShareService.instance.isSharing);
    final playbackUrl = _resolvePlaybackUrl(videoManager);
    final controller = videoManager.getController(playbackUrl);
    final playerState = videoManager.getState(playbackUrl);
    final overlayState = videoManager.getPlaybackOverlayState(playbackUrl);
    final playerError = videoManager.getError(playbackUrl);
    final sentImpression = useRef(false);
    final sentStart = useRef(false);
    final sent3s = useRef(false);
    final sent50Pct = useRef(false);
    final sent95Pct = useRef(false);
    final sentSkip = useRef(false);
    final startedAt = useRef<DateTime?>(null);
    final lastPositionMs = useRef(0);
    final resumeRecoveryArmed = useRef(false);

    final watchLabel = _buildWatchLabel(
      controller: controller,
      explicitDurationSeconds: entry.durationSeconds,
    );

    // Resume video when app returns to foreground (Videos tab lifecycle fix).
    // The manager's WidgetsBindingObserver handles pause-on-background but
    // resume must be triggered per-card since only this widget knows whether
    // it is the currently visible page.
    useEffect(() {
      if (!isVisible) return null;
      final listener = AppLifecycleListener(
        onInactive: () => resumeRecoveryArmed.value = true,
        onPause: () => resumeRecoveryArmed.value = true,
        onDetach: () => resumeRecoveryArmed.value = true,
        onResume: () {
          if (!resumeRecoveryArmed.value) return;
          resumeRecoveryArmed.value = false;
          unawaited(videoManager.ensurePlayback(playbackUrl));
        },
      );
      return listener.dispose;
    }, [isVisible, playbackUrl]);

    // Handle visibility changes
    useEffect(() {
      if (!isVisible) {
        _recordEarlySkipIfNeeded(
          repository: feedRepository,
          sentStart: sentStart.value,
          sentSkip: sentSkip.value,
          startedAt: startedAt.value,
          positionMs: lastPositionMs.value,
        ).then((didRecord) {
          if (didRecord) {
            sentSkip.value = true;
          }
        });
        videoManager.pauseVideo(playbackUrl);
        showBubbles.value = false;
      } else {
        // Self-arm playback when this card becomes visible. FeedTab is the
        // primary owner via onPageChanged, but that path can be missed when
        // navigating from a push notification or restoring scroll position.
        final state = videoManager.getState(playbackUrl);
        if (state == YTPlayerState.idle ||
            state == YTPlayerState.paused ||
            state == YTPlayerState.ready) {
          unawaited(videoManager.ensurePlayback(playbackUrl));
        }
      }
      return null;
    }, [isVisible, playbackUrl]);

    useEffect(() {
      if (isVisible && !sentImpression.value) {
        sentImpression.value = true;
        unawaited(
          feedRepository.recordInteraction(
            contentItemId: entry.id,
            eventType: FeedInteractionEvent.videoImpression,
            extraData: const {'surface': 'videos'},
          ),
        );
      }
      return null;
    }, [isVisible]);

    useEffect(() {
      void handleProgress() {
        if (!isVisible) return;

        final controllerState = controller?.value.playerState;
        final isPlaying = controllerState == PlayerState.playing ||
            playerState == YTPlayerState.playing;
        if (controller != null) {
          lastPositionMs.value = controller.value.position.inMilliseconds;
        }

        if (isPlaying && !sentStart.value) {
          sentStart.value = true;
          startedAt.value = DateTime.now();
          unawaited(
            feedRepository.recordInteraction(
              contentItemId: entry.id,
              eventType: FeedInteractionEvent.videoStart,
              extraData: const {'surface': 'videos'},
            ),
          );
        }

        if (!isPlaying) {
          return;
        }

        final positionMs = lastPositionMs.value;
        final durationMs = _resolveDurationMs(
          controller: controller,
          explicitDurationSeconds: entry.durationSeconds,
          fallbackMinutes: entry.readTime,
        );

        if (!sent3s.value && positionMs >= 3000) {
          sent3s.value = true;
          unawaited(
            feedRepository.recordInteraction(
              contentItemId: entry.id,
              eventType: FeedInteractionEvent.video3s,
              extraData: const {'surface': 'videos'},
            ),
          );
        }
        if (durationMs <= 0) {
          return;
        }

        final ratio = positionMs / durationMs;
        if (!sent50Pct.value && ratio >= 0.5) {
          sent50Pct.value = true;
          unawaited(
            feedRepository.recordInteraction(
              contentItemId: entry.id,
              eventType: FeedInteractionEvent.video50pct,
              extraData: const {'surface': 'videos'},
            ),
          );
          unawaited(sessionStore.markConsumed(FeedSurface.videos, entry.id));
        }
        if (!sent95Pct.value && ratio >= 0.95) {
          sent95Pct.value = true;
          unawaited(
            feedRepository.recordInteraction(
              contentItemId: entry.id,
              eventType: FeedInteractionEvent.video95pct,
              extraData: const {'surface': 'videos'},
            ),
          );
          unawaited(sessionStore.markConsumed(FeedSurface.videos, entry.id));
        }
      }

      if (controller != null) {
        controller.addListener(handleProgress);
        handleProgress();
        return () => controller.removeListener(handleProgress);
      }

      handleProgress();
      return null;
    }, [controller, playerState, isVisible, playbackUrl]);

    useEffect(() {
      return () {
        unawaited(
          _recordEarlySkipIfNeeded(
            repository: feedRepository,
            sentStart: sentStart.value,
            sentSkip: sentSkip.value,
            startedAt: startedAt.value,
            positionMs: lastPositionMs.value,
          ).then((didRecord) {
            if (didRecord) {
              sentSkip.value = true;
            }
          }),
        );
      };
    }, const []);

    // Note: Don't release video resources on dispose - let the pool manager handle cleanup.
    // Releasing here causes "IOSInAppWebViewController used after disposed" errors
    // because the YoutubePlayer widget's WebView may still be unmounting.

    // While the iOS share sheet is open, the YouTube WebView (PlatformView)
    // intercepts taps that would otherwise hit the page-sheet backdrop and
    // dismiss the sheet. A parent GestureDetector calls the native dismiss
    // instead; AbsorbPointer beneath prevents child handlers from also firing.
    // onTap is null when not sharing — zero interference with normal gestures.
    return Stack(
      children: [
        // Main card — absorbed while sharing so no accidental gestures fire.
        GestureDetector(
          onTap: isSharing
              ? () => unawaited(ShareService.instance.dismissShareSheet())
              : null,
          child: AbsorbPointer(
            absorbing: isSharing,
            child: Stack(
              children: [
                FeedCardFrame(
                  // 16:9 ensures YoutubePlayer fills the media section exactly —
                  // no black bars when the inline player is active.
                  mediaAspectRatio: 16 / 9,
                  media: _VideoMedia(
                    thumbnailUrl: preview,
                    controller: controller,
                    overlayState: overlayState,
                    playerError: playerError,
                  ),
                  category: entry.category,
                  title: entry.title,
                  summary: entry.summary,
                  source: entry.source,
                  freshnessInfo: FreshnessInfo(
                    publishedAt: entry.publishedAt,
                    addedAt: entry.addedAt,
                    tier: entry.freshnessTier,
                    isNewSinceLastSeen: isNewSinceLastSeen,
                  ),
                  readTime: watchLabel,
                  onMediaTap: () => _handleTap(
                    showBubbles: showBubbles,
                    videoManager: videoManager,
                    playbackUrl: playbackUrl,
                  ),
                  onLongPress: () => _showActionsSheet(context, ref, feedRepository),
                  onMoreOptions: () => _showActionsSheet(context, ref, feedRepository),
                  onContentTap: () => _openInBrowser(
                    repository: feedRepository,
                    sessionStore: sessionStore,
                  ),
                  onChat: () => showBubbles.value = !showBubbles.value,
                  onShare: () => _shareVideo(
                    context,
                    feedRepository,
                    sessionStore,
                  ),
                  onSaveToggle: () => unawaited(
                    ref.read(savedVideosProvider.notifier).toggle(entry),
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
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleTap({
    required ValueNotifier<bool> showBubbles,
    required YoutubePlayerManagerBase videoManager,
    required String playbackUrl,
  }) async {
    if (showBubbles.value) {
      showBubbles.value = false;
      return;
    }

    final freshController = videoManager.getController(playbackUrl);
    final freshPlayerState = videoManager.getState(playbackUrl);
    final freshOverlayState = videoManager.getPlaybackOverlayState(playbackUrl);
    final controllerState = freshController?.value.playerState;

    if (freshPlayerState == YTPlayerState.error ||
        freshOverlayState == YTPlaybackOverlayState.error) {
      await videoManager.retryVideo(playbackUrl);
      return;
    }

    if (freshOverlayState == YTPlaybackOverlayState.manualPause ||
        freshOverlayState == YTPlaybackOverlayState.autoplayStalled ||
        freshOverlayState == YTPlaybackOverlayState.autoplayPending) {
      unawaited(videoManager.ensurePlayback(playbackUrl));
      return;
    }

    if (freshPlayerState == YTPlayerState.playing ||
        controllerState == PlayerState.playing) {
      videoManager.pauseVideo(playbackUrl);
      return;
    }

    unawaited(videoManager.ensurePlayback(playbackUrl));
  }

  String _resolvePlaybackUrl(YoutubePlayerManagerBase videoManager) {
    final preferred = entry.videoUrl.trim();
    if (preferred.isNotEmpty &&
        videoManager.extractVideoId(preferred) != null) {
      return preferred;
    }
    return entry.link.trim();
  }

  Future<void> _openInBrowser({
    required FeedRepository repository,
    required FeedSessionStore sessionStore,
  }) async {
    unawaited(_recordOpenIntent(repository, sessionStore));
    final uri = resolvePreferredExternalVideoUri(
      sourceUrl: entry.link,
      videoUrl: entry.videoUrl,
    );
    if (uri == null) {
      logger.warning(
        'Missing launchable external video URL',
        category: LogCategory.app,
        error: 'source=${entry.link} video=${entry.videoUrl}',
      );
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      logger.warning(
        'Failed to launch video URL',
        category: LogCategory.app,
        error: uri.toString(),
      );
    }
  }

  Future<void> _recordOpenIntent(
    FeedRepository repository,
    FeedSessionStore sessionStore,
  ) async {
    await repository.recordInteraction(
      contentItemId: entry.id,
      eventType: FeedInteractionEvent.openSource,
      extraData: const {'surface': 'videos'},
    );
    try {
      await sessionStore.markConsumed(FeedSurface.videos, entry.id);
    } catch (error, stackTrace) {
      logger.warning(
        'Failed to persist video consumed state after open',
        category: LogCategory.app,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _shareVideo(
    BuildContext context,
    FeedRepository repository,
    FeedSessionStore sessionStore,
  ) async {
    unawaited(_recordShareIntent(repository, sessionStore));
    final dateLabel = DateFormat(
      'MMM d, yyyy',
    ).format(entry.publishedAt.toLocal());
    final preview = entry.thumbnailUrl ?? _videoFallbackImage;

    await ShareService.instance.shareVideo(
      context: context,
      title: entry.title,
      summary: entry.summary,
      channelName: entry.source,
      category: entry.category,
      date: dateLabel,
      duration: _buildWatchLabel(
        controller: null,
        explicitDurationSeconds: entry.durationSeconds,
      ),
      thumbnailUrl: preview,
      videoUrl: entry.link,
    );
  }

  Future<void> _recordShareIntent(
    FeedRepository repository,
    FeedSessionStore sessionStore,
  ) async {
    await repository.recordInteraction(
      contentItemId: entry.id,
      eventType: FeedInteractionEvent.videoShare,
      extraData: const {'surface': 'videos'},
    );
    try {
      await sessionStore.markConsumed(FeedSurface.videos, entry.id);
    } catch (error, stackTrace) {
      logger.warning(
        'Failed to persist video consumed state after share',
        category: LogCategory.app,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _showActionsSheet(
    BuildContext context,
    WidgetRef ref,
    FeedRepository repository,
  ) async {
    final action = await showModalBottomSheet<_VideoCardAction>(
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
              onTap: () =>
                  Navigator.of(ctx).pop(_VideoCardAction.lessFromCreator),
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Report'),
              subtitle: const Text('Flag this video for review.'),
              onTap: () => Navigator.of(ctx).pop(_VideoCardAction.report),
            ),
          ],
        ),
      ),
    );

    if (action == null || !context.mounted) return;

    switch (action) {
      case _VideoCardAction.lessFromCreator:
        await ref.read(blockedSourcesProvider.notifier).block(entry.source);
        unawaited(repository.recordInteraction(
          contentItemId: entry.id,
          eventType: FeedInteractionEvent.lessFromCreator,
          extraData: {'surface': 'videos', 'source': entry.source},
        ));
        if (context.mounted) {
          _showFeedback(
              context, '${entry.source} blocked and removed from your feed.');
        }
      case _VideoCardAction.report:
        if (!context.mounted) return;
        final reason = await ContentReportSheet.show(context);
        if (reason == null || !context.mounted) return;
        final ok = await repository.reportContent(
          contentItemId: entry.id,
          surface: 'videos',
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

  Future<bool> _recordEarlySkipIfNeeded({
    required FeedRepository repository,
    required bool sentStart,
    required bool sentSkip,
    required DateTime? startedAt,
    required int positionMs,
  }) async {
    if (!sentStart || sentSkip || startedAt == null) {
      return false;
    }

    final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
    final consumedMs = positionMs > 0 ? positionMs : elapsedMs;
    if (consumedMs >= 2000) {
      return false;
    }

    await repository.recordInteraction(
      contentItemId: entry.id,
      eventType: FeedInteractionEvent.videoSkipLt2s,
      extraData: {
        'surface': 'videos',
        'position_ms': consumedMs,
      },
    );
    return true;
  }

  int _resolveDurationMs({
    required YoutubePlayerController? controller,
    required int? explicitDurationSeconds,
    required int fallbackMinutes,
  }) {
    final controllerDurationMs =
        controller?.value.metaData.duration.inMilliseconds ?? 0;
    if (controllerDurationMs > 0) {
      return controllerDurationMs;
    }
    if (explicitDurationSeconds != null && explicitDurationSeconds > 0) {
      return explicitDurationSeconds * 1000;
    }
    return fallbackMinutes > 0 ? fallbackMinutes * 60 * 1000 : 0;
  }

  String _buildWatchLabel({
    required YoutubePlayerController? controller,
    required int? explicitDurationSeconds,
  }) {
    final controllerDurationSeconds =
        controller == null ? 0 : controller.value.metaData.duration.inSeconds;
    if (controllerDurationSeconds > 0) {
      final minutes = (controllerDurationSeconds / 60).ceil();
      return '$minutes min watch';
    }
    if (explicitDurationSeconds != null && explicitDurationSeconds > 0) {
      final minutes = (explicitDurationSeconds / 60).ceil();
      return '$minutes min watch';
    }
    return 'Watch video';
  }

  void _showFeedback(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1400),
        ),
      );
  }
}

class _VideoMedia extends StatelessWidget {
  const _VideoMedia({
    required this.thumbnailUrl,
    required this.controller,
    required this.overlayState,
    required this.playerError,
  });

  final String thumbnailUrl;
  final YoutubePlayerController? controller;
  final YTPlaybackOverlayState overlayState;
  final YTPlayerError? playerError;

  /// Checks if controller exists and can render the underlying WebView.
  bool get _isControllerValid {
    return controller != null;
  }

  @override
  Widget build(BuildContext context) {
    final showPlayer = _isControllerValid;
    final showPlayButton = overlayState == YTPlaybackOverlayState.manualPause ||
        overlayState == YTPlaybackOverlayState.autoplayStalled;
    final showError = overlayState == YTPlaybackOverlayState.error;

    return ClipRect(
      clipBehavior: Clip.hardEdge,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Thumbnail background
          Positioned.fill(
            child: thumbnailUrl.trim().isEmpty
                ? Container(
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
                    child: const Icon(
                      Icons.videocam_outlined,
                      size: 36,
                      color: Colors.white30,
                    ),
                  )
                : Image.network(
                    thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
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
                      child: const Icon(
                        Icons.videocam_outlined,
                        size: 36,
                        color: Colors.white30,
                      ),
                    ),
                  ),
          ),

          // Video player when ready and controller is valid
          if (showPlayer)
            Positioned.fill(
              child: YoutubePlayer(
                controller: controller!,
                showVideoProgressIndicator: false,
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

          if (showError) _VideoErrorOverlay(error: playerError),

          // Play button only appears after a user pause or a genuine autoplay stall.
          if (showPlayButton) _PlayButton(),
        ],
      ),
    );
  }
}

class _VideoErrorOverlay extends StatelessWidget {
  const _VideoErrorOverlay({required this.error});

  final YTPlayerError? error;

  @override
  Widget build(BuildContext context) {
    var title = 'Playback failed';
    var hint = 'Tap to retry';

    if (error != null) {
      if (error!.isPlaybackDisabled) {
        title = 'Playback disabled';
        hint = 'Video owner disabled embedding';
      } else if (error!.isVideoUnavailable) {
        title = 'Video unavailable';
        hint = 'Video may be private or removed';
      }
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 28),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              hint,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 2,
          ),
        ),
        child: const Icon(
          Icons.play_arrow_rounded,
          size: 72,
          color: Colors.white,
        ),
      ),
    );
  }
}
