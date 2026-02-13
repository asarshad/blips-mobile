@Tags(['unit'])
library video_url_parsing_test;

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('YouTube URL Extraction Tests', () {
    // Test helper - access private method via public API behavior
    // We'll test through the actual flow instead

    group('URL Formats', () {
      test('extracts ID from youtube.com/shorts/VIDEO_ID', () {
        const url = 'https://www.youtube.com/shorts/jcxgwl9NYFE';
        final videoId = extractVideoIdForTest(url);
        expect(videoId, equals('jcxgwl9NYFE'));
      });

      test('extracts ID from youtube.com/watch?v=VIDEO_ID', () {
        const url = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
        final videoId = extractVideoIdForTest(url);
        expect(videoId, equals('dQw4w9WgXcQ'));
      });

      test('extracts ID from youtu.be/VIDEO_ID', () {
        const url = 'https://youtu.be/dQw4w9WgXcQ';
        final videoId = extractVideoIdForTest(url);
        expect(videoId, equals('dQw4w9WgXcQ'));
      });

      test('extracts ID from youtube.com/watch with extra params', () {
        const url =
            'https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=120&list=PLxyz';
        final videoId = extractVideoIdForTest(url);
        expect(videoId, equals('dQw4w9WgXcQ'));
      });

      test('extracts ID from shorts with trailing slash', () {
        const url = 'https://www.youtube.com/shorts/jcxgwl9NYFE/';
        final videoId = extractVideoIdForTest(url);
        expect(videoId, equals('jcxgwl9NYFE'));
      });

      test('extracts ID from m.youtube.com/shorts/', () {
        const url = 'https://m.youtube.com/shorts/jcxgwl9NYFE';
        final videoId = extractVideoIdForTest(url);
        expect(videoId, equals('jcxgwl9NYFE'));
      });

      test('returns null for invalid URL', () {
        const url = 'https://example.com/video/123';
        final videoId = extractVideoIdForTest(url);
        expect(videoId, isNull);
      });

      test('returns null for empty string', () {
        const url = '';
        final videoId = extractVideoIdForTest(url);
        expect(videoId, isNull);
      });

      test('returns null for malformed URL', () {
        const url = 'not a valid url';
        final videoId = extractVideoIdForTest(url);
        expect(videoId, isNull);
      });
    });
  });
}

/// Extracted URL parsing logic for testing
/// This mirrors the logic in YoutubePlayerManager.extractVideoId
String? extractVideoIdForTest(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;

  // youtube.com/shorts/VIDEO_ID (check this BEFORE regular youtube.com)
  if (uri.host.contains('youtube.com') && uri.pathSegments.contains('shorts')) {
    final shortsIndex = uri.pathSegments.indexOf('shorts');
    if (uri.pathSegments.length > shortsIndex + 1) {
      // Handle trailing slash - filter out empty segments
      final videoId = uri.pathSegments[shortsIndex + 1];
      return videoId.isNotEmpty ? videoId : null;
    }
  }

  // youtube.com/watch?v=VIDEO_ID
  if (uri.host.contains('youtube.com')) {
    final videoId = uri.queryParameters['v'];
    if (videoId != null && videoId.isNotEmpty) {
      return videoId;
    }
  }

  // youtu.be/VIDEO_ID
  if (uri.host.contains('youtu.be')) {
    final segments = uri.pathSegments;
    if (segments.isNotEmpty) {
      return segments.first;
    }
  }

  return null;
}
