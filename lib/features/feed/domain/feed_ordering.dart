import 'package:blips_mobile/features/feed/domain/feed_entry.dart';

/// Merge fresh feed data while preserving deep-scroll stability.
///
/// [freshItems] may be a partial "page 1" snapshot rather than the
/// full feed.
/// To avoid truncating older loaded pages, entries missing from
/// [freshItems] are preserved from [currentItems].
///
/// Behavior:
/// - Existing entries keep their previous relative order.
/// - Entries that also exist in [freshItems] are updated with fresh payload.
/// - New entries from [freshItems] are prepended only when [prependNewItems]
///   is true.
List<FeedEntry> mergeFeedWithStableOrdering({
  required List<FeedEntry> currentItems,
  required List<FeedEntry> freshItems,
  bool prependNewItems = true,
}) {
  if (currentItems.isEmpty) return List<FeedEntry>.from(freshItems);

  final freshById = <int, FeedEntry>{
    for (final item in freshItems) item.id: item,
  };
  final currentIds = currentItems.map((entry) => entry.id).toSet();
  final newItems = freshItems
      .where((item) => !currentIds.contains(item.id))
      .toList(growable: false);

  final updatedCurrent = currentItems
      .map((item) => freshById[item.id] ?? item)
      .toList(growable: false);

  if (newItems.isEmpty || !prependNewItems) {
    return updatedCurrent;
  }

  return <FeedEntry>[...newItems, ...updatedCurrent];
}
