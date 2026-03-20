import 'dart:async';

import 'package:blips_mobile/features/feed/data/feed_repository.dart';
import 'package:blips_mobile/features/feed/data/feed_session_store.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/presentation/reels/reel_action_button.dart';
import 'package:blips_mobile/features/feed/presentation/widgets/widgets.dart';
import 'package:blips_mobile/features/feed/providers/feed_providers.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager_base.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

/// Individual reel item with video playback.
///
/// Shows thumbnail while loading, then transitions to video.
/// Tap to play/pause.
class ReelItem extends HookConsumerWidget {
  /// Creates a reel item.
  const ReelItem({
    required this.entry,
    required this.isActive,
    required this.isVisible,
    super.key,
  });

  /// The reel entry data.
  final ReelFeedEntry entry;

  /// Whether this reel is the currently active one in the PageView.
  final bool isActive;

  /// Whether the reels page is currently visible.
  final bool isVisible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(feedRepositoryProvider);
    final sessionStore = ref.read(feedSessionStoreProvider);
    final videoManager = ref.watch(youtubePlayerManagerProvider);
    final controller = videoManager.getController(entry.link);
    final playerState = videoManager.getState(entry.link);
    final playerError = videoManager.getError(entry.link);
    final showThumbnail = useState(true);
    final isMounted = useIsMounted();
    final isTextExpanded = useState(false);
    final sentImpression = useRef(false);
    final sentStart = useRef(false);
    final sent3s = useRef(false);
    final sent50Pct = useRef(false);
    final sent95Pct = useRef(false);
    final sentSkip = useRef(false);
    final startedAt = useRef<DateTime?>(null);
    final lastPositionMs = useRef(0);

    // Track when video is actually playing to hide thumbnail
    _useThumbnailVisibility(
      controller: controller,
      isActive: isActive,
      showThumbnail: showThumbnail,
      isMounted: isMounted,
    );

    // Safety net for missed initial autoplay: when this reel is the active,
    // visible page, explicitly (re)arm playback after the widget is mounted.
    useEffect(
      () {
        if (isActive && isVisible) {
          unawaited(videoManager.playVideo(entry.link));
        } else {
          unawaited(
            _recordEarlySkipIfNeeded(
              repository: repository,
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
        }
        return null;
      },
      [entry.link, isActive, isVisible],
    );

    useEffect(() {
      if (isActive && isVisible && !sentImpression.value) {
        sentImpression.value = true;
        unawaited(
          repository.recordInteraction(
            contentItemId: entry.id,
            eventType: FeedInteractionEvent.videoImpression,
            extraData: const {'surface': 'reels'},
          ),
        );
      }
      return null;
    }, [isActive, isVisible]);

    useEffect(() {
      void handleProgress() {
        if (!isActive || !isVisible) return;

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
            repository.recordInteraction(
              contentItemId: entry.id,
              eventType: FeedInteractionEvent.videoStart,
              extraData: const {'surface': 'reels'},
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
        );

        if (!sent3s.value && positionMs >= 3000) {
          sent3s.value = true;
          unawaited(
            repository.recordInteraction(
              contentItemId: entry.id,
              eventType: FeedInteractionEvent.video3s,
              extraData: const {'surface': 'reels'},
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
            repository.recordInteraction(
              contentItemId: entry.id,
              eventType: FeedInteractionEvent.video50pct,
              extraData: const {'surface': 'reels'},
            ),
          );
        }
        if (!sent95Pct.value && ratio >= 0.95) {
          sent95Pct.value = true;
          unawaited(
            repository.recordInteraction(
              contentItemId: entry.id,
              eventType: FeedInteractionEvent.video95pct,
              extraData: const {'surface': 'reels'},
            ),
          );
          unawaited(sessionStore.markConsumed(FeedSurface.reels, entry.id));
        }
      }

      if (controller != null) {
        controller.addListener(handleProgress);
        handleProgress();
        return () => controller.removeListener(handleProgress);
      }

      handleProgress();
      return null;
    }, [controller, playerState, isActive, isVisible]);

    useEffect(() {
      return () {
        unawaited(
          _recordEarlySkipIfNeeded(
            repository: repository,
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

    final isLoading = playerState == YTPlayerState.loading ||
        playerState == YTPlayerState.idle;
    final isError = playerState == YTPlayerState.error;

    // Mount the player whenever a controller exists so iframe initialization
    // can progress while state is still loading. Thumbnail/spinner overlays
    // remain on top until real playback starts.
    final showVideo = controller != null;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Video Layer
        Stack(
          fit: StackFit.expand,
          children: [
            // Video Layer - only show when ready
            if (showVideo) _YoutubeVideoLayer(controller: controller),

            // Thumbnail Layer
            _ThumbnailLayer(
              thumbnailUrl: entry.thumbnailUrl,
              isVisible: showThumbnail.value,
            ),

            // Gradient Overlay
            const _GradientOverlay(),

            // Tap capture overlay above the PlatformView so taps always reach
            // our play/pause handler, even when WebView swallows gestures.
            Positioned.fill(
              child: GestureDetector(
                key: const ValueKey('reel_playback_tap_overlay'),
                behavior: HitTestBehavior.opaque,
                onTap: () => _handleTap(controller, videoManager, playerState),
              ),
            ),

            // Play/pause indicator.
            // Show when paused (user tapped pause) or ready (auto-play
            // hasn't fired yet, tap re-arms it).  Intentionally hidden
            // during loading/idle so the spinner is the only indicator.
            if (isActive &&
                (playerState == YTPlayerState.paused ||
                    playerState == YTPlayerState.ready))
              const IgnorePointer(child: _PlayIndicator()),

            // Loading Indicator
            if (isActive && isLoading)
              const IgnorePointer(
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),

            // Error indicator
            if (isError)
              IgnorePointer(
                child: _ErrorIndicator(error: playerError),
              ),
          ],
        ),

        // Action Buttons
        _ActionButtons(
          onShare: () => _shareReel(repository, sessionStore),
          onOpen: () => _openReel(repository, sessionStore),
        ),

        // Info Layer (not tappable for play/pause, but text is tappable for expand/collapse)
        _InfoLayer(
          entry: entry,
          isTextExpanded: isTextExpanded,
        ),
      ],
    );
  }

  void _useThumbnailVisibility({
    required YoutubePlayerController? controller,
    required bool isActive,
    required ValueNotifier<bool> showThumbnail,
    required bool Function() isMounted,
  }) {
    useEffect(
      () {
        if (controller != null) {
          void listener() {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!isMounted()) return;

              final isPlaying =
                  controller.value.playerState == PlayerState.playing;

              // Hide thumbnail as soon as video starts playing.
              if (isPlaying && showThumbnail.value) {
                showThumbnail.value = false;
              } else if (!isActive && !showThumbnail.value) {
                showThumbnail.value = true;
              }
            });
          }

          controller.addListener(listener);
          // Eagerly restore thumbnail if item was swiped off-screen before
          // the controller fires another event (fast-swipe black frame fix).
          if (!isActive && !showThumbnail.value) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (isMounted()) showThumbnail.value = true;
            });
          }
          return () => controller.removeListener(listener);
        } else {
          // Controller was released (e.g. retryVideo after returning from
          // background or browser).  Restore the thumbnail so the user sees
          // a placeholder while the fresh controller loads, rather than a
          // black frame.
          if (!showThumbnail.value) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (isMounted()) showThumbnail.value = true;
            });
          }
          return null;
        }
      },
      [controller, isActive],
    );
  }

  void _handleTap(
    YoutubePlayerController? controller,
    YoutubePlayerManagerBase videoManager,
    YTPlayerState playerState,
  ) {
    // If error state, retry loading
    if (playerState == YTPlayerState.error) {
      debugPrint('Retrying failed video: ${entry.link}');
      videoManager.retryVideo(entry.link);
      return;
    }

    // If no controller yet, try to play (will trigger load)
    if (controller == null) {
      videoManager.playVideo(entry.link);
      return;
    }

    // Toggle play/pause
    if (controller.value.playerState == PlayerState.playing) {
      videoManager.pauseVideo(entry.link);
    } else {
      videoManager.playVideo(entry.link);
    }
  }

  Future<void> _shareReel(
    FeedRepository repository,
    FeedSessionStore sessionStore,
  ) async {
    await repository.recordInteraction(
      contentItemId: entry.id,
      eventType: FeedInteractionEvent.videoShare,
      extraData: const {'surface': 'reels'},
    );
    await sessionStore.markConsumed(FeedSurface.reels, entry.id);
    await ShareService.instance.shareReel(
      title: entry.title,
      videoUrl: entry.link,
    );
  }

  Future<void> _openReel(
    FeedRepository repository,
    FeedSessionStore sessionStore,
  ) async {
    await repository.recordInteraction(
      contentItemId: entry.id,
      eventType: FeedInteractionEvent.openSource,
      extraData: const {'surface': 'reels'},
    );
    await sessionStore.markConsumed(FeedSurface.reels, entry.id);
    final uri = Uri.parse(entry.link);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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
        'surface': 'reels',
        'position_ms': consumedMs,
      },
    );
    return true;
  }

  int _resolveDurationMs({
    required YoutubePlayerController? controller,
    required int? explicitDurationSeconds,
  }) {
    final controllerDurationMs =
        controller?.value.metaData.duration.inMilliseconds ?? 0;
    if (controllerDurationMs > 0) {
      return controllerDurationMs;
    }
    if (explicitDurationSeconds != null && explicitDurationSeconds > 0) {
      return explicitDurationSeconds * 1000;
    }
    return 30 * 1000;
  }
}

class _YoutubeVideoLayer extends StatelessWidget {
  const _YoutubeVideoLayer({required this.controller});

  final YoutubePlayerController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.width * 16 / 9,
          child: YoutubePlayer(
            controller: controller,
            progressColors: const ProgressBarColors(
              playedColor: Colors.white,
              handleColor: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _ThumbnailLayer extends StatelessWidget {
  const _ThumbnailLayer({
    required this.thumbnailUrl,
    required this.isVisible,
  });

  final String? thumbnailUrl;
  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: IgnorePointer(
        child: Image.network(
          thumbnailUrl ?? '',
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => Container(color: Colors.black),
        ),
      ),
    );
  }
}

class _GradientOverlay extends StatelessWidget {
  const _GradientOverlay();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, Colors.black87],
          begin: Alignment.center,
          end: Alignment.bottomCenter,
          stops: [0.6, 1.0],
        ),
      ),
    );
  }
}

class _PlayIndicator extends StatelessWidget {
  const _PlayIndicator();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.black38,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.play_arrow,
          color: Colors.white70,
          size: 48,
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.onShare,
    required this.onOpen,
  });

  final Future<void> Function() onShare;
  final Future<void> Function() onOpen;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 4,
      bottom: 120,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ReelActionButton(
            icon: Icons.share,
            label: 'Share',
            onTap: () => unawaited(onShare()),
          ),
          const SizedBox(height: 12),
          ReelActionButton(
            icon: Icons.open_in_new,
            label: 'Open',
            onTap: () => unawaited(onOpen()),
          ),
        ],
      ),
    );
  }
}

class _InfoLayer extends HookWidget {
  const _InfoLayer({
    required this.entry,
    required this.isTextExpanded,
  });

  final ReelFeedEntry entry;
  final ValueNotifier<bool> isTextExpanded;

  @override
  Widget build(BuildContext context) {
    // Watch the value notifier
    final expanded = useValueListenable(isTextExpanded);

    return Positioned(
      left: 16,
      right: 16,
      bottom: 32,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          IgnorePointer(
            child: _SourceBadge(source: entry.source),
          ),
          const SizedBox(height: 12),
          IgnorePointer(
            child: Text(
              entry.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (entry.summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                isTextExpanded.value = !isTextExpanded.value;
              },
              child: Text(
                entry.summary,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.3,
                ),
                maxLines: expanded ? null : 2,
                overflow: expanded ? null : TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        source,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ErrorIndicator extends StatelessWidget {
  const _ErrorIndicator({this.error});

  final YTPlayerError? error;

  @override
  Widget build(BuildContext context) {
    var message = 'Failed to load video';
    var hint = 'Tap to retry';

    if (error != null) {
      if (error!.isPlaybackDisabled) {
        message = 'Playback disabled';
        hint = 'Video owner disabled playback';
      } else if (error!.isVideoUnavailable) {
        message = 'Video unavailable';
        hint = 'Video may be private or removed';
      } else if (error!.isConfigError) {
        message = 'Configuration error';
        hint = 'Tap to retry';
      }
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: Colors.grey[400]),
          ),
          const SizedBox(height: 4),
          Text(
            hint,
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }
}
