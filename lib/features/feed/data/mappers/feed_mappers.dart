import 'dart:math';

import 'package:blips_mobile/features/feed/domain/feed_entry.dart';

const _unsplashBase = 'https://images.unsplash.com/';

const _fallbackImagePaths = <String, String>{
  'Technology': 'photo-1518770660439-4636190af475?w=800',
  'Artificial Intelligence': 'photo-1677442136019-21780ecad995?w=800',
  'Mobile': 'photo-1511707171634-5f897ff02aa9?w=800',
  'Gaming': 'photo-1493711662062-fa541f7f7d60?w=800',
  'Hardware': 'photo-1518770660439-4636190af475?w=800',
  'Software': 'photo-1555066931-4365d14bab8c?w=800',
  'Reviews': 'photo-1531297484001-80022131f5a1?w=800',
  'Science': 'photo-1507413245164-6160d8298b31?w=800',
  'Business': 'photo-1460925895917-afdab827c52f?w=800',
  'default': 'photo-1504384308090-c894fdcc538d?w=800',
};

final _fallbackImages = _fallbackImagePaths.map(
  (key, path) => MapEntry(key, '$_unsplashBase$path'),
);

final _random = Random();

/// Utility helpers for providing feed fallbacks.
class FeedFallbacks {
  const FeedFallbacks._();

  /// Picks a fallback image for a given [category].
  static String imageForCategory(String? category) {
    if (category != null && _fallbackImages.containsKey(category)) {
      return _fallbackImages[category]!;
    }

    final keys = _fallbackImages.keys
        .where((key) => key != 'default')
        .toList(growable: false);
    return keys.isEmpty
        ? _fallbackImages['default']!
        : _fallbackImages[keys[_random.nextInt(keys.length)]]!;
  }
}

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
