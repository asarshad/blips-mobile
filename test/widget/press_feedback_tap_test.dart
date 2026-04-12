@Tags(['widget'])
library press_feedback_tap_test;

import 'package:blips_mobile/features/feed/presentation/reels/reel_action_button.dart';
import 'package:blips_mobile/features/feed/presentation/widgets/press_feedback_tap.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<MethodCall> platformCalls;

  setUp(() {
    platformCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      platformCalls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  int selectionClickCount() => platformCalls
      .where(
        (call) =>
            call.method == 'HapticFeedback.vibrate' &&
            call.arguments == 'HapticFeedbackType.selectionClick',
      )
      .length;

  testWidgets('ink-based press targets scale while pressed and fire haptics',
      (tester) async {
    var tapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PressFeedbackTap(
              onTap: () => tapCount += 1,
              builder: (context, pressState) => AnimatedScale(
                scale: pressState.scale,
                duration: pressState.duration,
                curve: pressState.curve,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: pressState.onTap,
                    onHighlightChanged: pressState.onHighlightChanged,
                    child: const SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(Icons.share_outlined),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester
        .startGesture(tester.getCenter(find.byIcon(Icons.share_outlined)));
    await tester.pump();

    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      lessThan(1),
    );

    await gesture.up();
    await tester.pump();

    expect(tapCount, 1);
    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      equals(1),
    );
    expect(selectionClickCount(), 1);
  });

  testWidgets('reel action buttons scale while pressed and fire haptics',
      (tester) async {
    var tapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ReelActionButton(
              icon: Icons.share,
              label: 'Share',
              onTap: () => tapCount += 1,
            ),
          ),
        ),
      ),
    );

    final gesture =
        await tester.startGesture(tester.getCenter(find.byIcon(Icons.share)));
    await tester.pump();

    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      lessThan(1),
    );

    await gesture.up();
    await tester.pump();

    expect(tapCount, 1);
    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      equals(1),
    );
    expect(selectionClickCount(), 1);
  });
}
