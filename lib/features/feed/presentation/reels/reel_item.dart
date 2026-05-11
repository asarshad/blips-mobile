import 'dart:async';

import 'package:blips_mobile/core/error/error.dart';
import 'package:blips_mobile/core/services/external_url_launcher.dart';
import 'package:blips_mobile/features/feed/data/feed_repository.dart';
import 'package:blips_mobile/features/feed/data/feed_session_store.dart';
import 'package:blips_mobile/features/feed/domain/external_video_url.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/presentation/reels/reel_action_button.dart';
import 'package:blips_mobile/features/feed/presentation/reels/reel_playback_tap_action.dart';
import 'package:blips_mobile/features/feed/presentation/widgets/widgets.dart';
import 'package:blips_mobile/features/feed/providers/blocked_sources_provider.dart';
import 'package:blips_mobile/features/feed/providers/feed_providers.dart';
import 'package:blips_mobile/features/feed/providers/saved_items_providers.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager_base.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
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
    final playbackUrl = _resolvePlaybackUrl(videoManager);
    final controller = videoManager.getController(playbackUrl);
    final playerState = videoManager.getState(playbackUrl);
    final overlayState = videoManager.getPlaybackOverlayState(playbackUrl);
    final playerError = videoManager.getError(playbackUrl);
    final isSaved = ref.watch(savedVideoIdsProvider).contains(entry.id);
    // While the native share sheet is open, iOS doesn't block taps in the
    // exposed area above a page sheet. Absorb any leaked taps so the
    // full-screen playback overlay and info text don't react.
    final isSharing = useValueListenable(ShareService.instance.isSharing);
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
          unawaited(videoManager.ensurePlayback(playbackUrl));
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
      [playbackUrl, isActive, isVisible],
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

    final isError = overlayState == YTPlaybackOverlayState.error;
    // Mount the player whenever a controller exists so iframe initialization
    // can progress while state is still loading. Thumbnail/spinner overlays
    // remain on top until real playback starts.
    final showVideo = controller != null;
    final showPlayIndicator =
        (overlayState == YTPlaybackOverlayState.manualPause && !showVideo) ||
            overlayState == YTPlaybackOverlayState.autoplayStalled;

    // While the iOS share sheet is open, the YouTube WebView (PlatformView)
    // sits in its own native UIView layer and intercepts taps that would
    // otherwise hit the page-sheet backdrop and dismiss the sheet.
    // Solution: wrap in a GestureDetector that, while sharing, calls the
    // native dismiss instead of letting the tap fall through to play/pause.
    // AbsorbPointer beneath it prevents child handlers from also firing.
    return Stack(
      fit: StackFit.expand,
      children: [
        // Main content — absorbed while sharing so no accidental gestures fire.
        GestureDetector(
          // Attempt programmatic native dismiss on any tap while sharing.
          // onTap is null when not sharing → zero interference with children.
          onTap: isSharing
              ? () => unawaited(ShareService.instance.dismissShareSheet())
              : null,
          child: AbsorbPointer(
            absorbing: isSharing,
            child: Stack(
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

                    // Tap capture overlay above the PlatformView so taps always
                    // reach our play/pause handler, even when WebView swallows.
                    Positioned.fill(
                      child: GestureDetector(
                        key: const ValueKey('reel_playback_tap_overlay'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _handleTap(
                          controller,
                          videoManager,
                          playbackUrl,
                          playerState,
                          overlayState,
                        ),
                      ),
                    ),

                    // Show our play affordance only when the iframe does not
                    // already draw one, or autoplay recovery genuinely stalls.
                    if (isActive && showPlayIndicator)
                      const IgnorePointer(child: _PlayIndicator()),

                    // Error indicator
                    if (isError)
                      IgnorePointer(
                        child: _ErrorIndicator(error: playerError),
                      ),
                  ],
                ),

                // Action Buttons
                _ActionButtons(
                  isSaved: isSaved,
                  onSaveToggle: () =>
                      ref.read(savedVideosProvider.notifier).toggleReel(
                            entry,
                          ),
                  onShare: () => _shareReel(repository, sessionStore),
                  onOpen: () => _openReel(repository, sessionStore),
                  onLessFromCreator: () =>
                      _lessFromCreator(context, ref, repository),
                  onReport: () => _reportReel(context, ref, repository),
                ),

                // Info Layer
                _InfoLayer(
                  entry: entry,
                  isTextExpanded: isTextExpanded,
                ),
              ],
            ),
          ),
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
    String playbackUrl,
    YTPlayerState playerState,
    YTPlaybackOverlayState overlayState,
  ) {
    // Always read fresh state from the manager rather than the closure-captured
    // values. The widget may not have rebuilt between two rapid taps (because
    // _notifySafe posts a microtask), so playerState/overlayState can be stale.
    // Stale autoplayStalled causes every tap to resolve to retry, each one
    // calling releaseVideo which yanks _pendingInit out from under the previous
    // initController — creating concurrent controller creations and a permanent
    // stuck state.
    final freshController = videoManager.getController(playbackUrl);
    final freshPlayerState = videoManager.getState(playbackUrl);
    final freshOverlayState = videoManager.getPlaybackOverlayState(playbackUrl);

    final action = resolveReelPlaybackTapAction(
      hasController: freshController != null,
      showsPlayAffordance:
          freshOverlayState == YTPlaybackOverlayState.manualPause ||
              freshOverlayState == YTPlaybackOverlayState.autoplayStalled,
      playerState: freshPlayerState,
      controllerPlayerState: freshController?.value.playerState,
    );

    switch (action) {
      case ReelPlaybackTapAction.retry:
        debugPrint('Retrying reel playback: $playbackUrl');
        videoManager.retryVideo(playbackUrl);
      case ReelPlaybackTapAction.pause:
        videoManager.pauseVideo(playbackUrl);
      case ReelPlaybackTapAction.play:
        unawaited(videoManager.ensurePlayback(playbackUrl));
    }
  }

  String _resolvePlaybackUrl(YoutubePlayerManagerBase videoManager) {
    final preferred = entry.videoUrl.trim();
    if (preferred.isNotEmpty &&
        videoManager.extractVideoId(preferred) != null) {
      return preferred;
    }
    return entry.link.trim();
  }

  Future<void> _shareReel(
    FeedRepository repository,
    FeedSessionStore sessionStore,
  ) async {
    unawaited(_recordShareIntent(repository, sessionStore));
    await ShareService.instance.shareReel(
      title: entry.title,
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
      extraData: const {'surface': 'reels'},
    );
    try {
      await sessionStore.markConsumed(FeedSurface.reels, entry.id);
    } catch (error, stackTrace) {
      logger.warning(
        'Failed to persist reel consumed state after share',
        category: LogCategory.app,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _openReel(
    FeedRepository repository,
    FeedSessionStore sessionStore,
  ) async {
    unawaited(_recordOpenIntent(repository, sessionStore));
    final uri = resolvePreferredExternalVideoUri(
      sourceUrl: entry.link,
      videoUrl: entry.videoUrl,
      preferShorts: true,
    );
    if (uri == null) {
      logger.warning(
        'Missing launchable external reel URL',
        category: LogCategory.app,
        error: 'source=${entry.link} video=${entry.videoUrl}',
      );
      return;
    }
    final launched = await ExternalUrlLauncher.launchUri(uri);
    if (!launched) {
      logger.warning(
        'Failed to launch reel URL',
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
      extraData: const {'surface': 'reels'},
    );
    try {
      await sessionStore.markConsumed(FeedSurface.reels, entry.id);
    } catch (error, stackTrace) {
      logger.warning(
        'Failed to persist reel consumed state after open',
        category: LogCategory.app,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _lessFromCreator(
    BuildContext context,
    WidgetRef ref,
    FeedRepository repository,
  ) async {
    await ref.read(blockedSourcesProvider.notifier).block(entry.source);
    unawaited(repository.recordInteraction(
      contentItemId: entry.id,
      eventType: FeedInteractionEvent.lessFromCreator,
      extraData: {'surface': 'reels', 'source': entry.source},
    ));
    unawaited(repository.reportContent(
      contentItemId: entry.id,
      surface: 'reels',
      reason: 'blocked_source',
    ));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${entry.source} blocked and removed from your feed.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _reportReel(
    BuildContext context,
    WidgetRef ref,
    FeedRepository repository,
  ) async {
    final reason = await ContentReportSheet.show(context);
    if (reason == null || !context.mounted) return;
    final ok = await repository.reportContent(
      contentItemId: entry.id,
      surface: 'reels',
      reason: reason,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? 'Thanks — we\'ll review this content.'
              : 'Couldn\'t submit your report. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
          child: IgnorePointer(
            child: YoutubePlayer(
              controller: controller,
              progressColors: const ProgressBarColors(
                playedColor: Colors.white,
                handleColor: Colors.white,
              ),
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
    required this.isSaved,
    required this.onSaveToggle,
    required this.onShare,
    required this.onOpen,
    required this.onLessFromCreator,
    required this.onReport,
  });

  final bool isSaved;
  final Future<void> Function() onSaveToggle;
  final Future<void> Function() onShare;
  final Future<void> Function() onOpen;
  final Future<void> Function() onLessFromCreator;
  final Future<void> Function() onReport;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 4,
      bottom: 120,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ReelActionButton(
            icon: isSaved
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            label: isSaved ? 'Saved' : 'Save',
            onTap: () => unawaited(onSaveToggle()),
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 12),
          ReelActionButton(
            icon: Icons.block_outlined,
            label: 'Block',
            onTap: () => unawaited(onLessFromCreator()),
          ),
          const SizedBox(height: 12),
          ReelActionButton(
            icon: Icons.flag_outlined,
            label: 'Report',
            onTap: () => unawaited(onReport()),
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
