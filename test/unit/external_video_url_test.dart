@Tags(['unit'])
library external_video_url_test;

import 'package:blips_mobile/features/feed/domain/external_video_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolvePreferredExternalVideoUri', () {
    test('prefers canonical YouTube watch URL from playable video URL', () {
      final uri = resolvePreferredExternalVideoUri(
        sourceUrl: 'https://www.theverge.com/2026/03/20/video-story',
        videoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=120',
      );

      expect(
        uri?.toString(),
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      );
    });

    test('preserves shorts surface for reels', () {
      final uri = resolvePreferredExternalVideoUri(
        sourceUrl: 'https://twitter.com/some/status/123',
        videoUrl: 'https://m.youtube.com/shorts/jcxgwl9NYFE',
        preferShorts: true,
      );

      expect(
        uri?.toString(),
        'https://www.youtube.com/shorts/jcxgwl9NYFE',
      );
    });

    test('falls back to source URL when no YouTube URL is available', () {
      final uri = resolvePreferredExternalVideoUri(
        sourceUrl: 'https://www.theverge.com/2026/03/20/video-story',
        videoUrl: 'https://cdn.example.com/video.mp4',
      );

      expect(
        uri?.toString(),
        'https://www.theverge.com/2026/03/20/video-story',
      );
    });
  });
}
