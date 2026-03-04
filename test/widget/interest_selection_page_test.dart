@Tags(['widget', 'onboarding'])
library interest_selection_page_test;

import 'package:blips_mobile/features/onboarding/data/interests_local_service.dart';
import 'package:blips_mobile/features/onboarding/data/interests_remote_service.dart';
import 'package:blips_mobile/features/onboarding/domain/categories.dart';
import 'package:blips_mobile/features/onboarding/presentation/interest_selection_page.dart';
import 'package:blips_mobile/features/onboarding/providers/interests_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

// ── Fakes (same pattern as unit test) ─────────────────────────────────────

class _FakeLocalService extends InterestsLocalService {
  bool _done = false;
  final List<String> _saved = [];

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

class _FakeRemoteService extends InterestsRemoteService {
  _FakeRemoteService() : super(Dio());
  @override
  Future<void> syncCategories({
    required String deviceId,
    required List<String> selectedCategories,
  }) async {}
}

// ── Test helpers ──────────────────────────────────────────────────────────

/// Builds a [ProviderScope]-wrapped test app with overridden providers
/// so that [InterestSelectionPage] never touches SharedPreferences or Dio.
Widget _buildTestApp({_FakeLocalService? local, _FakeRemoteService? remote}) {
  final fakeLocal = local ?? _FakeLocalService();
  final fakeRemote = remote ?? _FakeRemoteService();

  // Override the notifier directly so it never tries to resolve
  // deviceIdProvider (which requires SharedPreferences in the test env).
  final notifierOverride = interestsNotifierProvider.overrideWith(
    (ref) => InterestsNotifier(fakeLocal, fakeRemote, Future.value('test-id')),
  );

  final router = GoRouter(
    initialLocation: InterestSelectionPage.path,
    routes: [
      GoRoute(
        path: InterestSelectionPage.path,
        builder: (_, __) => const InterestSelectionPage(),
      ),
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: Text('Feed')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      interestsLocalServiceProvider.overrideWithValue(fakeLocal),
      interestsRemoteServiceProvider.overrideWithValue(fakeRemote),
      notifierOverride,
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  group('InterestSelectionPage', () {
    testWidgets('renders all category labels', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      for (final cat in kAllCategories) {
        expect(find.text(cat.label), findsOneWidget);
      }
    });

    testWidgets('tapping a chip shows it as selected', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Tap the first category chip
      final firstLabel = kAllCategories.first.label;
      await tester.tap(find.text(firstLabel));
      await tester.pumpAndSettle();

      // The check icon should appear (only visible when selected)
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('Get started button disabled with no selection',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final ctaButton =
          find.widgetWithText(FilledButton, 'Select at least one topic');
      expect(ctaButton, findsOneWidget);

      // Verify the button is disabled (onPressed is null)
      final button = tester.widget<FilledButton>(ctaButton);
      expect(button.onPressed, isNull);
    });

    testWidgets('Get started button enabled after selection', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text(kAllCategories.first.label));
      await tester.pumpAndSettle();

      final ctaButton = find.widgetWithText(FilledButton, 'Get started');
      expect(ctaButton, findsOneWidget);

      final button = tester.widget<FilledButton>(ctaButton);
      expect(button.onPressed, isNotNull);
    });

    testWidgets('selection counter shows correct count', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text(kAllCategories[0].label));
      await tester.tap(find.text(kAllCategories[1].label));
      await tester.pumpAndSettle();

      expect(
          find.text('2 of $kMaxSelectedCategories selected'), findsOneWidget);
    });

    testWidgets('cannot select more than $kMaxSelectedCategories chips',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Select 3
      for (var i = 0; i < kMaxSelectedCategories; i++) {
        await tester.tap(find.text(kAllCategories[i].label));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      // Try to select a 4th
      final fourthLabel = kAllCategories[kMaxSelectedCategories].label;
      await tester.tap(find.text(fourthLabel));
      await tester.pumpAndSettle();

      // Counter should still read max
      expect(
        find.text(
            '$kMaxSelectedCategories of $kMaxSelectedCategories selected'),
        findsOneWidget,
      );
      // 4th chip should not have check icon (only 3 checks total)
      expect(find.byIcon(Icons.check_circle_rounded),
          findsNWidgets(kMaxSelectedCategories));
    });

    testWidgets('Skip navigates to feed', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.text('Feed'), findsOneWidget);
    });

    testWidgets('Get started navigates to feed after selection',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text(kAllCategories.first.label));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Get started'));
      await tester.pumpAndSettle();

      expect(find.text('Feed'), findsOneWidget);
    });
  });
}
