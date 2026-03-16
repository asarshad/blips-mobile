import 'package:blips_mobile/core/error/error.dart';
import 'package:blips_mobile/core/network/backend_api_client.dart';
import 'package:blips_mobile/features/feed/data/dto/article_dto.dart';
import 'package:blips_mobile/features/feed/data/dto/video_dto.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:dio/dio.dart';

enum FeedInventoryState {
  warmingUp,
  healthy,
  caughtUp,
}

class FeedPageResult<T extends FeedEntry> {
  const FeedPageResult({
    required this.items,
    required this.hasMore,
    required this.inventoryState,
    this.nextCursor,
    this.servedAt,
    this.sessionId,
  });

  final List<T> items;
  final bool hasMore;
  final FeedInventoryState inventoryState;
  final String? nextCursor;
  final DateTime? servedAt;
  final String? sessionId;

  bool get isCaughtUp => inventoryState == FeedInventoryState.caughtUp;
}

abstract final class FeedInteractionEvent {
  static const openSource = 'OPEN_SOURCE';
  static const videoImpression = 'VIDEO_IMPRESSION';
  static const videoStart = 'VIDEO_START';
  static const video3s = 'VIDEO_3S';
  static const video50pct = 'VIDEO_50PCT';
  static const video95pct = 'VIDEO_95PCT';
  static const videoSkipLt2s = 'VIDEO_SKIP_LT_2S';
  static const videoSave = 'VIDEO_SAVE';
  static const videoShare = 'VIDEO_SHARE';
  static const lessFromCreator = 'LESS_FROM_CREATOR';
  static const caughtUp = 'CAUGHT_UP';
}

/// Repository responsible for loading feed items from the backend.
class FeedRepository {
  /// Creates the repository with the provided API client.
  FeedRepository(this._api);

  final BackendApiClient _api;
  static const String _sessionPlaylistPath = '/session/playlist';
  static const String _interactionPath = '/session/interactions';

  // Session snapshot state for cursor-based continuation.
  String? _articleSessionId;
  int? _articleCursor;
  String? _videoSessionId;
  int? _videoCursor;
  String? _reelsCursor;

  String? get articleSessionId => _articleSessionId;

  String? get videoSessionId => _videoSessionId;

  /// Fetches only article items for a given page.
  Future<FeedPageResult<FeedEntry>> fetchArticlesPage({
    int size = 15,
    int page = 1,
    RequestMode requestMode = RequestMode.normal,
  }) async {
    try {
      if (page <= 1) {
        _articleSessionId = null;
        _articleCursor = null;
      }
      return await _fetchSessionPlaylist(
        type: 'ARTICLE',
        page: page,
        size: size,
        requestMode: requestMode,
      );
    } on DioException catch (e, stack) {
      throw NetworkException.fromDioError(e).copyWith(stackTrace: stack);
    } catch (e, stack) {
      throw DataException.fromParseError(e, stack);
    }
  }

  /// Fetches only video items for a given page.
  Future<FeedPageResult<FeedEntry>> fetchVideosPage({
    int size = 10,
    int page = 1,
    RequestMode requestMode = RequestMode.normal,
  }) async {
    try {
      if (page <= 1) {
        _videoSessionId = null;
        _videoCursor = null;
      }
      return await _fetchSessionPlaylist(
        type: 'VIDEO',
        page: page,
        size: size,
        requestMode: requestMode,
      );
    } on DioException catch (e, stack) {
      throw NetworkException.fromDioError(e).copyWith(stackTrace: stack);
    } catch (e, stack) {
      throw DataException.fromParseError(e, stack);
    }
  }

  /// Fetches both recent articles and videos, merging them into one list.
  @Deprecated('Use fetchArticlesPage / fetchVideosPage instead')
  Future<List<FeedEntry>> fetchFeed({
    int articleLimit = 15,
    int videoLimit = 10,
    int page = 1,
  }) async {
    final result = await fetchFeedPage(
      articleLimit: articleLimit,
      videoLimit: videoLimit,
      page: page,
    );
    return result.items;
  }

  @Deprecated('Use fetchArticlesPage / fetchVideosPage instead')
  Future<FeedPageResult<FeedEntry>> fetchFeedPage({
    int articleLimit = 15,
    int videoLimit = 10,
    int page = 1,
  }) async {
    try {
      if (page <= 1) {
        _resetSessionSnapshots();
      }

      final articleResult = await _fetchSessionPlaylist(
        type: 'ARTICLE',
        page: page,
        size: articleLimit,
      );
      final videoResult = await _fetchSessionPlaylist(
        type: 'VIDEO',
        page: page,
        size: videoLimit,
      );

      final merged = <FeedEntry>[
        ...articleResult.items.whereType<ArticleFeedEntry>(),
        ...videoResult.items.whereType<VideoFeedEntry>(),
      ]..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      final hasMore = articleResult.hasMore || videoResult.hasMore;

      return FeedPageResult(
        items: merged,
        hasMore: hasMore,
        inventoryState: _parseInventoryState(
          value: null,
          hasMore: hasMore,
          itemCount: merged.length,
        ),
        servedAt: _latestServedAt(articleResult.servedAt, videoResult.servedAt),
      );
    } on DioException catch (e, stack) {
      throw NetworkException.fromDioError(e).copyWith(stackTrace: stack);
    } catch (e, stack) {
      throw DataException.fromParseError(e, stack);
    }
  }

  Future<FeedPageResult<FeedEntry>> _fetchSessionPlaylist({
    required String type,
    required int page,
    required int size,
    RequestMode requestMode = RequestMode.normal,
  }) async {
    final query = <String, dynamic>{
      'type': type,
      'size': size,
      if (page > 1) ..._sessionContinuationQuery(type),
    };

    final response = await _api.get(
      _sessionPlaylistPath,
      queryParameters: query,
      requestMode: requestMode,
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
      final hasMore = response['has_more'] as bool? ?? true;
      return FeedPageResult(
        items: parsed,
        hasMore: hasMore,
        inventoryState: _parseInventoryState(
          value: response['inventory_state'] as String?,
          hasMore: hasMore,
          itemCount: parsed.length,
        ),
        sessionId: response['session_id'] as String?,
      );
    }

    // Backward-compatible fallback for environments without /session/playlist support.
    return _fetchLegacyFeedPage(type: type, page: page, size: size);
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
    _reelsCursor = null;
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

  Future<FeedPageResult<FeedEntry>> _fetchLegacyFeedPage({
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
      final items = _parseMixedList(
        articlesJson.cast<Map<String, dynamic>>(),
        (json) => ArticleDto.fromJson(json).toDomain(),
      );
      final hasMore =
          response['has_more'] as bool? ?? articlesJson.length >= size;
      return FeedPageResult(
        items: items,
        hasMore: hasMore,
        inventoryState: _parseInventoryState(
          value: response['inventory_state'] as String?,
          hasMore: hasMore,
          itemCount: items.length,
        ),
      );
    }

    final response = await _api.get(
      '/videos/recent',
      queryParameters: {
        'limit': size,
        'page': page,
      },
    );
    final videosJson = (response['items'] as List<dynamic>? ??
            response['videos'] as List<dynamic>? ??
            const [])
        .cast<Map<String, dynamic>>();
    final items = _parseMixedList(
      videosJson,
      (json) => VideoDto.fromJson(json).toDomain(),
    );
    final hasMore = response['has_more'] as bool? ?? videosJson.length >= size;
    final cursorValue = response['next_cursor'] as String? ??
        (hasMore ? '${(page - 1) * size + size}' : null);
    return FeedPageResult(
      items: items,
      hasMore: hasMore,
      inventoryState: _parseInventoryState(
        value: response['inventory_state'] as String?,
        hasMore: hasMore,
        itemCount: items.length,
      ),
      nextCursor: cursorValue,
      servedAt: _parseServedAt(response['served_at']),
    );
  }

  /// Fetches recent reels (short videos).
  Future<List<ReelFeedEntry>> fetchReels({int page = 1, int limit = 20}) async {
    final result = await fetchReelsPage(
      cursor: page <= 1 ? null : _reelsCursor,
      limit: limit,
    );
    return result.items;
  }

  Future<FeedPageResult<ReelFeedEntry>> fetchReelsPage({
    String? cursor,
    int limit = 20,
    RequestMode requestMode = RequestMode.normal,
  }) async {
    try {
      if (cursor == null) {
        _reelsCursor = null;
      }

      final response = await _api.get(
        '/videos/reels',
        queryParameters: {
          if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
          'limit': limit,
        },
        requestMode: requestMode,
      );
      final videosJson = (response['items'] as List<dynamic>? ??
              response['videos'] as List<dynamic>? ??
              const [])
          .cast<Map<String, dynamic>>();
      final items = videosJson
          .map(VideoDto.fromJson)
          .map((dto) => dto.toReelDomain())
          .toList(growable: false);
      final hasMore =
          response['has_more'] as bool? ?? videosJson.length >= limit;
      final currentOffset = int.tryParse(cursor ?? '0') ?? 0;
      final nextCursor = response['next_cursor'] as String? ??
          (hasMore ? '${currentOffset + limit}' : null);
      _reelsCursor = nextCursor;
      return FeedPageResult(
        items: items,
        hasMore: hasMore,
        inventoryState: _parseInventoryState(
          value: response['inventory_state'] as String?,
          hasMore: hasMore,
          itemCount: items.length,
        ),
        nextCursor: nextCursor,
        servedAt: _parseServedAt(response['served_at']),
      );
    } on DioException catch (e, stack) {
      throw NetworkException.fromDioError(e).copyWith(stackTrace: stack);
    } catch (e, stack) {
      throw DataException.fromParseError(e, stack);
    }
  }

  Future<void> recordInteraction({
    required int contentItemId,
    required String eventType,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      await _api.post(
        _interactionPath,
        data: {
          'content_item_id': contentItemId,
          'event_type': eventType,
          if (extraData != null && extraData.isNotEmpty)
            'extra_data': extraData,
        },
      );
    } on DioException catch (e, stack) {
      logger.warning(
        'Failed to record feed interaction ($eventType)',
        category: LogCategory.network,
        error: e,
        stackTrace: stack,
      );
    } catch (e, stack) {
      logger.warning(
        'Failed to record feed interaction ($eventType)',
        category: LogCategory.app,
        error: e,
        stackTrace: stack,
      );
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
    }).toList(growable: false);
  }

  FeedInventoryState _parseInventoryState({
    required String? value,
    required bool hasMore,
    required int itemCount,
  }) {
    switch ((value ?? '').toLowerCase()) {
      case 'caught_up':
        return FeedInventoryState.caughtUp;
      case 'healthy':
        return FeedInventoryState.healthy;
      case 'warming_up':
        return FeedInventoryState.warmingUp;
      default:
        if (itemCount == 0) return FeedInventoryState.warmingUp;
        return hasMore
            ? FeedInventoryState.healthy
            : FeedInventoryState.caughtUp;
    }
  }

  DateTime? _parseServedAt(dynamic value) {
    if (value is! String || value.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  DateTime? _latestServedAt(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }
}
