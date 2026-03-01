import 'package:blips_mobile/features/feed/data/mappers/feed_mappers.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';

/// DTO describing an article returned from the backend feed endpoint.
class ArticleDto {
  /// Creates an [ArticleDto] using the serialized API payload.
  const ArticleDto({
    required this.id,
    required this.title,
    required this.sourceUrl,
    this.summary,
    this.imageUrl,
    this.publishedDate,
    this.publishedAt,
    this.createdAt,
    this.readTimeMinutes,
    this.tags = const <ArticleTagDto>[],
    this.freshnessTier,
    this.freshnessReason,
    this.publishedAgeSeconds,
    this.addedAgeSeconds,
    this.conversationStarters = const <String>[],
  });

  /// Parses an [ArticleDto] from a JSON map.
  factory ArticleDto.fromJson(Map<String, dynamic> json) {
    return ArticleDto(
      id: json['id'] as int,
      title: json['title'] as String,
      sourceUrl: json['source_url'] as String,
      summary: json['summary'] as String?,
      imageUrl: _nullIfBlank(json['image_url'] as String?),
      publishedDate: json['published_date'] as String?,
      publishedAt: json['published_at'] as String?,
      createdAt: json['created_at'] as String?,
      readTimeMinutes: json['read_time_minutes'] as int?,
      tags: (json['tags'] as List<dynamic>? ?? [])
          .map(
            (tag) => ArticleTagDto.fromJson(
              Map<String, dynamic>.from(tag as Map),
            ),
          )
          .toList(growable: false),
      freshnessTier: json['freshness_tier'] as String?,
      freshnessReason: json['freshness_reason'] as String?,
      publishedAgeSeconds: json['published_age_seconds'] as int?,
      addedAgeSeconds: json['added_age_seconds'] as int?,
      conversationStarters: _parseStarters(json['conversation_starters']),
    );
  }

  /// Serializes this DTO back to JSON.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'source_url': sourceUrl,
        'summary': summary,
        'image_url': imageUrl,
        'published_date': publishedDate,
        'published_at': publishedAt,
        'created_at': createdAt,
        'read_time_minutes': readTimeMinutes,
        'tags': tags.map((tag) => tag.toJson()).toList(growable: false),
        'freshness_tier': freshnessTier,
        'freshness_reason': freshnessReason,
        'published_age_seconds': publishedAgeSeconds,
        'added_age_seconds': addedAgeSeconds,
        'conversation_starters': conversationStarters.isNotEmpty
            ? {'starters': conversationStarters}
            : null,
      };

  /// Unique article identifier.
  final int id;

  /// Textual headline or title.
  final String title;

  /// Canonical URL of the article.
  final String sourceUrl;

  /// Optional summary body from the backend.
  final String? summary;

  /// Optional hero image URL.
  final String? imageUrl;

  /// Publish date in ISO-8601 format (date only, backward compatible).
  final String? publishedDate;

  /// Full publish timestamp in ISO-8601 format.
  final String? publishedAt;

  /// Creation timestamp in ISO-8601 format.
  final String? createdAt;

  /// Estimated read time provided by the backend.
  final int? readTimeMinutes;

  /// Tag metadata attached to the article.
  final List<ArticleTagDto> tags;

  /// Freshness tier: "A" (fresh), "B" (recently added), "C" (evergreen).
  final String? freshnessTier;

  /// Human-readable reason: "fresh_published", "recently_added", "evergreen".
  final String? freshnessReason;

  /// Seconds since publication.
  final int? publishedAgeSeconds;

  /// Seconds since ingestion.
  final int? addedAgeSeconds;

  /// Pre-generated conversation starter questions.
  final List<String> conversationStarters;

  /// Returns null for empty or whitespace-only strings.
  static String? _nullIfBlank(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return value;
  }

  /// Parses the starters list from the nested JSON structure.
  static List<String> _parseStarters(dynamic json) {
    if (json is Map<String, dynamic>) {
      final starters = json['starters'];
      if (starters is List) {
        return starters
            .whereType<String>()
            .where((s) => s.trim().isNotEmpty)
            .toList();
      }
    }
    return const <String>[];
  }
}

/// DTO describing an individual tag attached to an article.
class ArticleTagDto {
  /// Creates a tag DTO used inside [ArticleDto].
  const ArticleTagDto({required this.name});

  /// Parses a tag DTO from JSON.
  factory ArticleTagDto.fromJson(Map<String, dynamic> json) =>
      ArticleTagDto(name: json['name'] as String);

  /// Serializes the tag back to JSON.
  Map<String, dynamic> toJson() => <String, dynamic>{'name': name};

  /// Tag display label.
  final String name;
}

/// Maps API article payloads into the domain model consumed by the UI.
extension ArticleDtoX on ArticleDto {
  /// Converts the DTO to an [ArticleFeedEntry] instance.
  ArticleFeedEntry toDomain() {
    final summaryText = (summary ?? '').trim();
    final category = tags.isNotEmpty ? tags.first.name : 'Technology';
    return ArticleFeedEntry(
      id: id,
      title: title,
      summary: summaryText,
      source: deriveSource(sourceUrl),
      publishedAt:
          resolvePublishedDate(publishedAt ?? publishedDate, createdAt),
      addedAt: createdAt != null ? DateTime.tryParse(createdAt!) : null,
      url: sourceUrl,
      imageUrl: imageUrl ?? FeedFallbacks.imageForCategory(category),
      category: category,
      readTime: readTimeMinutes ?? computeReadTime(summaryText),
      tags: tags.map((tag) => tag.name).toList(growable: false),
      freshnessTier: _parseFreshnessTier(freshnessTier),
      freshnessReason: freshnessReason,
      conversationStarters: conversationStarters,
    );
  }

  /// Parse freshness tier from string.
  FreshnessTier _parseFreshnessTier(String? tier) {
    switch (tier) {
      case 'A':
        return FreshnessTier.fresh;
      case 'B':
        return FreshnessTier.recentlyAdded;
      case 'C':
        return FreshnessTier.evergreen;
      default:
        return FreshnessTier.fresh;
    }
  }
}
