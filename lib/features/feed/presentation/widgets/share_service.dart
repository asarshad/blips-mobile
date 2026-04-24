import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

typedef ShareCardCaptureOverride = Future<Uint8List?> Function({
  required BuildContext context,
  required String title,
  required String summary,
  required String source,
  required String category,
  required String date,
  required String readTime,
  required String? imageUrl,
  required bool isVideo,
});

/// Service for capturing and sharing feed content.
///
/// Uses Flutter's native rendering (RepaintBoundary + overlay) to capture
/// widgets as images. The captured image is shared along with the content URL.
class ShareService {
  ShareService._({
    SharePlus? sharePlus,
    ShareCardCaptureOverride? captureOverride,
  })  : _sharePlus = sharePlus ?? SharePlus.instance,
        _captureOverride = captureOverride;

  /// Shared singleton instance.
  static final ShareService _defaultInstance = ShareService._();

  @visibleForTesting
  static ShareService? debugOverride;

  static ShareService get instance => debugOverride ?? _defaultInstance;

  @visibleForTesting
  factory ShareService.test({
    SharePlus? sharePlus,
    ShareCardCaptureOverride? captureOverride,
  }) {
    return ShareService._(
      sharePlus: sharePlus,
      captureOverride: captureOverride,
    );
  }

  static const _shareAttribution = 'Shared via Blips News';

  static const _uiChannel = MethodChannel('blips/ui');

  /// Programmatically dismisses the native share sheet.
  ///
  /// On iOS, screens that embed a PlatformView (YouTube WebView) cause the
  /// WebView's native UIView to intercept taps that would otherwise hit the
  /// page-sheet backdrop and auto-dismiss the sheet.  Call this from a
  /// Flutter GestureDetector wrapping those screens so the user's "tap
  /// outside" gesture still closes the share sheet.
  Future<void> dismissShareSheet() async {
    if (!_isSharing.value) return;
    if (!Platform.isIOS) return;
    try {
      await _uiChannel.invokeMethod<void>('dismissPresentedViewController');
    } catch (_) {
      // Best-effort — if channel call fails the user can still swipe-down.
    }
  }

  final SharePlus _sharePlus;
  final ShareCardCaptureOverride? _captureOverride;

  final ValueNotifier<bool> _isSharing = ValueNotifier<bool>(false);

  /// Whether a share sheet is currently being shown.
  ///
  /// iOS presents the share sheet as a page sheet that does not block taps
  /// on the exposed area above it. Widgets with background tap / long-press
  /// handlers (play/pause overlays, card action menus, etc.) should wrap
  /// themselves in an `AbsorbPointer` driven by this listenable so stray
  /// taps that leak through don't trigger background interactions while the
  /// user is mid-share.
  ValueListenable<bool> get isSharing => _isSharing;

  /// Shares an article with a screenshot and URL.
  Future<void> shareArticle({
    required BuildContext context,
    required String title,
    required String summary,
    required String source,
    required String category,
    required String date,
    required String readTime,
    required String? imageUrl,
    required String articleUrl,
  }) async {
    if (_isSharing.value) return;
    _isSharing.value = true;

    try {
      debugPrint('ShareService: Starting article share for "$title"');

      final imageBytes = await (_captureOverride ?? _captureShareCard)(
        context: context,
        title: title,
        summary: summary,
        source: source,
        category: category,
        date: date,
        readTime: readTime,
        imageUrl: imageUrl,
        isVideo: false,
      );

      if (imageBytes != null && imageBytes.isNotEmpty) {
        debugPrint('ShareService: Captured ${imageBytes.length} bytes');
        await _shareWithImage(
          imageBytes: imageBytes,
          url: articleUrl,
          subject: title,
        );
      } else {
        debugPrint('ShareService: Capture failed, falling back to text');
        await _shareTextOnly(
          text: _composeShareText(
            url: articleUrl,
            title: title,
          ),
          subject: title,
        );
      }
    } catch (e, stack) {
      debugPrint('ShareService: Error sharing article: $e');
      debugPrint('Stack: $stack');
      await _shareTextOnly(
        text: _composeShareText(
          url: articleUrl,
          title: title,
        ),
        subject: title,
      );
    } finally {
      _isSharing.value = false;
    }
  }

  /// Shares a video with a screenshot and URL.
  Future<void> shareVideo({
    required BuildContext context,
    required String title,
    required String summary,
    required String channelName,
    required String category,
    required String date,
    required String duration,
    required String thumbnailUrl,
    required String videoUrl,
  }) async {
    if (_isSharing.value) return;
    _isSharing.value = true;

    try {
      debugPrint('ShareService: Starting video share for "$title"');

      final imageBytes = await (_captureOverride ?? _captureShareCard)(
        context: context,
        title: title,
        summary: summary,
        source: channelName,
        category: category,
        date: date,
        readTime: duration,
        imageUrl: thumbnailUrl,
        isVideo: true,
      );

      if (imageBytes != null && imageBytes.isNotEmpty) {
        debugPrint('ShareService: Captured ${imageBytes.length} bytes');
        await _shareWithImage(
          imageBytes: imageBytes,
          url: videoUrl,
          subject: title,
        );
      } else {
        debugPrint('ShareService: Capture failed, falling back to text');
        await _shareTextOnly(
          text: _composeShareText(
            url: videoUrl,
            title: title,
          ),
          subject: title,
        );
      }
    } catch (e, stack) {
      debugPrint('ShareService: Error sharing video: $e');
      debugPrint('Stack: $stack');
      await _shareTextOnly(
        text: _composeShareText(
          url: videoUrl,
          title: title,
        ),
        subject: title,
      );
    } finally {
      _isSharing.value = false;
    }
  }

  /// Shares a reel with URL only (no screenshot).
  Future<void> shareReel({
    required String title,
    required String videoUrl,
  }) async {
    if (_isSharing.value) return;
    _isSharing.value = true;

    try {
      debugPrint('ShareService: Sharing reel "$title"');
      await _shareTextOnly(
        text: _composeShareText(url: videoUrl, title: title),
        subject: title,
      );
    } finally {
      _isSharing.value = false;
    }
  }

  /// Captures a share card by rendering it in an overlay.
  Future<Uint8List?> _captureShareCard({
    required BuildContext context,
    required String title,
    required String summary,
    required String source,
    required String category,
    required String date,
    required String readTime,
    required String? imageUrl,
    required bool isVideo,
  }) async {
    final completer = Completer<Uint8List?>();
    final boundaryKey = GlobalKey();
    OverlayEntry? overlayEntry;
    final overlay = Overlay.of(context);
    final theme = Theme.of(context);
    final normalizedImageUrl = imageUrl?.trim();

    try {
      if (normalizedImageUrl != null && normalizedImageUrl.isNotEmpty) {
        // Pre-cache the network image when an article/video actually has one.
        // Typically a cache hit (the user is viewing this exact image), so
        // near-instant. On a cold network this waits for the fetch rather
        // than rendering a placeholder — trade-off we're evaluating.
        debugPrint('ShareService: Pre-caching image: $normalizedImageUrl');
        final imageProvider = NetworkImage(normalizedImageUrl);
        await precacheImage(imageProvider, context);
        debugPrint('ShareService: Image cached');
      }

      // Create the overlay entry with the card
      overlayEntry = OverlayEntry(
        builder: (overlayContext) {
          return Positioned(
            left: -5000, // Off-screen
            top: -5000,
            child: RepaintBoundary(
              key: boundaryKey,
              child: Material(
                color: Colors.transparent,
                child: _buildShareCard(
                  theme: theme,
                  title: title,
                  summary: summary,
                  source: source,
                  category: category,
                  date: date,
                  readTime: readTime,
                  imageUrl: normalizedImageUrl,
                  isVideo: isVideo,
                ),
              ),
            ),
          );
        },
      );

      // Insert overlay
      overlay.insert(overlayEntry);
      debugPrint('ShareService: Overlay inserted');

      // Wait for the overlay to paint. Anchor the first wait to the first
      // frame after insertion, then wait for that frame to fully finish.
      // This avoids the race where consecutive endOfFrame awaits can both
      // complete immediately if called after the current frame already ended.
      final firstPostInsertFrame = Completer<void>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!firstPostInsertFrame.isCompleted) {
          firstPostInsertFrame.complete();
        }
      });
      await firstPostInsertFrame.future;
      await WidgetsBinding.instance.endOfFrame;

      // Capture the boundary
      final boundary = boundaryKey.currentContext?.findRenderObject();
      if (boundary is RenderRepaintBoundary) {
        debugPrint('ShareService: Found RepaintBoundary, capturing...');
        final image = await boundary.toImage();
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

        if (byteData != null) {
          debugPrint('ShareService: Capture successful');
          completer.complete(byteData.buffer.asUint8List());
        } else {
          debugPrint('ShareService: byteData is null');
          completer.complete(null);
        }
      } else {
        debugPrint('ShareService: Could not find RepaintBoundary');
        completer.complete(null);
      }
    } catch (e, stack) {
      debugPrint('ShareService: Capture error: $e');
      debugPrint('Stack: $stack');
      completer.complete(null);
    } finally {
      // Remove overlay
      overlayEntry?.remove();
    }

    return completer.future;
  }

  /// Builds the share card widget.
  Widget _buildShareCard({
    required ThemeData theme,
    required String title,
    required String summary,
    required String source,
    required String category,
    required String date,
    required String readTime,
    required String? imageUrl,
    required bool isVideo,
  }) {
    final colorScheme = theme.colorScheme;
    final scaffoldColor = theme.scaffoldBackgroundColor;
    final cardColor = theme.cardColor;
    final primaryColor = colorScheme.primary;
    final onSurface = colorScheme.onSurface;
    final onSurfaceVariant = colorScheme.onSurfaceVariant;
    final dividerColor = colorScheme.outlineVariant
        .withValues(alpha: theme.brightness == Brightness.dark ? 0.35 : 0.5);
    final playBadgeColor = colorScheme.surface.withValues(alpha: 0.92);
    final fallbackMediaColor = theme.brightness == Brightness.dark
        ? const Color(0xFF374151)
        : colorScheme.surfaceContainerHighest;

    const width = 1080.0;
    const height = 1920.0;

    return SizedBox(
      width: width,
      height: height,
      child: ColoredBox(
        color: scaffoldColor,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Media section (35%)
                Expanded(
                  flex: 35,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (imageUrl != null && imageUrl.isNotEmpty)
                        Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => ColoredBox(
                            color: fallbackMediaColor,
                            child: Center(
                              child: Icon(
                                Icons.image,
                                size: 80,
                                color: onSurfaceVariant.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        )
                      else
                        ColoredBox(
                          color: fallbackMediaColor,
                          child: Center(
                            child: Icon(
                              Icons.image,
                              size: 80,
                              color: onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      if (isVideo)
                        Center(
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: playBadgeColor,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.play_arrow_rounded,
                              size: 60,
                              color: onSurface,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Content section (65%)
                Expanded(
                  flex: 65,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(40, 28, 40, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: Category + Source
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _formatCategory(category),
                                style: TextStyle(
                                  color: primaryColor,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            const SizedBox(width: 28),
                            Expanded(
                              child: Text(
                                source,
                                style: TextStyle(
                                  color: onSurfaceVariant,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        // Title
                        Text(
                          title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: onSurface,
                            fontSize: 44,
                            fontWeight: FontWeight.bold,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Summary
                        Expanded(
                          child: Text(
                            summary,
                            style: TextStyle(
                              color: onSurfaceVariant,
                              fontSize: 34,
                              height: 1.4,
                            ),
                            overflow: TextOverflow.fade,
                          ),
                        ),
                        // Divider
                        Divider(
                          color: dividerColor,
                          height: 1,
                        ),
                        // Footer
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 32,
                                color: onSurfaceVariant,
                              ),
                              const SizedBox(width: 14),
                              Text(
                                date,
                                style: TextStyle(
                                  color: onSurfaceVariant,
                                  fontSize: 30,
                                ),
                              ),
                              const SizedBox(width: 36),
                              Icon(
                                Icons.access_time,
                                size: 32,
                                color: onSurfaceVariant,
                              ),
                              const SizedBox(width: 14),
                              Text(
                                readTime,
                                style: TextStyle(
                                  color: onSurfaceVariant,
                                  fontSize: 30,
                                ),
                              ),
                              const Spacer(),
                              // Blips branding
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.asset(
                                      'assets/icon/app_icon.png',
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Text(
                                    'Blips News',
                                    style: TextStyle(
                                      color: onSurface,
                                      fontSize: 32,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatCategory(String cat) {
    if (cat == 'Artificial Intelligence') return 'AI';
    return cat.toUpperCase();
  }

  String _composeShareText({
    required String url,
    String? title,
  }) {
    final buffer = StringBuffer();
    if (title != null && title.isNotEmpty) {
      buffer
        ..writeln(title)
        ..writeln();
    }
    buffer
      ..writeln(url)
      ..writeln()
      ..write(_shareAttribution);
    return buffer.toString();
  }

  /// Shares an image with URL.
  Future<void> _shareWithImage({
    required Uint8List imageBytes,
    required String url,
    required String subject,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = path.join(tempDir.path, 'blips_share_$timestamp.png');

      final file = File(filePath);
      await file.writeAsBytes(imageBytes);
      debugPrint(
        'ShareService: Saved image to $filePath '
        '(${imageBytes.length} bytes)',
      );

      await _sharePlus.share(
        ShareParams(
          files: [XFile(filePath)],
          text: _composeShareText(url: url, title: subject),
          title: subject,
          subject: subject,
        ),
      );

      // Cleanup after delay
      Future.delayed(const Duration(seconds: 10), () {
        try {
          if (file.existsSync()) file.deleteSync();
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('ShareService: Error sharing with image: $e');
      await _shareTextOnly(
        text: _composeShareText(url: url, title: subject),
        subject: subject,
      );
    }
  }

  /// Shares text only (fallback).
  Future<void> _shareTextOnly({
    required String text,
    required String subject,
  }) async {
    try {
      await _sharePlus.share(
        ShareParams(
          text: text,
          subject: subject,
        ),
      );
    } catch (e) {
      debugPrint('ShareService: Error sharing text: $e');
    }
  }
}
