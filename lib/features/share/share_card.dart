import 'dart:async';

import 'package:flutter/material.dart';

/// Pure presentational widget for 9:16 share cards.
///
/// This widget is designed for OFF-SCREEN rendering only.
/// It contains NO buttons, gestures, or interactive elements.
///
/// Layout:
/// - Hero image (top 40%)
/// - Title (max 2 lines)
/// - Summary (flexible, ~6 lines max)
/// - Source name
/// - Footer branding with Blips logo
class ShareCard extends StatelessWidget {
  const ShareCard({
    super.key,
    required this.title,
    required this.summary,
    required this.sourceName,
    required this.imageUrl,
    this.isVideo = false,
  });

  /// Content title.
  final String title;

  /// Content summary.
  final String summary;

  /// Source or channel name.
  final String sourceName;

  /// Hero image or thumbnail URL.
  final String imageUrl;

  /// Whether this is a video card (shows play icon overlay).
  final bool isVideo;

  /// Aspect ratio for 9:16 cards.
  static const double aspectRatio = 9 / 16;

  /// Logical width for rendering.
  static const double renderWidth = 1080;

  /// Logical height for rendering (9:16).
  static const double renderHeight = 1920;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: renderWidth,
      height: renderHeight,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1A1A2E),
            Color(0xFF0F0F1A),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero image (40% of height)
          SizedBox(
            height: renderHeight * 0.4,
            child: _HeroImage(
              imageUrl: imageUrl,
              isVideo: isVideo,
            ),
          ),

          // Content area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Source badge
                  _SourceBadge(sourceName: sourceName),
                  const SizedBox(height: 32),

                  // Title
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Summary
                  Expanded(
                    child: Text(
                      summary,
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 36,
                        height: 1.5,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Footer branding
          const _BrandingFooter(),
        ],
      ),
    );
  }
}

/// Hero image with optional video play overlay.
class _HeroImage extends StatelessWidget {
  const _HeroImage({
    required this.imageUrl,
    required this.isVideo,
  });

  final String imageUrl;
  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Image
        _NetworkImageWithFallback(imageUrl: imageUrl),

        // Gradient overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.6),
              ],
              stops: const [0.5, 1.0],
            ),
          ),
        ),

        // Video play icon
        if (isVideo)
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                size: 80,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ),
      ],
    );
  }
}

/// Network image with fallback placeholder.
class _NetworkImageWithFallback extends StatelessWidget {
  const _NetworkImageWithFallback({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: const Color(0xFF2A2A4A),
        child: const Center(
          child: Icon(
            Icons.image_outlined,
            size: 100,
            color: Colors.white38,
          ),
        ),
      ),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: const Color(0xFF2A2A4A),
          child: const Center(
            child: CircularProgressIndicator(
              color: Colors.white38,
              strokeWidth: 3,
            ),
          ),
        );
      },
    );
  }
}

/// Source name badge.
class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.sourceName});

  final String sourceName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        sourceName.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

/// Footer with Blips branding.
class _BrandingFooter extends StatelessWidget {
  const _BrandingFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      padding: const EdgeInsets.symmetric(horizontal: 48),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          // App icon placeholder
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'B',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),

          // App name
          const Text(
            'Blips',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),

          const Spacer(),

          // Tagline
          Text(
            'Your AI News Feed',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 24,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

/// Loads an image from URL and returns when ready.
///
/// Used to pre-load images before rendering share cards.
Future<bool> preloadImage(String url) async {
  try {
    final completer = Completer<bool>();
    final provider = NetworkImage(url);

    final stream = provider.resolve(ImageConfiguration.empty);
    stream.addListener(
      ImageStreamListener(
        (_, __) => completer.complete(true),
        onError: (_, __) => completer.complete(false),
      ),
    );

    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => false,
    );
  } catch (_) {
    return false;
  }
}
