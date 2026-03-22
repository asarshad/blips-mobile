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

/// Resolves a publication timestamp, falling back to creation date.
DateTime resolvePublishedDate(
  String? published,
  String? created, {
  DateTime Function() now = DateTime.now,
}) {
  if (published != null && published.isNotEmpty) {
    return DateTime.tryParse(published) ?? now().toUtc();
  }
  if (created != null && created.isNotEmpty) {
    return DateTime.tryParse(created)?.toUtc() ?? now().toUtc();
  }
  return now().toUtc();
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
