import 'package:blips_mobile/core/config/app_config.dart';
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

/// Resolves backend media URLs into URLs Flutter can request directly.
///
/// The backend may emit relative URLs for generated placeholders when the
/// public API origin is not configured server-side. Dio resolves those for API
/// calls, but `Image.network` does not know the API base URL, so normalize here
/// before the value reaches the UI/cache layer.
String? normalizeBackendMediaUrl(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;

  final uri = Uri.tryParse(trimmed);
  if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
    return trimmed;
  }

  if (!trimmed.startsWith('/')) {
    return trimmed;
  }

  final base = Uri.parse(AppConfig.backendBaseUrl);
  return base.resolve(trimmed).toString();
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
