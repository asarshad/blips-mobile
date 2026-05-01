import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Tracks the stableIds of native ad slots that received no fill from AdMob.
///
/// Feed tabs watch this and filter out failed slots so the user never sees
/// a blank or placeholder page in place of an ad.
class FailedAdSlotsNotifier extends StateNotifier<Set<int>> {
  FailedAdSlotsNotifier() : super(const {});

  void markFailed(int stableId) {
    if (!state.contains(stableId)) {
      state = {...state, stableId};
    }
  }
}

final failedAdSlotsProvider =
    StateNotifierProvider<FailedAdSlotsNotifier, Set<int>>(
  (ref) => FailedAdSlotsNotifier(),
);
