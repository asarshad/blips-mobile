import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

const _kFastSnapThreshold = 0.12;
const _kFastPageSpring = SpringDescription(
  mass: 0.45,
  stiffness: 560,
  damping: 32,
);
const _kMomentumCarryFactor = 0.26;
const _kMomentumCarryCap = 3200.0;

/// Page physics tuned for short-flick, one-card-at-a-time feed navigation.
///
/// This intentionally builds on Flutter's standard [PageScrollPhysics] rather
/// than generic scroll physics so it behaves like a page feed first, then adds
/// a lower snap threshold and some carried momentum for repeated flicks.
class FeedPageScrollPhysics extends PageScrollPhysics {
  /// Creates page physics tuned for feed-style card swiping.
  const FeedPageScrollPhysics({super.parent});

  @override
  FeedPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return FeedPageScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => _kFastPageSpring;

  @override
  double? get dragStartDistanceMotionThreshold => 0.5;

  @override
  double get minFlingDistance => 1.0;

  @override
  double get minFlingVelocity => kMinFlingVelocity * 0.35;

  @override
  double carriedMomentum(double existingVelocity) {
    final magnitude = existingVelocity.abs();
    if (magnitude < 120) {
      return 0;
    }
    return existingVelocity.sign *
        math.min(magnitude * _kMomentumCarryFactor, _kMomentumCarryCap);
  }

  double _getPage(ScrollMetrics position) {
    if (position is PageMetrics) {
      return position.page ?? 0;
    }
    return position.pixels / position.viewportDimension;
  }

  double _getPixels(ScrollMetrics position, double page) {
    if (position is PageMetrics) {
      return page * position.viewportDimension * position.viewportFraction;
    }
    return page * position.viewportDimension;
  }

  double _getTargetPage(
    ScrollMetrics position,
    Tolerance tolerance,
    double velocity,
  ) {
    final page = _getPage(position);
    final wholePage = page.floorToDouble();
    final progress = page - wholePage;

    if (velocity <= -tolerance.velocity) {
      return wholePage;
    }
    if (velocity >= tolerance.velocity) {
      return wholePage + 1;
    }

    return progress >= _kFastSnapThreshold ? wholePage + 1 : wholePage;
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final outOfRange =
        (velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
            (velocity >= 0.0 && position.pixels >= position.maxScrollExtent);
    if (outOfRange) {
      return super.createBallisticSimulation(position, velocity);
    }

    final tolerance = toleranceFor(position);
    final target = _getPixels(
      position,
      _getTargetPage(position, tolerance, velocity),
    );
    if (target == position.pixels) {
      return null;
    }

    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: tolerance,
    );
  }

  @override
  bool get allowImplicitScrolling => false;
}

ScrollPhysics buildFeedPagePhysics(BuildContext context) {
  final basePhysics = ScrollConfiguration.of(context).getScrollPhysics(context);
  return FeedPageScrollPhysics(
    parent: const AlwaysScrollableScrollPhysics().applyTo(basePhysics),
  );
}
