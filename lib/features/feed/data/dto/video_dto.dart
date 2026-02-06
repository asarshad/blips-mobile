import 'package:blips_mobile/features/feed/data/mappers/feed_mappers.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';

/// DTO describing a short-form video entry returned by the backend.
class VideoDto {
  /// Creates a [VideoDto] representation of the serialized payload.
  const VideoDto({
    required this.id,
    required this.title,
    required this.videoUrl,
    required this.sourceUrl,
    this.summary,
    this.thumbnailUrl,
    this.source,
    this.category,
    this.durationSeconds,
    this.createdAt,
    this.publishedAt,
    this.freshnessTier,
    this.freshnessReason,
    this.publishedAgeSeconds,
    this.addedAgeSeconds,
  });

  /// Parses a [VideoDto] from JSON.
  factory VideoDto.fromJson(Map<String, dynamic> json) => VideoDto(
        id: json['id'] as int,
        title: json['title'] as String,
        videoUrl: json['video_url'] as String,
        sourceUrl: json['source_url'] as String,
        summary: json['summary'] as String?,
        thumbnailUrl: json['thumbnail_url'] as String?,
        source: json['source'] as String?,
        category: json['category'] as String?,
        durationSeconds: json['duration_seconds'] as int?,
        createdAt: json['created_at'] as String?,
        publishedAt: json['published_at'] as String?,
        freshnessTier: json['freshness_tier'] as String?,
        freshnessReason: json['freshness_reason'] as String?,
        publishedAgeSeconds: json['published_age_seconds'] as int?,
        addedAgeSeconds: json['added_age_seconds'] as int?,
      );

  /// Serializes this DTO back to JSON.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'video_url': videoUrl,
        'source_url': sourceUrl,
        'summary': summary,
        'thumbnail_url': thumbnailUrl,
        'source': source,
        'category': category,
        'duration_seconds': durationSeconds,
        'created_at': createdAt,
        'published_at': publishedAt,
        'freshness_tier': freshnessTier,
        'freshness_reason': freshnessReason,
        'published_age_seconds': publishedAgeSeconds,
        'added_age_seconds': addedAgeSeconds,
      };

  /// Unique video identifier.
  final int id;

  /// Video title provided by the source.
  final String title;

  /// Direct video playback URL.
  final String videoUrl;

  /// Source permalink for the video.
  final String sourceUrl;

  /// Optional backend-provided summary transcript.
  final String? summary;

  /// Thumbnail preview image.
  final String? thumbnailUrl;

  /// Channel or publisher name.
  final String? source;

  /// Category label grouping similar videos.
  final String? category;

  /// Total length of the video in seconds.
  final int? durationSeconds;

  /// Creation timestamp in ISO-8601 format.
  final String? createdAt;

  /// Full publish timestamp in ISO-8601 format.
  final String? publishedAt;

  /// Freshness tier: "A" (fresh), "B" (recently added), "C" (evergreen).
  final String? freshnessTier;

  /// Human-readable reason: "fresh_published", "recently_added", "evergreen".
  final String? freshnessReason;

  /// Seconds since publication.
  final int? publishedAgeSeconds;

  /// Seconds since ingestion.
  final int? addedAgeSeconds;
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

/// Maps API video payloads into the domain representation.
extension VideoDtoX on VideoDto {
  /// Converts the DTO into a [VideoFeedEntry] instance.
  FeedEntry toDomain() {
    final summaryText = (summary ?? '').trim();
    final durationMinutes = durationSeconds == null
        ? computeReadTime(summaryText)
        : (durationSeconds! / 60).ceil();
    return VideoFeedEntry(
      id: id,
      title: title,
      summary: summaryText,
      videoUrl: videoUrl,
      link: sourceUrl,
      thumbnailUrl: thumbnailUrl,
      source: source ?? 'YouTube',
      category: category ?? 'Technology',
      publishedAt: resolvePublishedDate(publishedAt ?? createdAt, createdAt),
      addedAt: createdAt != null ? DateTime.tryParse(createdAt!) : null,
      readTime: durationMinutes,
      freshnessTier: _parseFreshnessTier(freshnessTier),
      freshnessReason: freshnessReason,
    );
  }

  /// Converts the DTO into a [ReelFeedEntry] instance.
  ReelFeedEntry toReelDomain() {
    final summaryText = (summary ?? '').trim();
    return ReelFeedEntry(
      id: id,
      title: title,
      summary: summaryText,
      videoUrl: videoUrl,
      link: sourceUrl,
      thumbnailUrl: thumbnailUrl,
      source: source ?? 'YouTube',
      publishedAt: resolvePublishedDate(publishedAt ?? createdAt, createdAt),
      addedAt: createdAt != null ? DateTime.tryParse(createdAt!) : null,
      freshnessTier: _parseFreshnessTier(freshnessTier),
      freshnessReason: freshnessReason,
    );
  }
}
