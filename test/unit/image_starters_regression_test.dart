@Tags(['unit'])
library image_starters_regression_test;

import 'package:blips_mobile/features/feed/data/dto/article_dto.dart';
import 'package:blips_mobile/features/feed/data/dto/video_dto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression tests for two production incidents:
/// 1. Broken article images — empty-string image_url bypassed null fallback
/// 2. Default conversation starters — article-specific starters never shown

void main() {
  group('Image URL regression', () {
    test('empty string image_url becomes null in ArticleDto', () {
      final dto = ArticleDto.fromJson(const {
        'id': 1,
        'title': 'Test Article',
        'source_url': 'https://example.com',
        'image_url': '',
        'tags': <dynamic>[],
      });

      expect(dto.imageUrl, isNull,
          reason: 'Empty string image_url should be coerced to null');
    });

    test('whitespace-only image_url becomes null in ArticleDto', () {
      final dto = ArticleDto.fromJson(const {
        'id': 2,
        'title': 'Test Article',
        'source_url': 'https://example.com',
        'image_url': '   ',
        'tags': <dynamic>[],
      });

      expect(dto.imageUrl, isNull,
          reason: 'Whitespace-only image_url should be coerced to null');
    });

    test('null image_url stays null in ArticleDto', () {
      final dto = ArticleDto.fromJson(const {
        'id': 3,
        'title': 'Test Article',
        'source_url': 'https://example.com',
        'image_url': null,
        'tags': <dynamic>[],
      });

      expect(dto.imageUrl, isNull);
    });

    test('valid image_url is preserved in ArticleDto', () {
      final dto = ArticleDto.fromJson(const {
        'id': 4,
        'title': 'Test Article',
        'source_url': 'https://example.com',
        'image_url': 'https://example.com/img.jpg',
        'tags': <dynamic>[],
      });

      expect(dto.imageUrl, equals('https://example.com/img.jpg'));
    });

    test('ArticleDto.toDomain() preserves null image_url for the UI renderer',
        () {
      final dto = ArticleDto.fromJson(const {
        'id': 5,
        'title': 'Test Article',
        'source_url': 'https://example.com',
        'image_url': '',
        'tags': [
          {'name': 'Technology'},
        ],
      });

      final entry = dto.toDomain();
      expect(entry.imageUrl, isNull,
          reason:
              'Missing article images should stay null until the UI decides how to render them.');
    });

    test('empty string thumbnail_url becomes null in VideoDto', () {
      final dto = VideoDto.fromJson(const {
        'id': 10,
        'title': 'Test Video',
        'video_url': 'https://youtube.com/watch?v=abc',
        'source_url': 'https://youtube.com/watch?v=abc',
        'thumbnail_url': '',
      });

      expect(dto.thumbnailUrl, isNull,
          reason: 'Empty string thumbnail_url should be coerced to null');
    });

    test('valid thumbnail_url is preserved in VideoDto', () {
      final dto = VideoDto.fromJson(const {
        'id': 11,
        'title': 'Test Video',
        'video_url': 'https://youtube.com/watch?v=abc',
        'source_url': 'https://youtube.com/watch?v=abc',
        'thumbnail_url': 'https://img.youtube.com/vi/abc/maxresdefault.jpg',
      });

      expect(dto.thumbnailUrl,
          equals('https://img.youtube.com/vi/abc/maxresdefault.jpg'));
    });
  });

  group('Conversation starters regression', () {
    test('empty dict conversation_starters returns empty list', () {
      final dto = ArticleDto.fromJson(const {
        'id': 20,
        'title': 'Test',
        'source_url': 'https://example.com',
        'conversation_starters': <String, dynamic>{},
        'tags': <dynamic>[],
      });

      expect(dto.conversationStarters, isEmpty);
    });

    test('null conversation_starters returns empty list', () {
      final dto = ArticleDto.fromJson(const {
        'id': 21,
        'title': 'Test',
        'source_url': 'https://example.com',
        'conversation_starters': null,
        'tags': <dynamic>[],
      });

      expect(dto.conversationStarters, isEmpty);
    });

    test('valid starters are parsed from nested structure', () {
      final dto = ArticleDto.fromJson(const {
        'id': 22,
        'title': 'Test',
        'source_url': 'https://example.com',
        'conversation_starters': {
          'starters': [
            'What are the implications?',
            'How does this affect users?',
            'What tech is involved?',
          ],
          'fallback': ['General question 1'],
        },
        'tags': <dynamic>[],
      });

      expect(dto.conversationStarters, hasLength(3));
      expect(
          dto.conversationStarters.first, equals('What are the implications?'));
    });

    test('starters with empty strings are filtered out', () {
      final dto = ArticleDto.fromJson(const {
        'id': 23,
        'title': 'Test',
        'source_url': 'https://example.com',
        'conversation_starters': {
          'starters': ['Valid question?', '', '   ', 'Another question?'],
        },
        'tags': <dynamic>[],
      });

      expect(dto.conversationStarters, hasLength(2));
      expect(dto.conversationStarters,
          equals(['Valid question?', 'Another question?']));
    });

    test('title-based starters from backend are parsed correctly', () {
      // This tests the serving-time fallback format from _default_starters_for
      final dto = ArticleDto.fromJson(const {
        'id': 24,
        'title': 'Test',
        'source_url': 'https://example.com',
        'conversation_starters': {
          'starters': [
            "What are the implications of 'New AI Breakthrough'?",
            'Can you break down the key points?',
            'How does this compare to similar developments?',
          ],
          'fallback': [
            'What are the main points of this?',
            'Can you summarize this for me?',
          ],
        },
        'tags': <dynamic>[],
      });

      expect(dto.conversationStarters, hasLength(3));
      expect(dto.conversationStarters.first, contains('implications'));
    });

    test('video conversation starters parsed the same as articles', () {
      final dto = VideoDto.fromJson(const {
        'id': 30,
        'title': 'Test Video',
        'video_url': 'https://youtube.com/watch?v=abc',
        'source_url': 'https://youtube.com/watch?v=abc',
        'conversation_starters': {
          'starters': ['Video specific question?', 'Another one?'],
        },
      });

      expect(dto.conversationStarters, hasLength(2));
    });
  });
}
