import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Service for capturing and sharing feed content.
///
/// Uses Flutter's native rendering (RepaintBoundary + overlay) to capture
/// widgets as images. The captured image is shared along with the content URL.
class ShareService {
  ShareService._();

  static final ShareService instance = ShareService._();

  bool _isSharing = false;

  /// Shares an article with a screenshot and URL.
  Future<void> shareArticle({
    required BuildContext context,
    required String title,
    required String summary,
    required String source,
    required String category,
    required String date,
    required String readTime,
    required String imageUrl,
    required String articleUrl,
  }) async {
    if (_isSharing) return;
    _isSharing = true;

    try {
      debugPrint('ShareService: Starting article share for "$title"');

      final imageBytes = await _captureShareCard(
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
          text: '$title\n\n$articleUrl',
          subject: title,
        );
      }
    } catch (e, stack) {
      debugPrint('ShareService: Error sharing article: $e');
      debugPrint('Stack: $stack');
      await _shareTextOnly(
        text: '$title\n\n$articleUrl',
        subject: title,
      );
    } finally {
      _isSharing = false;
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
    if (_isSharing) return;
    _isSharing = true;

    try {
      debugPrint('ShareService: Starting video share for "$title"');

      final imageBytes = await _captureShareCard(
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
          text: '$title\n\n$videoUrl',
          subject: title,
        );
      }
    } catch (e, stack) {
      debugPrint('ShareService: Error sharing video: $e');
      debugPrint('Stack: $stack');
      await _shareTextOnly(
        text: '$title\n\n$videoUrl',
        subject: title,
      );
    } finally {
      _isSharing = false;
    }
  }

  /// Shares a reel with URL only (no screenshot).
  Future<void> shareReel({
    required String title,
    required String videoUrl,
  }) async {
    if (_isSharing) return;
    _isSharing = true;

    try {
      debugPrint('ShareService: Sharing reel "$title"');
      await _shareTextOnly(
        text: videoUrl,
        subject: title,
      );
    } finally {
      _isSharing = false;
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
    required String imageUrl,
    required bool isVideo,
  }) async {
    final completer = Completer<Uint8List?>();
    final boundaryKey = GlobalKey();
    OverlayEntry? overlayEntry;

    try {
      // Pre-cache the network image
      debugPrint('ShareService: Pre-caching image: $imageUrl');
      final imageProvider = NetworkImage(imageUrl);
      await precacheImage(imageProvider, context);
      debugPrint('ShareService: Image cached');

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
                  title: title,
                  summary: summary,
                  source: source,
                  category: category,
                  date: date,
                  readTime: readTime,
                  imageUrl: imageUrl,
                  isVideo: isVideo,
                ),
              ),
            ),
          );
        },
      );

      // Insert overlay
      Overlay.of(context).insert(overlayEntry);
      debugPrint('ShareService: Overlay inserted');

      // Wait for rendering and image loading
      await Future<void>.delayed(const Duration(milliseconds: 800));

      // Capture the boundary
      final boundary = boundaryKey.currentContext?.findRenderObject();
      if (boundary is RenderRepaintBoundary) {
        debugPrint('ShareService: Found RepaintBoundary, capturing...');
        final image = await boundary.toImage(pixelRatio: 1.0);
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
    required String title,
    required String summary,
    required String source,
    required String category,
    required String date,
    required String readTime,
    required String imageUrl,
    required bool isVideo,
  }) {
    // Match the app's dark theme colors exactly from app.dart
    const scaffoldColor = Color(0xFF0F172A);
    const cardColor = Color(0xFF1E293B);
    const primaryColor = Color(0xFF0E7490);
    const onSurface = Colors.white;
    final onSurfaceVariant = Colors.white.withValues(alpha: 0.7);

    const width = 1080.0;
    const height = 1920.0;

    return SizedBox(
      width: width,
      height: height,
      child: Container(
        color: scaffoldColor,
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
                    Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF374151),
                        child: const Center(
                          child: Icon(Icons.image,
                              size: 80, color: Colors.white38),
                        ),
                      ),
                    ),
                    if (isVideo)
                      Center(
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.play_arrow_rounded,
                            size: 60,
                            color: cardColor,
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
                              style: const TextStyle(
                                color: primaryColor,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
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
                        style: const TextStyle(
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
                        color: Colors.white.withValues(alpha: 0.1),
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
                                const Text(
                                  'Blips News',
                                  style: TextStyle(
                                    color: Colors.white,
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
    );
  }

  String _formatCategory(String cat) {
    if (cat == 'Artificial Intelligence') return 'AI';
    return cat.toUpperCase();
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
          'ShareService: Saved image to $filePath (${imageBytes.length} bytes)');

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath)],
          text: url,
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
      await _shareTextOnly(text: url, subject: subject);
    }
  }

  /// Shares text only (fallback).
  Future<void> _shareTextOnly({
    required String text,
    required String subject,
  }) async {
    try {
      await SharePlus.instance.share(
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
