/// Freshness tier indicating how content was selected.
enum FreshnessTier {
  /// Tier A: Recently published content.
  fresh,

  /// Tier B: Recently added but older publication.
  recentlyAdded,

  /// Tier C: Evergreen high-quality content.
  evergreen,
}

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

  /// When the content was added to our system (optional).
  DateTime? get addedAt;

  /// Freshness tier: fresh, recentlyAdded, or evergreen.
  FreshnessTier get freshnessTier;

  /// Human-readable reason for tier selection.
  String? get freshnessReason;

  /// Pre-generated conversation starter questions.
  List<String> get conversationStarters;
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
    this.imageUrl,
    required this.category,
    required this.readTime,
    List<String> tags = const <String>[],
    this.addedAt,
    this.freshnessTier = FreshnessTier.fresh,
    this.freshnessReason,
    this.conversationStarters = const <String>[],
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

  /// When the article was added to our system.
  @override
  final DateTime? addedAt;

  /// Freshness tier for display purposes.
  @override
  final FreshnessTier freshnessTier;

  /// Human-readable reason for tier.
  @override
  final String? freshnessReason;

  /// Canonical article URL used when opening in browser.
  final String url;

  /// Optional hero image displayed behind the card contents.
  final String? imageUrl;

  /// Category label used for chips.
  final String category;

  /// Estimated read time in minutes.
  final int readTime;

  /// Associated topic tags.
  final List<String> tags;

  /// Pre-generated conversation starter questions.
  @override
  final List<String> conversationStarters;
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
    this.durationSeconds,
    this.thumbnailUrl,
    this.addedAt,
    this.freshnessTier = FreshnessTier.fresh,
    this.freshnessReason,
    this.conversationStarters = const <String>[],
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

  /// When the video was added to our system.
  @override
  final DateTime? addedAt;

  /// Freshness tier for display purposes.
  @override
  final FreshnessTier freshnessTier;

  /// Human-readable reason for tier.
  @override
  final String? freshnessReason;

  /// Approximate duration shown to the user.
  final int readTime;

  /// Exact duration in seconds when provided by the backend.
  final int? durationSeconds;

  /// Optional thumbnail preview.
  final String? thumbnailUrl;

  /// Pre-generated conversation starter questions.
  @override
  final List<String> conversationStarters;
}

/// Reel variant shown for short videos.
class ReelFeedEntry extends FeedEntry {
  /// Creates a reel entry.
  ReelFeedEntry({
    required this.id,
    required this.title,
    required this.summary,
    required this.videoUrl,
    required this.link,
    required this.source,
    required this.publishedAt,
    this.durationSeconds,
    this.thumbnailUrl,
    this.addedAt,
    this.freshnessTier = FreshnessTier.fresh,
    this.freshnessReason,
    this.conversationStarters = const <String>[],
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

  /// Publish timestamp used for ordering.
  @override
  final DateTime publishedAt;

  /// Exact duration in seconds when provided by the backend.
  final int? durationSeconds;

  /// When the reel was added to our system.
  @override
  final DateTime? addedAt;

  /// Freshness tier for display purposes.
  @override
  final FreshnessTier freshnessTier;

  /// Human-readable reason for tier.
  @override
  final String? freshnessReason;

  /// Optional thumbnail preview.
  final String? thumbnailUrl;

  /// Pre-generated conversation starter questions.
  @override
  final List<String> conversationStarters;
}

/// Ad feed entry — a synthetic item injected by the backend ad mixer.
///
/// Must live in this file because [FeedEntry] is `sealed`.
/// When the backend has ads disabled (default), no [AdFeedEntry] objects
/// are ever created.
class AdFeedEntry extends FeedEntry {
  /// Creates an ad feed entry from backend payload.
  const AdFeedEntry({
    required this.adId,
    required this.placementId,
    required this.sponsorName,
    this.title = '',
    this.body,
    this.imageUrl,
    this.clickUrl,
    this.label = 'Sponsored',
    this.impressionUrl,
    this.campaignId,
    this.priority,
  });

  /// Parses an [AdFeedEntry] from a JSON map (`item_type == "AD"`).
  factory AdFeedEntry.fromJson(Map<String, dynamic> json) {
    final tracking = json['tracking'] as Map<String, dynamic>?;
    final metadata = json['metadata'] as Map<String, dynamic>?;

    return AdFeedEntry(
      adId: json['ad_id'] as String,
      placementId: json['placement_id'] as String,
      sponsorName: json['sponsor_name'] as String,
      title: json['title'] as String? ?? '',
      body: json['body'] as String?,
      imageUrl: json['image_url'] as String?,
      clickUrl: json['click_url'] as String?,
      label: json['label'] as String? ?? 'Sponsored',
      impressionUrl: tracking?['impression_url'] as String?,
      campaignId: metadata?['campaign_id'] as String?,
      priority: metadata?['priority'] as int?,
    );
  }

  /// Unique ad identifier.
  final String adId;

  /// Surface placement (e.g. "feed_fullpage", "banner_bottom").
  final String placementId;

  /// Sponsor display name.
  final String sponsorName;

  /// Ad headline.
  @override
  final String title;

  /// Optional ad body text.
  final String? body;

  /// Optional hero image URL.
  final String? imageUrl;

  /// URL opened when the user taps the ad.
  final String? clickUrl;

  /// Badge text — always "Sponsored".
  final String label;

  /// Optional impression tracking URL.
  final String? impressionUrl;

  /// Optional campaign identifier (for analytics).
  final String? campaignId;

  /// Optional priority level from ad backend.
  final int? priority;

  // ── FeedEntry contract ──────────────────────────────────────

  /// Uses a hash-based int so ad entries participate in deduplication.
  @override
  int get id => adId.hashCode;

  /// Ads have no meaningful summary — return the body or empty string.
  @override
  String get summary => body ?? '';

  /// Ads are never sorted by date — use epoch as a sentinel.
  @override
  DateTime get publishedAt => DateTime.fromMillisecondsSinceEpoch(0);

  @override
  DateTime? get addedAt => null;

  @override
  FreshnessTier get freshnessTier => FreshnessTier.fresh;

  @override
  String? get freshnessReason => null;

  @override
  List<String> get conversationStarters => const <String>[];
}

/// Pattern-matching helper that replaces the Freezed `when` utility.
extension FeedEntryMatch on FeedEntry {
  /// Maps the entry to a type [T] based on its concrete subtype.
  ///
  /// The optional [ad] callback handles [AdFeedEntry] items injected by the
  /// backend ad mixer. When omitted, ad entries throw a [StateError].
  T when<T>({
    required T Function(ArticleFeedEntry article) article,
    required T Function(VideoFeedEntry video) video,
    required T Function(ReelFeedEntry reel) reel,
    T Function(AdFeedEntry ad)? ad,
  }) {
    final entry = this;
    if (entry is ArticleFeedEntry) {
      return article(entry);
    }
    if (entry is VideoFeedEntry) {
      return video(entry);
    }
    if (entry is ReelFeedEntry) {
      return reel(entry);
    }
    if (entry is AdFeedEntry) {
      if (ad != null) return ad(entry);
      throw StateError('AdFeedEntry encountered but no ad callback provided');
    }
    throw StateError('Unhandled FeedEntry subtype: $entry');
  }
}
