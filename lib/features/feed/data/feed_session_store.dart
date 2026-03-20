import 'dart:convert';

import 'package:blips_mobile/features/feed/data/feed_cache_interface.dart';
import 'package:blips_mobile/features/feed/data/feed_repository.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';

const _kActiveSessionPrefix = 'feed_session:';
const _kLastSurfaceKey = 'feed_last_surface';
const _kLocalHistoryKey = 'feed_local_history';

const Duration kFeedResumeWindow = Duration(hours: 2);
const Duration kBackendSessionTtl = Duration(hours: 1);
const Duration kConsumedSuppressionWindow = Duration(hours: 24);
const Duration kExposedDemotionWindow = Duration(hours: 6);

enum FeedSurface {
  articles,
  videos,
  reels;

  String get storageKey => switch (this) {
        FeedSurface.articles => 'articles',
        FeedSurface.videos => 'videos',
        FeedSurface.reels => 'reels',
      };

  int get tabIndex => switch (this) {
        FeedSurface.articles => 0,
        FeedSurface.videos => 1,
        FeedSurface.reels => 2,
      };

  static FeedSurface? tryParse(String? value) {
    return switch (value) {
      'articles' => FeedSurface.articles,
      'videos' => FeedSurface.videos,
      'reels' => FeedSurface.reels,
      _ => null,
    };
  }
}

class FeedSessionRestoreDecision {
  const FeedSessionRestoreDecision({
    this.resumeSnapshot,
  });

  final FeedSessionSnapshot? resumeSnapshot;
}

class FeedSessionSnapshot {
  const FeedSessionSnapshot({
    required this.surface,
    required this.items,
    required this.lastActiveAt,
    required this.headBaselineIds,
    required this.hasMore,
    required this.inventoryState,
    this.currentItemId,
    this.sessionId,
    this.continuationCursor,
    this.pendingNewCount = 0,
  });

  final FeedSurface surface;
  final List<FeedEntry> items;
  final int? currentItemId;
  final DateTime lastActiveAt;
  final List<int> headBaselineIds;
  final String? sessionId;
  final String? continuationCursor;
  final bool hasMore;
  final FeedInventoryState inventoryState;
  final int pendingNewCount;

  Map<String, dynamic> toJson() {
    return {
      'surface': surface.storageKey,
      'items': items.map(_serializeEntry).toList(growable: false),
      'current_item_id': currentItemId,
      'last_active_at': lastActiveAt.toIso8601String(),
      'head_baseline_ids': headBaselineIds,
      'session_id': sessionId,
      'continuation_cursor': continuationCursor,
      'has_more': hasMore,
      'inventory_state': inventoryState.name,
      'pending_new_count': pendingNewCount,
    };
  }

  factory FeedSessionSnapshot.fromJson(Map<String, dynamic> json) {
    return FeedSessionSnapshot(
      surface: FeedSurface.tryParse(json['surface'] as String?) ??
          FeedSurface.articles,
      items: ((json['items'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>())
          .map(_deserializeEntry)
          .toList(growable: false),
      currentItemId: json['current_item_id'] as int?,
      lastActiveAt: DateTime.parse(json['last_active_at'] as String),
      headBaselineIds: (json['head_baseline_ids'] as List<dynamic>? ?? const [])
          .map((value) => value as int)
          .toList(growable: false),
      sessionId: json['session_id'] as String?,
      continuationCursor: json['continuation_cursor'] as String?,
      hasMore: json['has_more'] as bool? ?? true,
      inventoryState: FeedInventoryState.values.firstWhere(
        (value) => value.name == (json['inventory_state'] as String?),
        orElse: () => FeedInventoryState.healthy,
      ),
      pendingNewCount: json['pending_new_count'] as int? ?? 0,
    );
  }

  FeedSessionSnapshot copyWith({
    List<FeedEntry>? items,
    int? currentItemId,
    bool clearCurrentItemId = false,
    DateTime? lastActiveAt,
    List<int>? headBaselineIds,
    String? sessionId,
    bool clearSessionId = false,
    String? continuationCursor,
    bool clearContinuationCursor = false,
    bool? hasMore,
    FeedInventoryState? inventoryState,
    int? pendingNewCount,
  }) {
    return FeedSessionSnapshot(
      surface: surface,
      items: items ?? this.items,
      currentItemId:
          clearCurrentItemId ? null : (currentItemId ?? this.currentItemId),
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      headBaselineIds: headBaselineIds ?? this.headBaselineIds,
      sessionId: clearSessionId ? null : (sessionId ?? this.sessionId),
      continuationCursor: clearContinuationCursor
          ? null
          : (continuationCursor ?? this.continuationCursor),
      hasMore: hasMore ?? this.hasMore,
      inventoryState: inventoryState ?? this.inventoryState,
      pendingNewCount: pendingNewCount ?? this.pendingNewCount,
    );
  }
}

class FeedLocalHistory {
  const FeedLocalHistory({
    required this.exposedAt,
    required this.consumedAt,
  });

  final Map<String, DateTime> exposedAt;
  final Map<String, DateTime> consumedAt;

  Map<String, dynamic> toJson() {
    return {
      'exposed_at': exposedAt.map(
        (key, value) => MapEntry(key, value.toIso8601String()),
      ),
      'consumed_at': consumedAt.map(
        (key, value) => MapEntry(key, value.toIso8601String()),
      ),
    };
  }

  factory FeedLocalHistory.fromJson(Map<String, dynamic> json) {
    DateTime? _parseDate(dynamic value) {
      if (value is! String || value.isEmpty) return null;
      return DateTime.tryParse(value);
    }

    Map<String, DateTime> _parseMap(dynamic raw) {
      final source = raw is Map<String, dynamic>
          ? raw
          : raw is Map
              ? raw.cast<String, dynamic>()
              : const <String, dynamic>{};
      final result = <String, DateTime>{};
      source.forEach((key, value) {
        final parsed = _parseDate(value);
        if (parsed != null) {
          result[key] = parsed;
        }
      });
      return result;
    }

    return FeedLocalHistory(
      exposedAt: _parseMap(json['exposed_at']),
      consumedAt: _parseMap(json['consumed_at']),
    );
  }

  factory FeedLocalHistory.empty() => const FeedLocalHistory(
        exposedAt: <String, DateTime>{},
        consumedAt: <String, DateTime>{},
      );
}

class FeedSessionStore {
  FeedSessionStore(this._cache);

  final FeedCacheInterface _cache;

  Future<FeedSessionRestoreDecision> prepareRestore(
    FeedSurface surface, {
    DateTime? now,
  }) async {
    final active = await getActiveSession(surface);
    if (active == null) {
      return const FeedSessionRestoreDecision();
    }

    final reference = now ?? DateTime.now();
    if (_isResumeEligible(active, reference)) {
      return FeedSessionRestoreDecision(resumeSnapshot: active);
    }

    await clearActiveSession(surface);
    return const FeedSessionRestoreDecision();
  }

  Future<FeedSessionSnapshot?> getActiveSession(FeedSurface surface) async {
    final raw =
        await _cache.getMeta('$_kActiveSessionPrefix${surface.storageKey}');
    if (raw == null || raw.isEmpty) return null;
    try {
      return FeedSessionSnapshot.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      await clearActiveSession(surface);
      return null;
    }
  }

  Future<void> saveActiveSession(FeedSessionSnapshot snapshot) async {
    await _cache.setMeta(
      '$_kActiveSessionPrefix${snapshot.surface.storageKey}',
      jsonEncode(snapshot.toJson()),
    );
  }

  Future<void> clearActiveSession(FeedSurface surface) async {
    await _cache.deleteMeta('$_kActiveSessionPrefix${surface.storageKey}');
  }

  Future<FeedSurface?> getLastSurface() async {
    return FeedSurface.tryParse(await _cache.getMeta(_kLastSurfaceKey));
  }

  Future<void> setLastSurface(FeedSurface surface) async {
    await _cache.setMeta(_kLastSurfaceKey, surface.storageKey);
  }

  bool isResumeEligible(FeedSessionSnapshot snapshot, {DateTime? now}) {
    return _isResumeEligible(snapshot, now ?? DateTime.now());
  }

  bool isRemoteContinuationFresh(
    FeedSurface surface,
    FeedSessionSnapshot snapshot, {
    DateTime? now,
  }) {
    if (surface == FeedSurface.reels) {
      return true;
    }
    final reference = now ?? DateTime.now();
    return reference.difference(snapshot.lastActiveAt) <= kBackendSessionTtl;
  }

  Future<void> markExposed(
    FeedSurface surface,
    int contentId, {
    DateTime? at,
  }) async {
    final history = await _getPrunedHistory(now: at);
    final key = _historyKey(surface, contentId);
    history.exposedAt[key] = at ?? DateTime.now();
    await _saveHistory(history);
  }

  Future<void> markConsumed(
    FeedSurface surface,
    int contentId, {
    DateTime? at,
  }) async {
    final history = await _getPrunedHistory(now: at);
    final key = _historyKey(surface, contentId);
    final timestamp = at ?? DateTime.now();
    history.exposedAt[key] = timestamp;
    history.consumedAt[key] = timestamp;
    await _saveHistory(history);
  }

  Future<Set<int>> getRecentlyConsumedIds(
    FeedSurface surface, {
    DateTime? now,
  }) async {
    final history = await _getPrunedHistory(now: now);
    return _idsForSurface(history.consumedAt, surface);
  }

  Future<Set<int>> getRecentlyExposedIds(
    FeedSurface surface, {
    DateTime? now,
  }) async {
    final history = await _getPrunedHistory(now: now);
    return _idsForSurface(history.exposedAt, surface);
  }

  Future<FeedLocalHistory> _getPrunedHistory({DateTime? now}) async {
    final raw = await _cache.getMeta(_kLocalHistoryKey);
    final reference = now ?? DateTime.now();
    final history = (() {
      if (raw == null || raw.isEmpty) {
        return FeedLocalHistory.empty();
      }
      try {
        return FeedLocalHistory.fromJson(
            jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        return FeedLocalHistory.empty();
      }
    })();

    history.exposedAt.removeWhere(
      (_, value) => reference.difference(value) > kExposedDemotionWindow,
    );
    history.consumedAt.removeWhere(
      (_, value) => reference.difference(value) > kConsumedSuppressionWindow,
    );
    return history;
  }

  Future<void> _saveHistory(FeedLocalHistory history) async {
    await _cache.setMeta(_kLocalHistoryKey, jsonEncode(history.toJson()));
  }

  bool _isResumeEligible(FeedSessionSnapshot snapshot, DateTime now) {
    return _isSameLocalDay(snapshot.lastActiveAt, now) &&
        now.difference(snapshot.lastActiveAt) <= kFeedResumeWindow;
  }

  bool _isSameLocalDay(DateTime a, DateTime b) {
    final localA = a.toLocal();
    final localB = b.toLocal();
    return localA.year == localB.year &&
        localA.month == localB.month &&
        localA.day == localB.day;
  }

  String _historyKey(FeedSurface surface, int contentId) {
    return '${surface.storageKey}:$contentId';
  }

  Set<int> _idsForSurface(Map<String, DateTime> source, FeedSurface surface) {
    final prefix = '${surface.storageKey}:';
    return source.keys
        .where((key) => key.startsWith(prefix))
        .map((key) => int.tryParse(key.substring(prefix.length)))
        .whereType<int>()
        .toSet();
  }
}

Map<String, dynamic> _serializeEntry(FeedEntry entry) {
  String tier(FreshnessTier value) => value.name;

  return switch (entry) {
    ArticleFeedEntry() => {
        'entry_type': 'article',
        'id': entry.id,
        'title': entry.title,
        'summary': entry.summary,
        'source': entry.source,
        'published_at': entry.publishedAt.toIso8601String(),
        'added_at': entry.addedAt?.toIso8601String(),
        'freshness_tier': tier(entry.freshnessTier),
        'freshness_reason': entry.freshnessReason,
        'conversation_starters': entry.conversationStarters,
        'url': entry.url,
        'image_url': entry.imageUrl,
        'category': entry.category,
        'read_time': entry.readTime,
        'tags': entry.tags,
      },
    VideoFeedEntry() => {
        'entry_type': 'video',
        'id': entry.id,
        'title': entry.title,
        'summary': entry.summary,
        'source': entry.source,
        'published_at': entry.publishedAt.toIso8601String(),
        'added_at': entry.addedAt?.toIso8601String(),
        'freshness_tier': tier(entry.freshnessTier),
        'freshness_reason': entry.freshnessReason,
        'conversation_starters': entry.conversationStarters,
        'video_url': entry.videoUrl,
        'link': entry.link,
        'category': entry.category,
        'read_time': entry.readTime,
        'duration_seconds': entry.durationSeconds,
        'thumbnail_url': entry.thumbnailUrl,
      },
    ReelFeedEntry() => {
        'entry_type': 'reel',
        'id': entry.id,
        'title': entry.title,
        'summary': entry.summary,
        'source': entry.source,
        'published_at': entry.publishedAt.toIso8601String(),
        'added_at': entry.addedAt?.toIso8601String(),
        'freshness_tier': tier(entry.freshnessTier),
        'freshness_reason': entry.freshnessReason,
        'conversation_starters': entry.conversationStarters,
        'video_url': entry.videoUrl,
        'link': entry.link,
        'duration_seconds': entry.durationSeconds,
        'thumbnail_url': entry.thumbnailUrl,
      },
    _ =>
      throw ArgumentError('Unsupported feed entry type: ${entry.runtimeType}'),
  };
}

FeedEntry _deserializeEntry(Map<String, dynamic> json) {
  final tier = FreshnessTier.values.firstWhere(
    (value) => value.name == (json['freshness_tier'] as String?),
    orElse: () => FreshnessTier.fresh,
  );

  final publishedAt = DateTime.parse(json['published_at'] as String);
  final addedAt = (json['added_at'] as String?)?.let(DateTime.parse);
  final starters = (json['conversation_starters'] as List<dynamic>? ?? const [])
      .whereType<String>()
      .toList(growable: false);

  switch (json['entry_type'] as String? ?? '') {
    case 'article':
      return ArticleFeedEntry(
        id: json['id'] as int,
        title: json['title'] as String,
        summary: json['summary'] as String? ?? '',
        source: json['source'] as String? ?? '',
        publishedAt: publishedAt,
        url: json['url'] as String? ?? '',
        imageUrl: json['image_url'] as String? ?? '',
        category: json['category'] as String? ?? '',
        readTime: json['read_time'] as int? ?? 1,
        tags: (json['tags'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(growable: false),
        addedAt: addedAt,
        freshnessTier: tier,
        freshnessReason: json['freshness_reason'] as String?,
        conversationStarters: starters,
      );
    case 'video':
      return VideoFeedEntry(
        id: json['id'] as int,
        title: json['title'] as String,
        summary: json['summary'] as String? ?? '',
        videoUrl: json['video_url'] as String? ?? '',
        link: json['link'] as String? ?? '',
        source: json['source'] as String? ?? '',
        category: json['category'] as String? ?? '',
        publishedAt: publishedAt,
        readTime: json['read_time'] as int? ?? 1,
        durationSeconds: json['duration_seconds'] as int?,
        thumbnailUrl: json['thumbnail_url'] as String?,
        addedAt: addedAt,
        freshnessTier: tier,
        freshnessReason: json['freshness_reason'] as String?,
        conversationStarters: starters,
      );
    case 'reel':
      return ReelFeedEntry(
        id: json['id'] as int,
        title: json['title'] as String,
        summary: json['summary'] as String? ?? '',
        videoUrl: json['video_url'] as String? ?? '',
        link: json['link'] as String? ?? '',
        source: json['source'] as String? ?? '',
        publishedAt: publishedAt,
        durationSeconds: json['duration_seconds'] as int?,
        thumbnailUrl: json['thumbnail_url'] as String?,
        addedAt: addedAt,
        freshnessTier: tier,
        freshnessReason: json['freshness_reason'] as String?,
        conversationStarters: starters,
      );
    default:
      throw ArgumentError(
          'Unsupported snapshot entry type: ${json['entry_type']}');
  }
}

extension _NullableStringX on String? {
  T? let<T>(T Function(String value) transform) {
    final value = this;
    if (value == null || value.isEmpty) return null;
    return transform(value);
  }
}
