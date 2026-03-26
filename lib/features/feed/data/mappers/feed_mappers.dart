import 'package:blips_mobile/features/feed/domain/feed_entry.dart';

/// Extracts a readable source name from the provided [url].
String deriveSource(String url) {
  try {
    final uri = Uri.parse(url);
    return uri.host.replaceFirst('www.', '');
  } catch (_) {
    return 'Tech Whisperer';
  }
}

/// Estimates reading time in minutes for the given [summary].
int computeReadTime(String summary) {
  final words = summary.split(RegExp(r'\s+')).length;
  return words <= 0 ? 1 : (words / 200).round().clamp(1, 20);
}

/// Parses backend timestamps, treating timezone-less values as UTC.
DateTime? parseBackendDateTime(String? value) {
  if (value == null || value.isEmpty) return null;

  final parsed = DateTime.tryParse(value);
  if (parsed == null) return null;

  if (_hasExplicitTimezone(value)) {
    return parsed.toUtc();
  }

  return DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
    parsed.millisecond,
    parsed.microsecond,
  );
}

/// Resolves a publication timestamp, falling back to creation date.
DateTime resolvePublishedDate(
  String? published,
  String? created, {
  DateTime Function() now = DateTime.now,
}) {
  final publishedAt = parseBackendDateTime(published);
  if (publishedAt != null) return publishedAt;

  final createdAt = parseBackendDateTime(created);
  if (createdAt != null) return createdAt;

  return now().toUtc();
}

bool _hasExplicitTimezone(String value) {
  return RegExp(r'(?:Z|[+-]\d{2}:\d{2})$').hasMatch(value);
}

/// Convenience extension for pattern matching without manual type checks.
extension FeedEntryMapper on FeedEntry {
  /// Applies the correct mapper based on the runtime subtype.
  T map<T>({
    required T Function(ArticleFeedEntry article) article,
    required T Function(VideoFeedEntry video) video,
    required T Function(ReelFeedEntry reel) reel,
    T Function(dynamic ad)? ad,
  }) =>
      when(article: article, video: video, reel: reel, ad: ad);
}
