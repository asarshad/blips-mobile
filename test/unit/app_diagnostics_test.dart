@Tags(['unit'])
library app_diagnostics_test;

import 'package:blips_mobile/core/diagnostics/app_diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppDiagnosticsController records and exports recent events', () {
    final controller = AppDiagnosticsController(
      const AppDiagnosticsConfig(
        enabled: true,
        maxEntries: 3,
        mirrorToConsole: false,
      ),
    );

    controller.record(
      scope: 'feed.notifier',
      action: 'manualRefresh',
      stage: 'start',
      surface: 'articles',
      data: const <String, Object?>{'page': 1},
    );
    controller.record(
      scope: 'feed.notifier',
      action: 'manualRefresh',
      stage: 'success',
      surface: 'articles',
      data: const <String, Object?>{'resultCount': 15},
    );

    expect(controller.count, 2);
    expect(controller.latest?.stage, 'success');

    final exported = controller.exportText(limit: 10);
    expect(exported, contains('feed.notifier.manualRefresh.success'));
    expect(exported, contains('resultCount=15'));
  });

  test('AppDiagnosticsController enforces buffer size', () {
    final controller = AppDiagnosticsController(
      const AppDiagnosticsConfig(
        enabled: true,
        maxEntries: 2,
        mirrorToConsole: false,
      ),
    );

    controller.record(scope: 'a', action: 'b', stage: '1');
    controller.record(scope: 'a', action: 'b', stage: '2');
    controller.record(scope: 'a', action: 'b', stage: '3');

    expect(controller.count, 2);
    final exported = controller.exportText(limit: 10);
    expect(exported, contains('a.b.3'));
    expect(exported, isNot(contains('a.b.1')));
  });
}
