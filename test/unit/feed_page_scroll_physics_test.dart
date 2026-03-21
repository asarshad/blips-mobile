@Tags(['unit'])
library feed_page_scroll_physics_test;

import 'package:blips_mobile/features/feed/presentation/widgets/feed_page_scroll_physics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

PageMetrics _metrics({required double page}) {
  return PageMetrics(
    minScrollExtent: 0,
    maxScrollExtent: 900,
    pixels: page * 300,
    viewportDimension: 300,
    axisDirection: AxisDirection.down,
    devicePixelRatio: 2,
    viewportFraction: 1,
  );
}

void main() {
  test('snaps forward once 12 percent of the next page is crossed', () {
    const physics = FeedPageScrollPhysics();

    final beforeThreshold = physics.createBallisticSimulation(
      _metrics(page: 2.11),
      0,
    );
    final afterThreshold = physics.createBallisticSimulation(
      _metrics(page: 2.13),
      0,
    );

    expect(beforeThreshold, isNotNull);
    expect(afterThreshold, isNotNull);
    expect(beforeThreshold!.x(10), closeTo(600, 0.5));
    expect(afterThreshold!.x(10), closeTo(900, 0.5));
  });

  test('fling velocity still advances in the fling direction', () {
    const physics = FeedPageScrollPhysics();

    final forward = physics.createBallisticSimulation(_metrics(page: 2.1), 500);
    final backward = physics.createBallisticSimulation(
      _metrics(page: 2.9),
      -500,
    );

    expect(forward, isNotNull);
    expect(backward, isNotNull);
    expect(forward!.x(10), closeTo(900, 0.5));
    expect(backward!.x(10), closeTo(600, 0.5));
  });

  test('carries momentum for repeated same-direction flicks', () {
    const physics = FeedPageScrollPhysics();

    expect(physics.carriedMomentum(1200), greaterThan(0));
    expect(physics.carriedMomentum(-1200), lessThan(0));
    expect(physics.carriedMomentum(100), 0);
  });
}
