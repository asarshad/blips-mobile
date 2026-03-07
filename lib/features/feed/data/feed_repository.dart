import 'package:blips_mobile/core/error/error.dart';
import 'package:blips_mobile/core/network/backend_api_client.dart';
import 'package:blips_mobile/features/feed/data/dto/article_dto.dart';
import 'package:blips_mobile/features/feed/data/dto/video_dto.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:dio/dio.dart';

/// Repository responsible for loading feed items from the backend.
class FeedRepository {
  /// Creates the repository with the provided API client.
  FeedRepository(this._api);

  final BackendApiClient _api;
  static const String _sessionPlaylistPath = '/session/playlist';

  // Session snapshot state for cursor-based continuation.
  String? _articleSessionId;
  int? _articleCursor;
  String? _videoSessionId;
  int? _videoCursor;

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
      if (page <= 1) {
        _resetSessionSnapshots();
      }

      final articleItems = await _fetchSessionPlaylist(
        type: 'ARTICLE',
        page: page,
        size: articleLimit,
      );
      final videoItems = await _fetchSessionPlaylist(
        type: 'VIDEO',
        page: page,
        size: videoLimit,
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

  Future<List<FeedEntry>> _fetchSessionPlaylist({
    required String type,
    required int page,
    required int size,
  }) async {
    final query = <String, dynamic>{
      'type': type,
      'size': size,
      if (page > 1) ..._sessionContinuationQuery(type),
    };

    final response = await _api.get(
      _sessionPlaylistPath,
      queryParameters: query,
    );
    final items = (response['items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();

    _captureSessionState(
      type: type,
      sessionId: response['session_id'] as String?,
      cursor: response['cursor'] as int?,
    );

    final parsed = _parsePlaylistItems(items);
    if (parsed.isNotEmpty) {
      return parsed;
    }

    // Backward-compatible fallback for environments without /session/playlist support.
    return _fetchLegacyFeed(type: type, page: page, size: size);
  }

  Map<String, dynamic> _sessionContinuationQuery(String type) {
    final sessionId = type == 'ARTICLE' ? _articleSessionId : _videoSessionId;
    final cursor = type == 'ARTICLE' ? _articleCursor : _videoCursor;
    return {
      if (sessionId != null && sessionId.isNotEmpty) 'session_id': sessionId,
      if (cursor != null) 'cursor': cursor,
    };
  }

  void _captureSessionState({
    required String type,
    String? sessionId,
    int? cursor,
  }) {
    if (type == 'ARTICLE') {
      _articleSessionId = sessionId ?? _articleSessionId;
      _articleCursor = cursor;
      return;
    }
    _videoSessionId = sessionId ?? _videoSessionId;
    _videoCursor = cursor;
  }

  void _resetSessionSnapshots() {
    _articleSessionId = null;
    _articleCursor = null;
    _videoSessionId = null;
    _videoCursor = null;
  }

  List<FeedEntry> _parsePlaylistItems(List<Map<String, dynamic>> items) {
    final parsed = <FeedEntry>[];
    for (final item in items) {
      final itemType = (item['type'] as String? ?? '').toUpperCase();
      if (itemType == 'ARTICLE') {
        final dto = _playlistArticleToDto(item);
        parsed.add(dto.toDomain());
      } else if (itemType == 'VIDEO') {
        final dto = _playlistVideoToDto(item);
        parsed.add(dto.toDomain());
      } else if (itemType == 'AD' && item['item_type'] == 'AD') {
        parsed.add(AdFeedEntry.fromJson(item));
      }
    }
    return parsed;
  }

  ArticleDto _playlistArticleToDto(Map<String, dynamic> item) {
    final topics = (item['topics'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(growable: false);
    return ArticleDto.fromJson({
      'id': item['id'],
      'title': item['title'],
      'source_url': item['source_url'] ?? '',
      'summary': item['summary'],
      'image_url': item['image_url'],
      'published_at': item['published_at'],
      'created_at': item['published_at'],
      'published_date': item['published_at'],
      'read_time_minutes': item['read_time_minutes'],
      'tags': topics.map((topic) => {'name': topic}).toList(growable: false),
      'conversation_starters': item['conversation_starters'],
    });
  }

  VideoDto _playlistVideoToDto(Map<String, dynamic> item) {
    final topics = (item['topics'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(growable: false);
    return VideoDto.fromJson({
      'id': item['id'],
      'title': item['title'],
      'video_url': item['video_url'] ?? item['source_url'] ?? '',
      'source_url': item['source_url'] ?? '',
      'summary': item['summary'],
      'thumbnail_url': item['image_url'],
      'source': item['source'],
      'category': topics.isNotEmpty ? topics.first : null,
      'duration_seconds': item['duration'],
      'created_at': item['published_at'],
      'published_at': item['published_at'],
      'conversation_starters': item['conversation_starters'],
    });
  }

  Future<List<FeedEntry>> _fetchLegacyFeed({
    required String type,
    required int page,
    required int size,
  }) async {
    if (type == 'ARTICLE') {
      final response = await _api.get(
        '/articles/recent',
        queryParameters: {
          'limit': size,
          'page': page,
        },
      );
      final articlesJson = response['articles'] as List<dynamic>? ?? const [];
      return _parseMixedList(
        articlesJson.cast<Map<String, dynamic>>(),
        (json) => ArticleDto.fromJson(json).toDomain(),
      );
    }

    final response = await _api.get(
      '/videos/recent',
      queryParameters: {
        'limit': size,
        'page': page,
      },
    );
    final videosJson = response['videos'] as List<dynamic>? ?? const [];
    return _parseMixedList(
      videosJson.cast<Map<String, dynamic>>(),
      (json) => VideoDto.fromJson(json).toDomain(),
    );
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
