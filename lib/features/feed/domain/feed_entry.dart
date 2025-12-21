/// Sealed base class describing feed entries used by the UI.
sealed class FeedEntry {
  const FeedEntry();

  /// Entry identifier from the backend.
  int get id;

  /// Human-friendly title.
  String get title;

  /// Short description or summary transcript.
  String get summary;

  /// Publication timestamp, used for sorting.
  DateTime get publishedAt;
}

/// Article variant shown for written stories.
class ArticleFeedEntry extends FeedEntry {
  /// Creates an article entry.
  ArticleFeedEntry({
    required this.id,
    required this.title,
    required this.summary,
    required this.source,
    required this.publishedAt,
    required this.url,
    required this.imageUrl,
    required this.category,
    required this.readTime,
    List<String> tags = const <String>[],
  }) : tags = List.unmodifiable(tags);

  /// Unique article identifier.
  @override
  final int id;

  /// Human-readable title rendered in the card.
  @override
  final String title;

  /// Summary or snippet displayed beneath the title.
  @override
  final String summary;

  /// Source publication name (e.g., the domain).
  final String source;

  /// Publication timestamp for sorting.
  @override
  final DateTime publishedAt;

  /// Canonical article URL used when opening in browser.
  final String url;

  /// Hero image displayed behind the card contents.
  final String imageUrl;

  /// Category label used for chips.
  final String category;

  /// Estimated read time in minutes.
  final int readTime;

  /// Associated topic tags.
  final List<String> tags;
}

/// Video variant shown for short-form clips.
class VideoFeedEntry extends FeedEntry {
  /// Creates a video entry.
  VideoFeedEntry({
    required this.id,
    required this.title,
    required this.summary,
    required this.videoUrl,
    required this.link,
    required this.source,
    required this.category,
    required this.publishedAt,
    required this.readTime,
    this.thumbnailUrl,
  });

  /// Unique video identifier.
  @override
  final int id;

  /// Video title shown on the card.
  @override
  final String title;

  /// Summary snippet displayed below the title.
  @override
  final String summary;

  /// Direct video playback URL (e.g., mp4 or stream).
  final String videoUrl;

  /// External link for opening the video in the browser/app.
  final String link;

  /// Channel/publisher name.
  final String source;

  /// Category label for the video entry.
  final String category;

  /// Publish timestamp used for ordering.
  @override
  final DateTime publishedAt;

  /// Approximate duration shown to the user.
  final int readTime;

  /// Optional thumbnail preview.
  final String? thumbnailUrl;
}

/// Pattern-matching helper that replaces the Freezed `when` utility.
extension FeedEntryMatch on FeedEntry {
  /// Maps the entry to a type [T] based on its concrete subtype.
  T when<T>({
    required T Function(ArticleFeedEntry article) article,
    required T Function(VideoFeedEntry video) video,
  }) {
    final entry = this;
    if (entry is ArticleFeedEntry) {
      return article(entry);
    }
    if (entry is VideoFeedEntry) {
      return video(entry);
    }
    throw StateError('Unhandled FeedEntry subtype: $entry');
  }
}
