import 'dart:io';

import 'package:blips_mobile/features/share/share_card_renderer.dart';
import 'package:blips_mobile/features/share/share_models.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// Service for sharing articles, videos, and reels.
///
/// Public API:
/// - [shareArticle] - Share article with 9:16 card image + URL
/// - [shareVideo] - Share video with 9:16 card image + URL
/// - [shareReel] - Share reel URL only (no image)
///
/// All methods handle errors gracefully and fall back to URL-only sharing
/// if image generation fails.
class ShareService {
  ShareService._();

  static final ShareService instance = ShareService._();

  final _renderer = ShareCardRenderer.instance;

  bool _isSharing = false;

  /// Shares an article with a 9:16 card image and source URL.
  ///
  /// Falls back to URL-only sharing if image generation fails.
  Future<BlipsShareResult> shareArticle(ArticleShareData data) async {
    if (_isSharing) {
      return const BlipsShareError('Share already in progress');
    }

    _isSharing = true;
    try {
      debugPrint('ShareService: Sharing article "${data.title}"');

      // Try to render the card
      final imagePath = await _renderer.renderArticleCard(data);

      // Share with image if available, otherwise fallback to text
      if (imagePath != null) {
        return _shareWithImage(
          imagePath: imagePath,
          text: data.sourceUrl,
          subject: data.title,
        );
      } else {
        debugPrint('ShareService: Falling back to URL-only share');
        return _shareTextOnly(
          text: '${data.title}\n\n${data.sourceUrl}',
          subject: data.title,
        );
      }
    } catch (e) {
      debugPrint('ShareService: Error sharing article: $e');
      // Final fallback
      return _shareTextOnly(
        text: data.sourceUrl,
        subject: data.title,
      );
    } finally {
      _isSharing = false;
    }
  }

  /// Shares a video with a 9:16 card image and video URL.
  ///
  /// Falls back to URL-only sharing if image generation fails.
  Future<BlipsShareResult> shareVideo(VideoShareData data) async {
    if (_isSharing) {
      return const BlipsShareError('Share already in progress');
    }

    _isSharing = true;
    try {
      debugPrint('ShareService: Sharing video "${data.title}"');

      // Try to render the card
      final imagePath = await _renderer.renderVideoCard(data);

      // Share with image if available, otherwise fallback to text
      if (imagePath != null) {
        return _shareWithImage(
          imagePath: imagePath,
          text: data.videoUrl,
          subject: data.title,
        );
      } else {
        debugPrint('ShareService: Falling back to URL-only share');
        return _shareTextOnly(
          text: '${data.title}\n\n${data.videoUrl}',
          subject: data.title,
        );
      }
    } catch (e) {
      debugPrint('ShareService: Error sharing video: $e');
      // Final fallback
      return _shareTextOnly(
        text: data.videoUrl,
        subject: data.title,
      );
    } finally {
      _isSharing = false;
    }
  }

  /// Shares a reel with URL only (no image).
  Future<BlipsShareResult> shareReel(ReelShareData data) async {
    if (_isSharing) {
      return const BlipsShareError('Share already in progress');
    }

    _isSharing = true;
    try {
      debugPrint('ShareService: Sharing reel "${data.title}"');
      return _shareTextOnly(
        text: data.videoUrl,
        subject: data.title,
      );
    } finally {
      _isSharing = false;
    }
  }

  /// Shares an image file with accompanying text.
  Future<BlipsShareResult> _shareWithImage({
    required String imagePath,
    required String text,
    required String subject,
  }) async {
    try {
      final file = File(imagePath);
      if (!file.existsSync()) {
        debugPrint('ShareService: Image file not found: $imagePath');
        return _shareTextOnly(text: text, subject: subject);
      }

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(imagePath)],
          text: text,
          subject: subject,
        ),
      );

      // Schedule cleanup
      _scheduleCleanup(imagePath);

      return const BlipsShareSuccess();
    } catch (e) {
      debugPrint('ShareService: Error sharing with image: $e');
      return BlipsShareError(e.toString());
    }
  }

  /// Shares text only (fallback).
  Future<BlipsShareResult> _shareTextOnly({
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
      return const BlipsShareSuccess();
    } catch (e) {
      debugPrint('ShareService: Error sharing text: $e');
      return BlipsShareError(e.toString());
    }
  }

  /// Schedules cleanup of temporary image file.
  void _scheduleCleanup(String path) {
    Future.delayed(const Duration(seconds: 10), () {
      try {
        final file = File(path);
        if (file.existsSync()) {
          file.deleteSync();
          debugPrint('ShareService: Cleaned up $path');
        }
      } catch (e) {
        debugPrint('ShareService: Cleanup error: $e');
      }
    });
  }
}
