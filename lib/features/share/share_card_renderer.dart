import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:blips_mobile/features/share/share_card.dart';
import 'package:blips_mobile/features/share/share_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Renders share cards off-screen and captures them as PNG images.
///
/// This class uses Canvas-based rendering to create share card images
/// without affecting the visible UI.
class ShareCardRenderer {
  ShareCardRenderer._();

  static final ShareCardRenderer instance = ShareCardRenderer._();

  /// Renders an article share card and returns the file path.
  ///
  /// Returns null if rendering fails.
  Future<String?> renderArticleCard(ArticleShareData data) async {
    return _renderCard(
      title: data.title,
      summary: data.summary,
      sourceName: data.sourceName,
      isVideo: false,
      prefix: 'article',
    );
  }

  /// Renders a video share card and returns the file path.
  ///
  /// Returns null if rendering fails.
  Future<String?> renderVideoCard(VideoShareData data) async {
    return _renderCard(
      title: data.title,
      summary: data.summary,
      sourceName: data.channelName,
      isVideo: true,
      prefix: 'video',
    );
  }

  /// Internal method to render a card using Canvas.
  Future<String?> _renderCard({
    required String title,
    required String summary,
    required String sourceName,
    required bool isVideo,
    required String prefix,
  }) async {
    try {
      const width = ShareCard.renderWidth;
      const height = ShareCard.renderHeight;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Background gradient
      final bgPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1A2E), Color(0xFF0F0F1A)],
        ).createShader(const Rect.fromLTWH(0, 0, width, height));

      canvas.drawRect(const Rect.fromLTWH(0, 0, width, height), bgPaint);

      // Image placeholder area (top 40%)
      final imagePaint = Paint()..color = const Color(0xFF2A2A4A);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, width, height * 0.4),
        imagePaint,
      );

      // Gradient overlay on image area
      final overlayPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.6),
          ],
          stops: const [0.5, 1.0],
        ).createShader(const Rect.fromLTWH(0, 0, width, height * 0.4));
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, width, height * 0.4),
        overlayPaint,
      );

      // Video play icon
      if (isVideo) {
        final playBgPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.9);
        canvas.drawCircle(
          const Offset(width / 2, height * 0.2),
          60,
          playBgPaint,
        );

        // Draw play triangle
        final playPath = Path()
          ..moveTo(width / 2 - 20, height * 0.2 - 30)
          ..lineTo(width / 2 - 20, height * 0.2 + 30)
          ..lineTo(width / 2 + 30, height * 0.2)
          ..close();
        final playPaint = Paint()..color = const Color(0xFF1A1A2E);
        canvas.drawPath(playPath, playPaint);
      }

      // Source badge
      final badgeRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(48, height * 0.4 + 48, 200, 44),
        const Radius.circular(8),
      );
      final badgePaint = Paint()..color = const Color(0xFF6366F1);
      canvas.drawRRect(badgeRect, badgePaint);

      final sourcePainter = TextPainter(
        text: TextSpan(
          text: sourceName.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 180);
      sourcePainter.paint(
        canvas,
        Offset(48 + (200 - sourcePainter.width) / 2, height * 0.4 + 56),
      );

      // Title
      final titlePainter = TextPainter(
        text: TextSpan(
          text: title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 56,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '...',
      )..layout(maxWidth: width - 96);
      titlePainter.paint(canvas, Offset(48, height * 0.4 + 120));

      // Summary
      final summaryPainter = TextPainter(
        text: TextSpan(
          text: summary,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 36,
            height: 1.5,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 6,
        ellipsis: '...',
      )..layout(maxWidth: width - 96);
      summaryPainter.paint(canvas, Offset(48, height * 0.4 + 120 + titlePainter.height + 24));

      // Footer separator
      final separatorPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.1)
        ..strokeWidth = 1;
      canvas.drawLine(
        const Offset(0, height - 140),
        const Offset(width, height - 140),
        separatorPaint,
      );

      // App icon placeholder
      final iconRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(48, height - 100, 60, 60),
        const Radius.circular(12),
      );
      final iconPaint = Paint()..color = const Color(0xFF6366F1);
      canvas.drawRRect(iconRect, iconPaint);

      // "B" in icon
      final iconTextPainter = TextPainter(
        text: const TextSpan(
          text: 'B',
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      iconTextPainter.paint(
        canvas,
        Offset(48 + (60 - iconTextPainter.width) / 2, height - 100 + (60 - iconTextPainter.height) / 2),
      );

      // "Blips" text
      final brandPainter = TextPainter(
        text: const TextSpan(
          text: 'Blips',
          style: TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      brandPainter.paint(canvas, Offset(128, height - 85));

      // Tagline
      final taglinePainter = TextPainter(
        text: TextSpan(
          text: 'Your AI News Feed',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 24,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      taglinePainter.paint(
        canvas,
        Offset(width - 48 - taglinePainter.width, height - 80),
      );

      // End recording
      final picture = recorder.endRecording();
      final image = await picture.toImage(width.toInt(), height.toInt());

      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        debugPrint('ShareCardRenderer: Failed to get byte data');
        return null;
      }

      // Save to temp file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = path.join(
        tempDir.path,
        'blips_share_${prefix}_$timestamp.png',
      );

      final file = File(filePath);
      await file.writeAsBytes(byteData.buffer.asUint8List());

      debugPrint('ShareCardRenderer: Saved card to $filePath');
      return filePath;
    } catch (e, stack) {
      debugPrint('ShareCardRenderer: Error rendering card: $e');
      debugPrint('Stack: $stack');
      return null;
    }
  }

  /// Cleans up old share card images from temp directory.
  Future<void> cleanupOldCards() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final files = tempDir.listSync().whereType<File>();

      for (final file in files) {
        if (path.basename(file.path).startsWith('blips_share_')) {
          final stat = file.statSync();
          final age = DateTime.now().difference(stat.modified);
          if (age.inHours >= 1) {
            file.deleteSync();
          }
        }
      }
    } catch (e) {
      debugPrint('ShareCardRenderer: Cleanup error: $e');
    }
  }
}
