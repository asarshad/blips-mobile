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

/// Counts only the contiguous new prefix ahead of the current session head.
///
/// This is intentionally stricter than a generic set-difference count.
/// If the top story is unchanged and only lower items within the head batch
/// rotate, we do not surface a "new items" pill because tapping it jumps the
/// user back to the top. The pill should only appear when there are genuinely
/// new items ahead of the current head.
int countLeadingHeadNewItems({
  required List<int> baselineIds,
  required List<int> freshHeadIds,
}) {
  if (baselineIds.isEmpty || freshHeadIds.isEmpty) return 0;

  final baseline = baselineIds.toSet();
  var count = 0;
  for (final id in freshHeadIds) {
    if (baseline.contains(id)) {
      break;
    }
    count += 1;
  }
  return count;
}
