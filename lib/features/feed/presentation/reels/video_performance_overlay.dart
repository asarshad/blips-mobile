import 'package:blips_mobile/features/feed/providers/optimized_video_provider.dart';
import 'package:flutter/material.dart';

/// Performance overlay for debugging video playback.
///
/// Only shown in debug mode.
class VideoPerformanceOverlay extends StatelessWidget {
  /// Creates a performance overlay.
  const VideoPerformanceOverlay({
    required this.videoManager,
    super.key,
  });

  /// The video manager to get metrics from.
  final OptimizedVideoPlayerManager videoManager;

  @override
  Widget build(BuildContext context) {
    final avgTime = videoManager.averageTimeToFirstFrame;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 8,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Video Performance',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Avg TTFF: ${avgTime?.inMilliseconds ?? '-'}ms',
              style: TextStyle(
                color: avgTime != null && avgTime.inMilliseconds < 200
                    ? Colors.greenAccent
                    : Colors.orangeAccent,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
