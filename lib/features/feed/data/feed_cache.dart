import 'dart:convert';

import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/data/feed_cache_interface.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// SQLite-based cache for feed data with stale-while-revalidate support.
class FeedCache implements FeedCacheInterface {
  static final FeedCache instance = FeedCache._init();
  static Database? _database;
  static const String _feedLastSeenAtKey = 'feed_last_seen_at';

  FeedCache._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('blips_feed_cache.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Articles table
    await db.execute('''
      CREATE TABLE articles (
        id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        summary TEXT NOT NULL,
        source TEXT NOT NULL,
        published_at TEXT NOT NULL,
        url TEXT NOT NULL,
        image_url TEXT NOT NULL,
        category TEXT NOT NULL,
        read_time INTEGER NOT NULL,
        tags TEXT NOT NULL,
        conversation_starters TEXT,
        cached_at TEXT NOT NULL
      )
    ''');

    // Videos table
    await db.execute('''
      CREATE TABLE videos (
        id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        summary TEXT NOT NULL,
        video_url TEXT NOT NULL,
        link TEXT NOT NULL,
        source TEXT NOT NULL,
        category TEXT NOT NULL,
        published_at TEXT NOT NULL,
        read_time INTEGER NOT NULL,
        thumbnail_url TEXT,
        conversation_starters TEXT,
        cached_at TEXT NOT NULL
      )
    ''');

    // Reels table
    await db.execute('''
      CREATE TABLE reels (
        id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        summary TEXT NOT NULL,
        video_url TEXT NOT NULL,
        link TEXT NOT NULL,
        source TEXT NOT NULL,
        published_at TEXT NOT NULL,
        thumbnail_url TEXT,
        conversation_starters TEXT,
        cached_at TEXT NOT NULL
      )
    ''');

    // Index for faster sorting
    await db.execute(
      'CREATE INDEX idx_articles_published ON articles(published_at DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_videos_published ON videos(published_at DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_reels_published ON reels(published_at DESC)',
    );

    // Index for cache cleanup queries
    await db.execute('CREATE INDEX idx_articles_cached ON articles(cached_at)');
    await db.execute('CREATE INDEX idx_videos_cached ON videos(cached_at)');
    await db.execute('CREATE INDEX idx_reels_cached ON reels(cached_at)');

    // Metadata key/value store.
    await db.execute('''
      CREATE TABLE cache_meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // v2: Add conversation_starters column to all tables
      await db.execute(
        'ALTER TABLE articles ADD COLUMN conversation_starters TEXT',
      );
      await db.execute(
        'ALTER TABLE videos ADD COLUMN conversation_starters TEXT',
      );
      await db.execute(
        'ALTER TABLE reels ADD COLUMN conversation_starters TEXT',
      );
    }
    if (oldVersion < 3) {
      // v3: Add cached_at indexes for faster cleanup queries
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_articles_cached ON articles(cached_at)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_videos_cached ON videos(cached_at)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_reels_cached ON reels(cached_at)',
      );
    }
    if (oldVersion < 4) {
      // v4: Add cache metadata store for feed UX flags.
      await db.execute('''
        CREATE TABLE IF NOT EXISTS cache_meta (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
    }
  }

  /// Decode a JSON-encoded starters list from SQLite, returning empty list on null/error.
  static List<String> _decodeStarters(dynamic value) {
    if (value == null) return const <String>[];
    try {
      final decoded = jsonDecode(value as String);
      if (decoded is List) {
        return decoded.whereType<String>().toList();
      }
    } catch (_) {}
    return const <String>[];
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Articles
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> cacheArticles(List<ArticleFeedEntry> articles) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();

    for (final article in articles) {
      batch.insert(
          'articles',
          {
            'id': article.id,
            'title': article.title,
            'summary': article.summary,
            'source': article.source,
            'published_at': article.publishedAt.toIso8601String(),
            'url': article.url,
            'image_url': article.imageUrl,
            'category': article.category,
            'read_time': article.readTime,
            'tags': jsonEncode(article.tags),
            'conversation_starters': article.conversationStarters.isNotEmpty
                ? jsonEncode(article.conversationStarters)
                : null,
            'cached_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
  }

  Future<List<ArticleFeedEntry>> getCachedArticles({int limit = 50}) async {
    final db = await database;
    final results = await db.query(
      'articles',
      orderBy: 'published_at DESC',
      limit: limit,
    );

    return results.map(_articleFromRow).toList();
  }

  ArticleFeedEntry _articleFromRow(Map<String, dynamic> row) {
    return ArticleFeedEntry(
      id: row['id'] as int,
      title: row['title'] as String,
      summary: row['summary'] as String,
      source: row['source'] as String,
      publishedAt: DateTime.parse(row['published_at'] as String),
      url: row['url'] as String,
      imageUrl: row['image_url'] as String,
      category: row['category'] as String,
      readTime: row['read_time'] as int,
      tags: (jsonDecode(row['tags'] as String) as List<dynamic>)
          .cast<String>()
          .toList(),
      conversationStarters: _decodeStarters(row['conversation_starters']),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Videos
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> cacheVideos(List<VideoFeedEntry> videos) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();

    for (final video in videos) {
      batch.insert(
          'videos',
          {
            'id': video.id,
            'title': video.title,
            'summary': video.summary,
            'video_url': video.videoUrl,
            'link': video.link,
            'source': video.source,
            'category': video.category,
            'published_at': video.publishedAt.toIso8601String(),
            'read_time': video.readTime,
            'thumbnail_url': video.thumbnailUrl,
            'conversation_starters': video.conversationStarters.isNotEmpty
                ? jsonEncode(video.conversationStarters)
                : null,
            'cached_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
  }

  Future<List<VideoFeedEntry>> getCachedVideos({int limit = 30}) async {
    final db = await database;
    final results = await db.query(
      'videos',
      orderBy: 'published_at DESC',
      limit: limit,
    );

    return results.map(_videoFromRow).toList();
  }

  VideoFeedEntry _videoFromRow(Map<String, dynamic> row) {
    return VideoFeedEntry(
      id: row['id'] as int,
      title: row['title'] as String,
      summary: row['summary'] as String,
      videoUrl: row['video_url'] as String,
      link: row['link'] as String,
      source: row['source'] as String,
      category: row['category'] as String,
      publishedAt: DateTime.parse(row['published_at'] as String),
      readTime: row['read_time'] as int,
      thumbnailUrl: row['thumbnail_url'] as String?,
      conversationStarters: _decodeStarters(row['conversation_starters']),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Reels
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> cacheReels(List<ReelFeedEntry> reels) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();

    for (final reel in reels) {
      batch.insert(
          'reels',
          {
            'id': reel.id,
            'title': reel.title,
            'summary': reel.summary,
            'video_url': reel.videoUrl,
            'link': reel.link,
            'source': reel.source,
            'published_at': reel.publishedAt.toIso8601String(),
            'thumbnail_url': reel.thumbnailUrl,
            'conversation_starters': reel.conversationStarters.isNotEmpty
                ? jsonEncode(reel.conversationStarters)
                : null,
            'cached_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
  }

  @override
  Future<List<ReelFeedEntry>> getCachedReels({int limit = 50}) async {
    final db = await database;
    final results = await db.query(
      'reels',
      orderBy: 'published_at DESC',
      limit: limit,
    );

    return results.map(_reelFromRow).toList();
  }

  ReelFeedEntry _reelFromRow(Map<String, dynamic> row) {
    return ReelFeedEntry(
      id: row['id'] as int,
      title: row['title'] as String,
      summary: row['summary'] as String,
      videoUrl: row['video_url'] as String,
      link: row['link'] as String,
      source: row['source'] as String,
      publishedAt: DateTime.parse(row['published_at'] as String),
      thumbnailUrl: row['thumbnail_url'] as String?,
      conversationStarters: _decodeStarters(row['conversation_starters']),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Combined Feed (Articles + Videos)
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns combined articles and videos sorted by published date.
  @override
  Future<List<FeedEntry>> getCachedFeed({
    int articleLimit = 15,
    int videoLimit = 10,
  }) async {
    final articles = await getCachedArticles(limit: articleLimit);
    final videos = await getCachedVideos(limit: videoLimit);

    return [...articles, ...videos]
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
  }

  /// Caches a mixed feed by separating articles and videos.
  @override
  Future<void> cacheFeed(List<FeedEntry> entries) async {
    final articles = entries.whereType<ArticleFeedEntry>().toList();
    final videos = entries.whereType<VideoFeedEntry>().toList();

    await Future.wait([
      if (articles.isNotEmpty) cacheArticles(articles),
      if (videos.isNotEmpty) cacheVideos(videos),
    ]);
  }

  @override
  Future<DateTime?> getFeedLastSeenAt() async {
    final db = await database;
    final rows = await db.query(
      'cache_meta',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [_feedLastSeenAtKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final raw = rows.first['value'] as String?;
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  @override
  Future<void> setFeedLastSeenAt(DateTime lastSeenAt) async {
    final db = await database;
    await db.insert(
        'cache_meta',
        {
          'key': _feedLastSeenAtKey,
          'value': lastSeenAt.toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Cache management
  // ─────────────────────────────────────────────────────────────────────────

  /// Clears all cached data.
  Future<void> clearAll() async {
    final db = await database;
    await db.delete('articles');
    await db.delete('videos');
    await db.delete('reels');
  }

  /// Clears stale cache entries older than [maxAge].
  Future<void> clearStale({Duration maxAge = const Duration(hours: 24)}) async {
    final db = await database;
    final cutoff = DateTime.now().subtract(maxAge).toIso8601String();

    await db.delete('articles', where: 'cached_at < ?', whereArgs: [cutoff]);
    await db.delete('videos', where: 'cached_at < ?', whereArgs: [cutoff]);
    await db.delete('reels', where: 'cached_at < ?', whereArgs: [cutoff]);
  }

  /// Returns true if there is any cached feed data.
  Future<bool> hasCachedFeed() async {
    final db = await database;
    final articleCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM articles'),
    );
    final videoCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM videos'),
    );
    return (articleCount ?? 0) > 0 || (videoCount ?? 0) > 0;
  }

  /// Returns true if there are any cached reels.
  Future<bool> hasCachedReels() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM reels'),
    );
    return (count ?? 0) > 0;
  }
}
