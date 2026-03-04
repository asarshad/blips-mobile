/// Riverpod providers for the onboarding interest selection feature.
///
/// Provides:
/// - [interestsLocalServiceProvider] – singleton local service
/// - [interestsRemoteServiceProvider] – singleton remote service
/// - [onboardingDoneProvider] – async bool, true once onboarding complete
/// - [selectedCategoriesProvider] – current in-progress selection (max 3)
/// - [interestsNotifierProvider] – combined notifier: load / toggle / save
library;

import 'dart:async';

import 'package:blips_mobile/core/network/dio_provider.dart';
import 'package:blips_mobile/core/services/device_id_service.dart';
import 'package:blips_mobile/features/onboarding/data/interests_local_service.dart';
import 'package:blips_mobile/features/onboarding/data/interests_remote_service.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

// ─── Service providers ────────────────────────────────────────────────────

final interestsLocalServiceProvider = Provider<InterestsLocalService>(
  (ref) => InterestsLocalService(),
);

final interestsRemoteServiceProvider = Provider<InterestsRemoteService>(
  (ref) => InterestsRemoteService(ref.watch(dioProvider)),
);

// ─── Onboarding gate ─────────────────────────────────────────────────────

/// Async bool – true once the user has seen/dismissed the interest screen.
///
/// Re-evaluated each time [onboardingDoneProvider] is invalidated.
final onboardingDoneProvider = FutureProvider<bool>((ref) async {
  final local = ref.watch(interestsLocalServiceProvider);
  return local.isOnboardingDone();
});

// ─── Interest selection notifier ─────────────────────────────────────────

/// Max number of categories the user may select.
const kMaxSelectedCategories = 3;

/// State: currently selected category IDs.
class InterestsNotifier extends StateNotifier<List<String>> {
  InterestsNotifier(this._local, this._remote, this._deviceIdFuture)
      : super(const []) {
    _load();
  }

  final InterestsLocalService _local;
  final InterestsRemoteService _remote;
  final Future<String> _deviceIdFuture;

  /// Load persisted selection from disk.
  Future<void> _load() async {
    final saved = await _local.loadSelectedCategories();
    state = List.unmodifiable(saved);
  }

  /// Toggle a category on or off.
  ///
  /// If [id] is already selected it is removed.
  /// If not selected and [state.length] < [kMaxSelectedCategories] it is added.
  /// Adding beyond the max is silently ignored (UI should show feedback).
  void toggle(String id) {
    if (state.contains(id)) {
      state = List.unmodifiable(state.where((c) => c != id).toList());
    } else if (state.length < kMaxSelectedCategories) {
      state = List.unmodifiable([...state, id]);
    }
  }

  /// Returns true if adding [id] would exceed the selection limit.
  bool isAtCapacity(String id) =>
      !state.contains(id) && state.length >= kMaxSelectedCategories;

  /// Persist locally, sync to backend (fire-and-forget), mark onboarding done.
  Future<void> save() async {
    final categories = List<String>.unmodifiable(state);
    await _local.saveSelectedCategories(categories);
    await _local.markOnboardingDone();

    // Best-effort remote sync – swallows all errors.
    final deviceId = await _deviceIdFuture;
    unawaited(
      _remote.syncCategories(
        deviceId: deviceId,
        selectedCategories: categories,
      ),
    );
  }

  /// Skip without selecting – marks onboarding done, clears selection.
  Future<void> skip() async {
    state = const [];
    await _local.saveSelectedCategories(const []);
    await _local.markOnboardingDone();
  }
}

final interestsNotifierProvider =
    StateNotifierProvider<InterestsNotifier, List<String>>((ref) {
  final local = ref.watch(interestsLocalServiceProvider);
  final remote = ref.watch(interestsRemoteServiceProvider);
  // Provide the future; the notifier resolves it internally without blocking.
  final deviceIdFuture = ref.watch(deviceIdProvider.future);
  return InterestsNotifier(local, remote, deviceIdFuture);
});
