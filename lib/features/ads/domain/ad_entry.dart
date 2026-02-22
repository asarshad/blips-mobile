/// Re-exports [AdFeedEntry] from the sealed [FeedEntry] hierarchy.
///
/// The actual class lives in `feed_entry.dart` because Dart 3 requires
/// sealed-class subtypes to reside in the same library.
export 'package:blips_mobile/features/feed/domain/feed_entry.dart'
    show AdFeedEntry;
