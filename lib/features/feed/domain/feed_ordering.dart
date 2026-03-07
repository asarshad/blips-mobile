import 'package:blips_mobile/features/feed/domain/feed_entry.dart';

/// Merge fresh feed data while keeping ordering stable when nothing new exists.
///
/// Behavior:
/// - If no new IDs are present in [freshItems], preserve [currentItems] order.
/// - If new IDs exist, prepend those new entries in fresh rank order.
/// - Existing entries keep their previous relative order to avoid jumpiness.
List<FeedEntry> mergeFeedWithStableOrdering({
  required List<FeedEntry> currentItems,
  required List<FeedEntry> freshItems,
}) {
  if (currentItems.isEmpty) return List<FeedEntry>.from(freshItems);

  final currentIds = currentItems.map((entry) => entry.id).toSet();
  final freshById = <int, FeedEntry>{
    for (final item in freshItems) item.id: item,
  };
  final newItems = freshItems
      .where((item) => !currentIds.contains(item.id))
      .toList();

  // No newly approved items: keep today's order stable.
  if (newItems.isEmpty) {
    return currentItems
        .where((item) => freshById.containsKey(item.id))
        .map((item) => freshById[item.id]!)
        .toList();
  }

  // New items surface first; existing entries keep previous order.
  final carried = currentItems
      .where((item) => freshById.containsKey(item.id))
      .map((item) => freshById[item.id]!)
      .toList();
  return <FeedEntry>[...newItems, ...carried];
}
