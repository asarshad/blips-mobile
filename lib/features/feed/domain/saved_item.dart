import 'package:blips_mobile/features/feed/domain/feed_entry.dart';

enum SavedVideoType {
  video,
  reel;

  String get storageValue => switch (this) {
        SavedVideoType.video => 'VIDEO',
        SavedVideoType.reel => 'REEL',
      };

  static SavedVideoType fromStorage(String? value) {
    return switch (value?.trim().toUpperCase()) {
      'REEL' => SavedVideoType.reel,
      _ => SavedVideoType.video,
    };
  }
}

/// Lightweight saved article metadata used by the Saved tab.
class SavedArticleItem {
  const SavedArticleItem({
    required this.contentId,
    required this.sourceUrl,
    required this.title,
    required this.source,
    this.imageUrl,
    required this.category,
    required this.publishedAt,
    required this.savedAt,
  });

  factory SavedArticleItem.fromFeedEntry(
    ArticleFeedEntry entry, {
    DateTime? savedAt,
  }) {
    return SavedArticleItem(
      contentId: entry.id,
      sourceUrl: entry.url,
      title: entry.title,
      source: entry.source,
      imageUrl: entry.imageUrl,
      category: entry.category,
      publishedAt: entry.publishedAt,
      savedAt: savedAt ?? DateTime.now(),
    );
  }

  final int contentId;
  final String sourceUrl;
  final String title;
  final String source;
  final String? imageUrl;
  final String category;
  final DateTime publishedAt;
  final DateTime savedAt;

  SavedArticleItem copyWith({
    DateTime? savedAt,
  }) {
    return SavedArticleItem(
      contentId: contentId,
      sourceUrl: sourceUrl,
      title: title,
      source: source,
      imageUrl: imageUrl,
      category: category,
      publishedAt: publishedAt,
      savedAt: savedAt ?? this.savedAt,
    );
  }
}

/// Lightweight saved video metadata used by the Saved tab.
class SavedVideoItem {
  const SavedVideoItem({
    required this.contentId,
    required this.type,
    required this.sourceUrl,
    required this.title,
    required this.source,
    this.thumbnailUrl,
    required this.category,
    required this.publishedAt,
    required this.savedAt,
  });

  factory SavedVideoItem.fromFeedEntry(
    VideoFeedEntry entry, {
    DateTime? savedAt,
  }) {
    return SavedVideoItem(
      contentId: entry.id,
      type: SavedVideoType.video,
      sourceUrl: entry.link,
      title: entry.title,
      source: entry.source,
      thumbnailUrl: entry.thumbnailUrl,
      category: entry.category,
      publishedAt: entry.publishedAt,
      savedAt: savedAt ?? DateTime.now(),
    );
  }

  factory SavedVideoItem.fromReelEntry(
    ReelFeedEntry entry, {
    DateTime? savedAt,
  }) {
    return SavedVideoItem(
      contentId: entry.id,
      type: SavedVideoType.reel,
      sourceUrl: entry.link,
      title: entry.title,
      source: entry.source,
      thumbnailUrl: entry.thumbnailUrl,
      category: 'Reel',
      publishedAt: entry.publishedAt,
      savedAt: savedAt ?? DateTime.now(),
    );
  }

  final int contentId;
  final SavedVideoType type;
  final String sourceUrl;
  final String title;
  final String source;
  final String? thumbnailUrl;
  final String category;
  final DateTime publishedAt;
  final DateTime savedAt;

  SavedVideoItem copyWith({
    SavedVideoType? type,
    DateTime? savedAt,
  }) {
    return SavedVideoItem(
      contentId: contentId,
      type: type ?? this.type,
      sourceUrl: sourceUrl,
      title: title,
      source: source,
      thumbnailUrl: thumbnailUrl,
      category: category,
      publishedAt: publishedAt,
      savedAt: savedAt ?? this.savedAt,
    );
  }
}
