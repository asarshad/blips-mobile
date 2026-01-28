import 'package:blips_mobile/core/error/error.dart';
import 'package:blips_mobile/core/network/backend_api_client.dart';
import 'package:blips_mobile/features/feed/data/dto/article_dto.dart';
import 'package:blips_mobile/features/feed/data/dto/video_dto.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:dio/dio.dart';

/// Repository responsible for loading feed items from the backend.
class FeedRepository {
  /// Creates the repository with the provided API client.
  const FeedRepository(this._api);

  final BackendApiClient _api;

  /// Fetches both recent articles and videos, merging them into one list.
  ///
  /// Throws [NetworkException] on network errors.
  /// Throws [DataException] on parsing errors.
  Future<List<FeedEntry>> fetchFeed({
    int articleLimit = 15,
    int videoLimit = 10,
    int page = 1,
  }) async {
    try {
      final articlesFuture = _api.get(
        '/articles/recent',
        queryParameters: {
          'limit': articleLimit,
          'page': page,
        },
      );
      final videosFuture = _api.get(
        '/videos/recent',
        queryParameters: {
          'limit': videoLimit,
          'page': page,
        },
      );

      final responses = await Future.wait([articlesFuture, videosFuture]);
      final articlesJson =
          responses[0]['articles'] as List<dynamic>? ?? const [];
      final videosJson = responses[1]['videos'] as List<dynamic>? ?? const [];

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
    } on DioException catch (e, stack) {
      throw NetworkException.fromDioError(e).copyWith(stackTrace: stack);
    } catch (e, stack) {
      throw DataException.fromParseError(e, stack);
    }
  }

  /// Fetches recent reels (short videos).
  ///
  /// Throws [NetworkException] on network errors.
  /// Throws [DataException] on parsing errors.
  Future<List<ReelFeedEntry>> fetchReels({int page = 1, int limit = 20}) async {
    try {
      final response = await _api.get(
        '/videos/reels',
        queryParameters: {
          'page': page,
          'limit': limit,
        },
      );
      final videosJson = response['videos'] as List<dynamic>? ?? const [];
      return videosJson
          .cast<Map<String, dynamic>>()
          .map(VideoDto.fromJson)
          .map((dto) => dto.toReelDomain())
          .toList();
    } on DioException catch (e, stack) {
      throw NetworkException.fromDioError(e).copyWith(stackTrace: stack);
    } catch (e, stack) {
      throw DataException.fromParseError(e, stack);
    }
  }
}
