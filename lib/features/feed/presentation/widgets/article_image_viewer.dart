import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

class ArticleImageViewer extends StatefulWidget {
  const ArticleImageViewer({
    super.key,
    required this.imageUrl,
    required this.heroTag,
  });

  final String imageUrl;
  final Object heroTag;

  static Future<void> show(
    BuildContext context, {
    required String imageUrl,
    required Object heroTag,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => ArticleImageViewer(
          imageUrl: imageUrl,
          heroTag: heroTag,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final fade = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(opacity: fade, child: child);
        },
      ),
    );
  }

  @override
  State<ArticleImageViewer> createState() => _ArticleImageViewerState();
}

class _ArticleImageViewerState extends State<ArticleImageViewer> {
  static const double _dismissDistance = 140;
  static const double _dismissVelocity = 1000;

  double _verticalOffset = 0;
  bool _isDismissEnabled = true;

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (!_isDismissEnabled) return;
    setState(() {
      _verticalOffset += details.delta.dy;
    });
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    if (!_isDismissEnabled) return;
    final shouldDismiss = _verticalOffset.abs() > _dismissDistance ||
        details.velocity.pixelsPerSecond.dy.abs() > _dismissVelocity;
    if (shouldDismiss) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _verticalOffset = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dragProgress = (_verticalOffset.abs() / 240).clamp(0.0, 1.0);
    final backgroundOpacity = 1 - (dragProgress * 0.45);
    final scale = math.max(0.92, 1 - (dragProgress * 0.05));

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: backgroundOpacity),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                key: const Key('article-image-viewer-drag-area'),
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: _handleVerticalDragUpdate,
                onVerticalDragEnd: _handleVerticalDragEnd,
                child: Center(
                  child: Transform.translate(
                    offset: Offset(0, _verticalOffset),
                    child: Transform.scale(
                      scale: scale,
                      child: PhotoView(
                        imageProvider: NetworkImage(widget.imageUrl),
                        heroAttributes:
                            PhotoViewHeroAttributes(tag: widget.heroTag),
                        minScale: PhotoViewComputedScale.contained,
                        initialScale: PhotoViewComputedScale.contained,
                        maxScale: PhotoViewComputedScale.covered * 3,
                        backgroundDecoration:
                            const BoxDecoration(color: Colors.transparent),
                        loadingBuilder: (context, event) => const SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            color: Colors.white70,
                            strokeWidth: 2.5,
                          ),
                        ),
                        errorBuilder: (context, error, stackTrace) =>
                            const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            'Unable to load image.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        scaleStateChangedCallback: (scaleState) {
                          final shouldEnableDismiss =
                              scaleState == PhotoViewScaleState.initial;
                          if (shouldEnableDismiss != _isDismissEnabled &&
                              mounted) {
                            setState(() {
                              _isDismissEnabled = shouldEnableDismiss;
                              if (shouldEnableDismiss && _verticalOffset != 0) {
                                _verticalOffset = 0;
                              }
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  key: const Key('article-image-viewer-close'),
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close_rounded),
                  color: Colors.white,
                  tooltip: 'Close image',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
