import 'package:blips_mobile/features/feed/domain/feed_entry.dart';

/// Returns the best timestamp for "new since last seen" checks.
///
/// Prefer [FeedEntry.addedAt] so older evergreen content newly promoted into
/// the feed can still be marked as new to the user.
DateTime freshnessTimestampForEntry(FeedEntry entry) {
  return (entry.addedAt ?? entry.publishedAt).toUtc();
}

/// Computes IDs that should be marked as new for the current session.
Set<int> computeNewSinceLastSeenIds({
  required List<FeedEntry> entries,
  required DateTime? lastSeenAt,
}) {
  if (lastSeenAt == null) return <int>{};
  final cutoff = lastSeenAt.toUtc();
  return entries
      .where((entry) => freshnessTimestampForEntry(entry).isAfter(cutoff))
      .map((entry) => entry.id)
      .toSet();
}
