@Tags(['unit', 'onboarding'])
library interests_notifier_test;

import 'package:blips_mobile/features/onboarding/data/interests_local_service.dart';
import 'package:blips_mobile/features/onboarding/data/interests_remote_service.dart';
import 'package:blips_mobile/features/onboarding/providers/interests_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Fakes ──────────────────────────────────────────────────────────────────

/// In-memory stand-in for SharedPreferences-backed local service.
class _FakeLocalService extends InterestsLocalService {
  final List<String> _saved = [];
  bool _done = false;

  @override
  Future<List<String>> loadSelectedCategories() async => List.of(_saved);

  @override
  Future<void> saveSelectedCategories(List<String> cats) async {
    _saved
      ..clear()
      ..addAll(cats);
  }

  @override
  Future<bool> isOnboardingDone() async => _done;

  @override
  Future<void> markOnboardingDone() async => _done = true;
}

/// In-memory stand-in for the Dio-backed remote service.
class _FakeRemoteService extends InterestsRemoteService {
  _FakeRemoteService() : super(Dio()); // Dio instance never actually called

  int callCount = 0;
  List<String>? lastCategories;

  @override
  Future<void> syncCategories({
    required String deviceId,
    required List<String> selectedCategories,
  }) async {
    callCount++;
    lastCategories = List.of(selectedCategories);
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────

InterestsNotifier _makeNotifier({
  _FakeLocalService? local,
  _FakeRemoteService? remote,
}) {
  return InterestsNotifier(
    local ?? _FakeLocalService(),
    remote ?? _FakeRemoteService(),
    Future.value('test-device-id'),
  );
}

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  group('InterestsNotifier', () {
    late _FakeLocalService local;
    late _FakeRemoteService remote;
    late InterestsNotifier notifier;

    setUp(() {
      local = _FakeLocalService();
      remote = _FakeRemoteService();
      notifier = _makeNotifier(local: local, remote: remote);
    });

    tearDown(() => notifier.dispose());

    test('initial state is empty', () {
      expect(notifier.state, isEmpty);
    });

    test('toggle adds a category', () {
      notifier.toggle('AI');
      expect(notifier.state, contains('AI'));
    });

    test('toggle removes an already-selected category', () {
      notifier.toggle('AI');
      notifier.toggle('AI');
      expect(notifier.state, isNot(contains('AI')));
    });

    test('allows up to $kMaxSelectedCategories selections', () {
      notifier
        ..toggle('AI')
        ..toggle('Security')
        ..toggle('Cloud');

      expect(notifier.state.length, kMaxSelectedCategories);
    });

    test('ignores a 4th selection when at capacity', () {
      notifier
        ..toggle('AI')
        ..toggle('Security')
        ..toggle('Cloud')
        ..toggle('Mobile'); // should be silently ignored

      expect(notifier.state.length, kMaxSelectedCategories);
      expect(notifier.state, isNot(contains('Mobile')));
    });

    test('isAtCapacity is false when below limit', () {
      notifier.toggle('AI');
      expect(notifier.isAtCapacity('Security'), isFalse);
    });

    test('isAtCapacity is true for unselected chip when limit reached', () {
      notifier
        ..toggle('AI')
        ..toggle('Security')
        ..toggle('Cloud');

      expect(notifier.isAtCapacity('Mobile'), isTrue);
    });

    test('isAtCapacity is false for an already-selected chip at max', () {
      notifier
        ..toggle('AI')
        ..toggle('Security')
        ..toggle('Cloud');

      // 'AI' is selected — removing it is always allowed.
      expect(notifier.isAtCapacity('AI'), isFalse);
    });

    test('save persists selection locally', () async {
      notifier
        ..toggle('AI')
        ..toggle('Security');
      await notifier.save();

      expect(local._saved, containsAll(['AI', 'Security']));
      expect(local._done, isTrue);
    });

    test('save fires remote sync', () async {
      notifier.toggle('AI');
      await notifier.save();

      // Let the unawaited future execute.
      await Future<void>.delayed(Duration.zero);
      expect(remote.callCount, 1);
      expect(remote.lastCategories, contains('AI'));
    });

    test('skip clears state and marks onboarding done', () async {
      notifier.toggle('AI');
      await notifier.skip();

      expect(notifier.state, isEmpty);
      expect(local._saved, isEmpty);
      expect(local._done, isTrue);
    });

    test('skip does NOT call remote sync', () async {
      notifier.toggle('AI');
      await notifier.skip();
      await Future<void>.delayed(Duration.zero);
      expect(remote.callCount, 0);
    });

    group('non-selected categories', () {
      test('non-selected category remains toggleable after save', () async {
        notifier.toggle('AI');
        await notifier.save();

        // 'Security' was never selected — should still be toggleable.
        notifier.toggle('Security');
        expect(notifier.state, contains('Security'));
      });
    });
  });
}
