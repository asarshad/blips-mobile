import 'package:blips_mobile/core/error/error.dart';
import 'package:blips_mobile/core/network/backend_api_client.dart';
import 'package:blips_mobile/features/ads/domain/ad_entry.dart';
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
  /// The backend ad mixer may inject `item_type: "AD"` objects into the
  /// articles/videos arrays. These are parsed as [AdFeedEntry] and kept
  /// in the returned list at roughly the same relative positions.
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

      // Parse articles — may contain injected AD items from the backend mixer
      final articlesJson =
          responses[0]['articles'] as List<dynamic>? ?? const [];
      final articleItems = _parseMixedList(
        articlesJson.cast<Map<String, dynamic>>(),
        (json) => ArticleDto.fromJson(json).toDomain(),
      );

      // Parse videos — may also contain injected AD items
      final videosJson = responses[1]['videos'] as List<dynamic>? ?? const [];
      final videoItems = _parseMixedList(
        videosJson.cast<Map<String, dynamic>>(),
        (json) => VideoDto.fromJson(json).toDomain(),
      );

      // Separate organic from ads for proper sorting
      final organic = <FeedEntry>[
        ...articleItems.whereType<ArticleFeedEntry>(),
        ...videoItems.whereType<VideoFeedEntry>(),
      ]..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

      final ads = <AdFeedEntry>[
        ...articleItems.whereType<AdFeedEntry>(),
        ...videoItems.whereType<AdFeedEntry>(),
      ];

      if (ads.isEmpty) return organic;

      // Re-interleave ads at spaced positions
      final mixed = <FeedEntry>[...organic];
      for (var i = 0; i < ads.length; i++) {
        final pos = ((i + 1) * (organic.length ~/ (ads.length + 1)))
            .clamp(1, mixed.length);
        mixed.insert(pos + i, ads[i]);
      }

      return mixed;
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

  /// Parses a mixed JSON list that may contain both organic items and
  /// injected AD items (identified by `item_type == "AD"`).
  static List<FeedEntry> _parseMixedList(
    List<Map<String, dynamic>> jsonList,
    FeedEntry Function(Map<String, dynamic>) organicParser,
  ) {
    return jsonList.map((json) {
      if (json['item_type'] == 'AD') {
        return AdFeedEntry.fromJson(json);
      }
      return organicParser(json);
    }).toList();
  }
}
