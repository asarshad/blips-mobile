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
    this.freshnessStrategy,
    this.resumeContinuityWindowMinutes,
    this.resumeSnapshotAfterRemoteWindow = true,
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
  final String? freshnessStrategy;
  final int? resumeContinuityWindowMinutes;
  final bool resumeSnapshotAfterRemoteWindow;

  bool get isCaughtUp => inventoryState == FeedInventoryState.caughtUp;
}

class FeedHeadMetadata {
  const FeedHeadMetadata({
    this.servedAt,
    this.feedVersion,
    this.newestPublishedAt,
    this.newestCreatedAt,
    this.freshnessStrategy,
  });

  final DateTime? servedAt;
  final String? feedVersion;
  final DateTime? newestPublishedAt;
  final DateTime? newestCreatedAt;
  final String? freshnessStrategy;
}

const String kFeedFreshnessStrategyCurrent = 'current';
const String kFeedFreshnessStrategyFreshUnseenV1 = 'fresh_unseen_v1';
const String kFeedFreshnessStrategyArticleRecentHeadV1 =
    'article_recent_head_v1';

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
  static const report = 'REPORT';
}

/// Repository responsible for loading feed items from the backend.
class FeedRepository {
  /// Creates the repository with the provided API client.
  FeedRepository(this._api, [this._diagnostics]);

  final BackendApiClient _api;
  final AppDiagnosticsController? _diagnostics;
  static const String _sessionPlaylistPath = '/session/playlist';
  static const String _sessionPlaylistMetaPath = '/session/playlist/meta';
  static const String _interactionPath = '/session/interactions';
  static const String _reportsPath = '/session/reports';
  static const String _freshnessEventPath = '/events/track';

  // Session snapshot state for cursor-based continuation.
  String? _articleSessionId;
  int? _articleCursor;
  String? _videoSessionId;
  int? _videoCursor;
  String? _reelSessionId;
  int? _reelCursor;

  String? get articleSessionId => _articleSessionId;

  String? get videoSessionId => _videoSessionId;

  int? get articleCursor => _articleCursor;

  int? get videoCursor => _videoCursor;

  String? get reelsSessionId => _reelSessionId;

  int? get reelsCursor => _reelCursor;

  void restoreArticleSession({String? sessionId, int? cursor}) {
    _articleSessionId = sessionId;
    _articleCursor = cursor;
  }

  void restoreVideoSession({String? sessionId, int? cursor}) {
    _videoSessionId = sessionId;
    _videoCursor = cursor;
  }

  void restoreReelsSession({String? sessionId, int? cursor}) {
    _reelSessionId = sessionId;
    _reelCursor = cursor;
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
    int? continuationCursorOverride,
  }) async {
    final query = <String, dynamic>{
      'type': type,
      'size': size,
      if (page > 1)
        ..._sessionContinuationQuery(
          type,
          cursorOverride: continuationCursorOverride,
        ),
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
        freshnessStrategy: response['freshness_strategy'] as String?,
        resumeContinuityWindowMinutes:
            response['resume_continuity_window_minutes'] as int?,
        resumeSnapshotAfterRemoteWindow:
            response['resume_snapshot_after_remote_window'] as bool? ?? true,
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

  Future<FeedHeadMetadata> fetchArticlesMetadata({
    RequestMode requestMode = RequestMode.normal,
  }) {
    return _fetchSessionPlaylistMetadata(
      type: 'ARTICLE',
      requestMode: requestMode,
    );
  }

  Future<FeedHeadMetadata> _fetchSessionPlaylistMetadata({
    required String type,
    RequestMode requestMode = RequestMode.normal,
  }) async {
    final span = _diagnostics?.startSpan(
      scope: 'feed.repository',
      action: 'sessionPlaylistMeta',
      surface: _surfaceLabelForType(type),
      data: <String, Object?>{
        'requestMode': requestMode.name,
      },
    );

    try {
      final response = await _api.get(
        _sessionPlaylistMetaPath,
        queryParameters: <String, dynamic>{'type': type},
        requestMode: requestMode,
      );
      final metadata = FeedHeadMetadata(
        servedAt: _parseServedAt(response['served_at']),
        feedVersion: response['feed_version'] as String?,
        newestPublishedAt: _parseServedAt(response['newest_published_at']),
        newestCreatedAt: _parseServedAt(response['newest_created_at']),
        freshnessStrategy: response['freshness_strategy'] as String?,
      );
      span?.success(
        data: <String, Object?>{
          'feedVersion': metadata.feedVersion,
          'freshnessStrategy': metadata.freshnessStrategy,
        },
      );
      return metadata;
    } catch (error, stackTrace) {
      span?.failure(error, stackTrace: stackTrace);
      rethrow;
    }
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

  Future<FeedHeadMetadata> fetchVideosMetadata({
    RequestMode requestMode = RequestMode.normal,
  }) {
    return _fetchSessionPlaylistMetadata(
      type: 'VIDEO',
      requestMode: requestMode,
    );
  }

  Future<FeedHeadMetadata> fetchReelsMetadata({
    RequestMode requestMode = RequestMode.normal,
  }) {
    return _fetchSessionPlaylistMetadata(
      type: 'REEL',
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

  Map<String, dynamic> _sessionContinuationQuery(
    String type, {
    int? cursorOverride,
  }) {
    String? sessionId;
    int? cursor;
    switch (type) {
      case 'ARTICLE':
        sessionId = _articleSessionId;
        cursor = _articleCursor;
        break;
      case 'VIDEO':
        sessionId = _videoSessionId;
        cursor = _videoCursor;
        break;
      case 'REEL':
        sessionId = _reelSessionId;
        cursor = _reelCursor;
        break;
      default:
        break;
    }
    final effectiveCursor = cursorOverride ?? cursor;
    return {
      if (sessionId != null && sessionId.isNotEmpty) 'session_id': sessionId,
      if (effectiveCursor != null) 'cursor': effectiveCursor,
    };
  }

  void _captureSessionState({
    required String type,
    String? sessionId,
    int? cursor,
  }) {
    switch (type) {
      case 'ARTICLE':
        _articleSessionId = sessionId ?? _articleSessionId;
        _articleCursor = cursor;
        return;
      case 'VIDEO':
        _videoSessionId = sessionId ?? _videoSessionId;
        _videoCursor = cursor;
        return;
      case 'REEL':
        _reelSessionId = sessionId ?? _reelSessionId;
        _reelCursor = cursor;
        return;
      default:
        return;
    }
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
      } else if (itemType == 'REEL') {
        final dto = _playlistVideoToDto(item);
        parsed.add(dto.toReelDomain());
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

  /// Fetches a single reel for notification-target recovery.
  Future<ReelFeedEntry> fetchReelById(int id) async {
    try {
      final response = await _api.get('/videos/$id');
      final dto = VideoDto.fromJson(response);
      if (!dto.isReel) {
        throw const FormatException('Notification target is not a reel');
      }
      return dto.toReelDomain();
    } on DioException catch (e, stack) {
      throw NetworkException.fromDioError(e).copyWith(stackTrace: stack);
    } catch (e, stack) {
      throw DataException.fromParseError(e, stack);
    }
  }

  /// Fetches recent reels (short videos).
  Future<List<ReelFeedEntry>> fetchReels({int page = 1, int limit = 20}) async {
    final result = await fetchReelsPage(
      cursor: page <= 1 ? null : _reelCursor?.toString(),
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
        _reelSessionId = null;
        _reelCursor = null;
      }

      final page = await _fetchSessionPlaylist(
        type: 'REEL',
        page: cursor == null ? 1 : 2,
        size: limit,
        requestMode: requestMode,
        captureSessionState: captureCursorState,
        continuationCursorOverride: int.tryParse(cursor ?? ''),
      );
      final items =
          page.items.whereType<ReelFeedEntry>().toList(growable: false);
      span?.success(
        data: <String, Object?>{
          'itemCount': items.length,
          'hasMore': page.hasMore,
          'nextCursor': page.sessionCursor?.toString() ?? '',
          'inventoryState': page.inventoryState.name,
        },
      );
      return FeedPageResult(
        items: items,
        hasMore: page.hasMore,
        inventoryState: page.inventoryState,
        nextCursor: page.sessionCursor?.toString(),
        sessionId: page.sessionId,
        sessionCursor: page.sessionCursor,
        servedAt: page.servedAt,
        feedVersion: page.feedVersion,
        newestPublishedAt: page.newestPublishedAt,
        newestCreatedAt: page.newestCreatedAt,
        freshnessStrategy: page.freshnessStrategy,
        resumeContinuityWindowMinutes: page.resumeContinuityWindowMinutes,
        resumeSnapshotAfterRemoteWindow: page.resumeSnapshotAfterRemoteWindow,
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

  /// Reports a piece of content to the moderation queue.
  ///
  /// [contentItemId] is the feed entry ID.
  /// [surface] is one of 'articles', 'videos', 'reels', 'chat'.
  /// [reason] is a short machine key, e.g. 'hateful', 'spam', 'explicit',
  ///   'violence', 'misinformation', 'other'.
  /// [messageId] optionally identifies a specific AI chat response.
  ///
  /// Returns `true` if the report was accepted by the server, `false` on any
  /// network or server error so callers can surface a meaningful failure message.
  Future<bool> reportContent({
    required int contentItemId,
    required String surface,
    required String reason,
    String? messageId,
  }) async {
    try {
      await _api.post(
        _reportsPath,
        data: {
          'content_item_id': contentItemId,
          'surface': surface,
          'reason': reason,
          if (messageId != null) 'message_id': messageId,
        },
      );
      return true;
    } on DioException catch (e, stack) {
      logger.warning(
        'Failed to submit content report',
        category: LogCategory.network,
        error: e,
        stackTrace: stack,
      );
      return false;
    } catch (e, stack) {
      logger.warning(
        'Failed to submit content report',
        category: LogCategory.app,
        error: e,
        stackTrace: stack,
      );
      return false;
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
      'REEL' => 'reels',
      _ => type.toLowerCase(),
    };
  }
}
