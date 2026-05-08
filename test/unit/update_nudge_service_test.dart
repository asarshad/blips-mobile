@Tags(['unit'])
library update_nudge_service_test;

import 'package:blips_mobile/core/services/update_nudge_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('UpdateNudgeService.shouldShowNudge', () {
    test('returns false when minRecommendedVersion is null', () {
      expect(
        UpdateNudgeService.shouldShowNudge(
          currentVersion: '1.0.3',
          minRecommendedVersion: null,
        ),
        isFalse,
      );
    });

    test('returns false when minRecommendedVersion is empty', () {
      expect(
        UpdateNudgeService.shouldShowNudge(
          currentVersion: '1.0.3',
          minRecommendedVersion: '',
        ),
        isFalse,
      );
    });

    test('returns true when current version is below recommended minimum', () {
      expect(
        UpdateNudgeService.shouldShowNudge(
          currentVersion: '1.0.3',
          minRecommendedVersion: '1.0.5',
        ),
        isTrue,
      );
    });

    test('returns false when current version equals recommended minimum', () {
      expect(
        UpdateNudgeService.shouldShowNudge(
          currentVersion: '1.0.5',
          minRecommendedVersion: '1.0.5',
        ),
        isFalse,
      );
    });

    test('returns false when current version is above recommended minimum', () {
      expect(
        UpdateNudgeService.shouldShowNudge(
          currentVersion: '1.0.6',
          minRecommendedVersion: '1.0.5',
        ),
        isFalse,
      );
    });

    test('compares minor version correctly across major boundary', () {
      expect(
        UpdateNudgeService.shouldShowNudge(
          currentVersion: '0.9.9',
          minRecommendedVersion: '1.0.0',
        ),
        isTrue,
      );
    });

    test('ignores build number suffix in both versions', () {
      // 1.0.3+15 is still below 1.0.5, build number does not matter
      expect(
        UpdateNudgeService.shouldShowNudge(
          currentVersion: '1.0.3+15',
          minRecommendedVersion: '1.0.5+2',
        ),
        isTrue,
      );
    });

    test('handles two-part version strings gracefully', () {
      expect(
        UpdateNudgeService.shouldShowNudge(
          currentVersion: '1.0',
          minRecommendedVersion: '1.1',
        ),
        isTrue,
      );
    });

    test('handles major version difference', () {
      expect(
        UpdateNudgeService.shouldShowNudge(
          currentVersion: '1.9.9',
          minRecommendedVersion: '2.0.0',
        ),
        isTrue,
      );
      expect(
        UpdateNudgeService.shouldShowNudge(
          currentVersion: '2.0.0',
          minRecommendedVersion: '1.9.9',
        ),
        isFalse,
      );
    });

    test('strips leading v/V prefix before comparing', () {
      expect(
        UpdateNudgeService.shouldShowNudge(
          currentVersion: 'v1.0.3',
          minRecommendedVersion: 'v1.0.5',
        ),
        isTrue,
      );
      expect(
        UpdateNudgeService.shouldShowNudge(
          currentVersion: 'V1.0.5',
          minRecommendedVersion: 'V1.0.5',
        ),
        isFalse,
      );
    });

    test('strips pre-release label before comparing', () {
      expect(
        UpdateNudgeService.shouldShowNudge(
          currentVersion: '1.0.5-beta',
          minRecommendedVersion: '1.0.5',
        ),
        // 1.0.5-beta semver part is 1.0.5, equal to min — no nudge
        isFalse,
      );
      expect(
        UpdateNudgeService.shouldShowNudge(
          currentVersion: '1.0.4-rc1',
          minRecommendedVersion: '1.0.5',
        ),
        isTrue,
      );
    });
  });

  group('UpdateNudgeService dismiss tracking', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('wasDismissedFor returns false when no entry stored', () async {
      final prefs = await SharedPreferences.getInstance();

      expect(
        await UpdateNudgeService.wasDismissedFor(prefs, '1.0.5'),
        isFalse,
      );
    });

    test('wasDismissedFor returns true after markDismissed for same version',
        () async {
      final prefs = await SharedPreferences.getInstance();

      await UpdateNudgeService.markDismissed(prefs, '1.0.5');

      expect(
        await UpdateNudgeService.wasDismissedFor(prefs, '1.0.5'),
        isTrue,
      );
    });

    test('wasDismissedFor returns false for a different version', () async {
      final prefs = await SharedPreferences.getInstance();
      await UpdateNudgeService.markDismissed(prefs, '1.0.5');

      // A newer nudge for 1.0.6 should not be suppressed by the 1.0.5 dismiss
      expect(
        await UpdateNudgeService.wasDismissedFor(prefs, '1.0.6'),
        isFalse,
      );
    });

    test('markDismissed overwrites a previous dismissal for a different version',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await UpdateNudgeService.markDismissed(prefs, '1.0.5');
      await UpdateNudgeService.markDismissed(prefs, '1.0.6');

      expect(
        await UpdateNudgeService.wasDismissedFor(prefs, '1.0.5'),
        isFalse,
      );
      expect(
        await UpdateNudgeService.wasDismissedFor(prefs, '1.0.6'),
        isTrue,
      );
    });
  });
}
