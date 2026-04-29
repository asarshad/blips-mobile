/// Persists a set of sources the user has blocked ("Block [source]" action).
///
/// Blocking a source removes its items from every feed immediately by having
/// each feed tab filter its [AsyncValue<List<FeedPageItem>>] through
/// [filterBlocked] before passing the list to the PageView builder.
///
/// Backed by SharedPreferences so the list survives app restarts.
library;

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'blips_blocked_sources_v1';

class BlockedSourcesNotifier extends StateNotifier<Set<String>> {
  BlockedSourcesNotifier() : super(const {}) {
    _load();
  }

  /// No-load constructor for subclasses that don't need persistence
  /// (e.g. test fakes). Does not call [_load].
  BlockedSourcesNotifier.empty() : super(const {});

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_prefsKey) ?? const [];
    state = stored.toSet();
  }

  /// Immediately removes [source] from all feeds and persists the choice.
  Future<void> block(String source) async {
    state = {...state, source};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, state.toList());
  }
}

final blockedSourcesProvider =
    StateNotifierProvider<BlockedSourcesNotifier, Set<String>>(
  (ref) => BlockedSourcesNotifier(),
);
