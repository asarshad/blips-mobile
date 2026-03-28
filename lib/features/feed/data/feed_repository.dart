import 'package:blips_mobile/core/diagnostics/app_diagnostics.dart';
import 'package:blips_mobile/core/error/error.dart';
import 'package:blips_mobile/core/network/backend_api_client.dart';
import 'package:blips_mobile/features/feed/data/dto/article_dto.dart';
import 'package:blips_mobile/features/feed/data/mappers/feed_mappers.dart';
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
    this.sessionCursor,
    this.servedAt,
    this.sessionId,
    this.feedVersion,
    this.newestPublishedAt,
    this.newestCreatedAt,
  });

  final List<T> items;
  final bool hasMore;
  final FeedInventoryState inventoryState;
  final String? nextCursor;
  final int? sessionCursor;
  final DateTime? servedAt;
  final String? sessionId;
  final String? feedVersion;
  final DateTime? newestPublishedAt;
  final DateTime? newestCreatedAt;

  bool get isCaughtUp => inventoryState == FeedInventoryState.caughtUp;
}

abstract final class FeedInteractionEvent {
  static const view10s = 'VIEW_10S';
  static const openSource = 'OPEN_SOURCE';
  static const share = 'SHARE';
  static const save = 'SAVE';
  static const chatStart = 'CHAT_START';
  static const chatMessage = 'CHAT_MESSAGE';
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
  FeedRepository(this._api, [this._diagnostics]);

  final BackendApiClient _api;
  final AppDiagnosticsController? _diagnostics;
  static const String _sessionPlaylistPath = '/session/playlist';
  static const String _interactionPath = '/session/interactions';
  static const String _freshnessEventPath = '/events/track';

  // Session snapshot state for cursor-based continuation.
  String? _articleSessionId;
  int? _articleCursor;
  String? _videoSessionId;
  int? _videoCursor;
  String? _reelsCursor;

  String? get articleSessionId => _articleSessionId;

  String? get videoSessionId => _videoSessionId;

  int? get articleCursor => _articleCursor;

  int? get videoCursor => _videoCursor;

  String? get reelsCursor => _reelsCursor;

  void restoreArticleSession({String? sessionId, int? cursor}) {
    _articleSessionId = sessionId;
    _articleCursor = cursor;
  }

  void restoreVideoSession({String? sessionId, int? cursor}) {
    _videoSessionId = sessionId;
    _videoCursor = cursor;
  }

  void restoreReelsCursor(String? cursor) {
    _reelsCursor = cursor;
  }

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

  Future<FeedPageResult<FeedEntry>> _fetchSessionPlaylist({
    required String type,
    required int page,
    required int size,
    RequestMode requestMode = RequestMode.normal,
    bool captureSessionState = true,
  }) async {
    final query = <String, dynamic>{
      'type': type,
      'size': size,
      if (page > 1) ..._sessionContinuationQuery(type),
    };
    final span = _diagnostics?.startSpan(
      scope: 'feed.repository',
      action: 'sessionPlaylist',
      surface: _surfaceLabelForType(type),
      data: <String, Object?>{
        'page': page,
        'size': size,
        'requestMode': requestMode.name,
        'captureSessionState': captureSessionState,
        if (query.containsKey('session_id')) 'sessionId': query['session_id'],
        if (query.containsKey('cursor')) 'cursor': query['cursor'],
      },
    );

    try {
      final response = await _api.get(
        _sessionPlaylistPath,
        queryParameters: query,
        requestMode: requestMode,
      );
      final items = (response['items'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>();

      if (captureSessionState) {
        _captureSessionState(
          type: type,
          sessionId: response['session_id'] as String?,
          cursor: response['cursor'] as int?,
        );
      }

      final parsed = _parsePlaylistItems(items);
      final hasMore = response['has_more'] as bool? ?? true;
      span?.success(
        data: <String, Object?>{
          'itemCount': parsed.length,
          'hasMore': hasMore,
          'sessionId': response['session_id'] as String? ?? '',
          'cursor': response['cursor'] as int?,
          'inventoryState': response['inventory_state'] as String? ?? 'unknown',
        },
      );
      return FeedPageResult(
        items: parsed,
        hasMore: hasMore,
        inventoryState: _parseInventoryState(
          value: response['inventory_state'] as String?,
          hasMore: hasMore,
          itemCount: parsed.length,
        ),
        sessionId: response['session_id'] as String?,
        sessionCursor: response['cursor'] as int?,
        servedAt: _parseServedAt(response['served_at']),
        feedVersion: response['feed_version'] as String?,
        newestPublishedAt: _parseServedAt(response['newest_published_at']),
        newestCreatedAt: _parseServedAt(response['newest_created_at']),
      );
    } catch (error, stackTrace) {
      span?.failure(error, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<FeedPageResult<FeedEntry>> previewArticlesHead({
    int size = 15,
    RequestMode requestMode = RequestMode.normal,
  }) {
    return _previewSessionPlaylist(
      type: 'ARTICLE',
      size: size,
      requestMode: requestMode,
    );
  }

  Future<FeedPageResult<FeedEntry>> previewVideosHead({
    int size = 10,
    RequestMode requestMode = RequestMode.normal,
  }) {
    return _previewSessionPlaylist(
      type: 'VIDEO',
      size: size,
      requestMode: requestMode,
    );
  }

  Future<FeedPageResult<FeedEntry>> _previewSessionPlaylist({
    required String type,
    required int size,
    required RequestMode requestMode,
  }) async {
    return _fetchSessionPlaylist(
      type: type,
      page: 1,
      size: size,
      requestMode: requestMode,
      captureSessionState: false,
    );
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
      'created_at': item['created_at'] ?? item['published_at'],
      'published_date': item['published_at'],
      'read_time_minutes': item['read_time_minutes'],
      'tags': topics.map((topic) => {'name': topic}).toList(growable: false),
      'freshness_tier': item['freshness_tier'],
      'freshness_reason': item['freshness_reason'],
      'published_age_seconds': item['published_age_seconds'],
      'added_age_seconds': item['added_age_seconds'],
      'conversation_starters': item['conversation_starters'],
    });
  }

  VideoDto _playlistVideoToDto(Map<String, dynamic> item) {
    final topics = (item['topics'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(growable: false);
    return VideoDto.fromJson({
      'id': item['id'],
      'type': item['type'],
      'title': item['title'],
      'video_url': item['video_url'] ?? item['source_url'] ?? '',
      'source_url': item['source_url'] ?? '',
      'summary': item['summary'],
      'thumbnail_url': item['thumbnail_url'] ?? item['image_url'],
      'source': item['source'],
      'category': topics.isNotEmpty ? topics.first : null,
      'duration_seconds': item['duration_seconds'] ?? item['duration'],
      'created_at': item['created_at'] ?? item['published_at'],
      'published_at': item['published_at'],
      'freshness_tier': item['freshness_tier'],
      'freshness_reason': item['freshness_reason'],
      'published_age_seconds': item['published_age_seconds'],
      'added_age_seconds': item['added_age_seconds'],
      'conversation_starters': item['conversation_starters'],
    });
  }

  /// Fetches a single article for notification-target recovery.
  Future<ArticleFeedEntry> fetchArticleById(int id) async {
    try {
      final response = await _api.get('/articles/$id');
      final dto = ArticleDto.fromJson(response);
      if (!dto.isArticle) {
        throw const FormatException('Notification target is not an article');
      }
      return dto.toDomain();
    } on DioException catch (e, stack) {
      throw NetworkException.fromDioError(e).copyWith(stackTrace: stack);
    } catch (e, stack) {
      throw DataException.fromParseError(e, stack);
    }
  }

  /// Fetches a single video for notification-target recovery.
  Future<VideoFeedEntry> fetchVideoById(int id) async {
    try {
      final response = await _api.get('/videos/$id');
      final dto = VideoDto.fromJson(response);
      if (dto.isReel) {
        throw const FormatException('Notification target resolved to a reel');
      }
      if (!dto.isVideo) {
        throw const FormatException('Notification target is not a video');
      }
      return dto.toDomain() as VideoFeedEntry;
    } on DioException catch (e, stack) {
      throw NetworkException.fromDioError(e).copyWith(stackTrace: stack);
    } catch (e, stack) {
      throw DataException.fromParseError(e, stack);
    }
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
    bool captureCursorState = true,
  }) async {
    final span = _diagnostics?.startSpan(
      scope: 'feed.repository',
      action: 'reelsPage',
      surface: 'reels',
      data: <String, Object?>{
        'cursor': cursor ?? '',
        'limit': limit,
        'requestMode': requestMode.name,
        'captureCursorState': captureCursorState,
      },
    );
    try {
      if (captureCursorState && cursor == null) {
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
      if (captureCursorState) {
        _reelsCursor = nextCursor;
      }
      span?.success(
        data: <String, Object?>{
          'itemCount': items.length,
          'hasMore': hasMore,
          'nextCursor': nextCursor ?? '',
          'inventoryState': response['inventory_state'] as String? ?? 'unknown',
        },
      );
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
        feedVersion: response['feed_version'] as String?,
        newestPublishedAt: _parseServedAt(response['newest_published_at']),
        newestCreatedAt: _parseServedAt(response['newest_created_at']),
      );
    } on DioException catch (e, stack) {
      span?.failure(e, stackTrace: stack);
      throw NetworkException.fromDioError(e).copyWith(stackTrace: stack);
    } catch (e, stack) {
      span?.failure(e, stackTrace: stack);
      throw DataException.fromParseError(e, stack);
    }
  }

  Future<FeedPageResult<ReelFeedEntry>> previewReelsHead({
    int limit = 20,
    RequestMode requestMode = RequestMode.normal,
  }) async {
    return fetchReelsPage(
      cursor: null,
      limit: limit,
      requestMode: requestMode,
      captureCursorState: false,
    );
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

  Future<void> recordFreshnessEvent({
    required String eventName,
    required String surface,
    String itemType = 'FEED',
    int? contentItemId,
    String? feedVersion,
    String? freshnessTier,
    int count = 1,
    String? sessionId,
  }) async {
    try {
      await _api.post(
        _freshnessEventPath,
        data: {
          'item_type': itemType,
          'surface': surface,
          if (contentItemId != null) 'content_id': contentItemId,
          'event_name': eventName,
          'count': count,
          if (feedVersion != null) 'feed_version': feedVersion,
          if (freshnessTier != null) 'freshness_tier': freshnessTier,
          if (sessionId != null) 'session_id': sessionId,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        },
      );
    } on DioException catch (e, stack) {
      logger.warning(
        'Failed to record freshness event ($eventName)',
        category: LogCategory.network,
        error: e,
        stackTrace: stack,
      );
    } catch (e, stack) {
      logger.warning(
        'Failed to record freshness event ($eventName)',
        category: LogCategory.app,
        error: e,
        stackTrace: stack,
      );
    }
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
    return parseBackendDateTime(value);
  }

  String _surfaceLabelForType(String type) {
    return switch (type) {
      'ARTICLE' => 'articles',
      'VIDEO' => 'videos',
      _ => type.toLowerCase(),
    };
  }
}
