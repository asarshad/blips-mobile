import 'package:blips_mobile/features/feed/data/dto/article_dto.dart';
import 'package:blips_mobile/features/feed/data/dto/video_dto.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:dio/dio.dart';

/// Repository responsible for loading feed items from the backend.
class FeedRepository {
  /// Creates the repository with the provided [Dio] client.
  const FeedRepository(this._dio);

  final Dio _dio;

  /// Fetches both recent articles and videos, merging them into one list.
  Future<List<FeedEntry>> fetchFeed({
    int articleLimit = 15,
    int videoLimit = 10,
  }) async {
    final articlesFuture = _dio.get<Map<String, dynamic>>(
      '/articles/recent',
      queryParameters: {'limit': articleLimit},
    );
    final videosFuture = _dio.get<Map<String, dynamic>>(
      '/videos/recent',
      queryParameters: {'limit': videoLimit},
    );

    final responses = await Future.wait([articlesFuture, videosFuture]);
    final articlesJson =
        responses[0].data?['articles'] as List<dynamic>? ?? const [];
    final videosJson =
        responses[1].data?['videos'] as List<dynamic>? ?? const [];

    final articles = articlesJson
        .cast<Map<String, dynamic>>()
        .map(ArticleDto.fromJson)
        .map((dto) => dto.toDomain());
    final videos = videosJson
        .cast<Map<String, dynamic>>()
        .map(VideoDto.fromJson)
        .map((dto) => dto.toDomain());

    return [...articles, ...videos]
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
  }
}
