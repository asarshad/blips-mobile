/// Golden tests for the bottom navigation bar.
///
/// Tests the bottom nav across different device configurations to ensure:
/// - Proper safe area handling
/// - No overlap with system navigation
/// - Consistent appearance across devices
library;

import 'package:blips_mobile/core/theme/theme.dart';
import 'package:blips_mobile/features/feed/presentation/widgets/nav_bar_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_test_utils.dart';

void main() {
  group('Bottom Navigation Golden Tests', () {
    // Test helper to create a bottom nav in isolation
    Widget buildBottomNav({required EdgeInsets viewPadding}) {
      return Builder(
        builder: (context) {
          return Container(
            color: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
            padding: EdgeInsets.only(bottom: viewPadding.bottom),
            child: SizedBox(
              height: AppSizes.bottomNavHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  NavBarIcon(
                    icon: Icons.article_outlined,
                    selectedIcon: Icons.article,
                    label: 'Feed',
                    isSelected: true,
                    onTap: () {},
                  ),
                  NavBarIcon(
                    icon: Icons.play_circle_outline,
                    selectedIcon: Icons.play_circle,
                    label: 'Videos',
                    isSelected: false,
                    onTap: () {},
                  ),
                  NavBarIcon(
                    icon: Icons.movie_filter_outlined,
                    selectedIcon: Icons.movie_filter,
                    label: 'Reels',
                    isSelected: false,
                    onTap: () {},
                  ),
                  NavBarIcon(
                    icon: Icons.chat_bubble_outline,
                    selectedIcon: Icons.chat_bubble,
                    label: 'Chat',
                    isSelected: false,
                    onTap: () {},
                  ),
                  NavBarIcon(
                    icon: Icons.settings_outlined,
                    selectedIcon: Icons.settings,
                    label: 'Settings',
                    isSelected: false,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    testWidgets('Bottom nav on iPhone with home indicator', (tester) async {
      final device = GoldenDevices.iphoneSafeArea;
      
      await tester.setDeviceConfig(device);
      
      await tester.pumpWidget(
        goldenTestWrapper(
          device: device,
          child: Scaffold(
            body: const Center(child: Text('Content')),
            bottomNavigationBar: buildBottomNav(
              viewPadding: device.viewPadding,
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/bottom_nav_iphone_safe.png'),
      );
    });

    testWidgets('Bottom nav on Android gesture navigation', (tester) async {
      final device = GoldenDevices.androidGesture;
      
      await tester.setDeviceConfig(device);
      
      await tester.pumpWidget(
        goldenTestWrapper(
          device: device,
          child: Scaffold(
            body: const Center(child: Text('Content')),
            bottomNavigationBar: buildBottomNav(
              viewPadding: device.viewPadding,
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/bottom_nav_android_gesture.png'),
      );
    });

    testWidgets('Bottom nav on Android 3-button navigation', (tester) async {
      final device = GoldenDevices.androidButtons;
      
      await tester.setDeviceConfig(device);
      
      await tester.pumpWidget(
        goldenTestWrapper(
          device: device,
          child: Scaffold(
            body: const Center(child: Text('Content')),
            bottomNavigationBar: buildBottomNav(
              viewPadding: device.viewPadding,
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/bottom_nav_android_buttons.png'),
      );
    });

    testWidgets('Bottom nav on small phone', (tester) async {
      final device = GoldenDevices.smallPhone;
      
      await tester.setDeviceConfig(device);
      
      await tester.pumpWidget(
        goldenTestWrapper(
          device: device,
          child: Scaffold(
            body: const Center(child: Text('Content')),
            bottomNavigationBar: buildBottomNav(
              viewPadding: device.viewPadding,
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/bottom_nav_small_phone.png'),
      );
    });

    testWidgets('Bottom nav with large text scaling', (tester) async {
      final device = GoldenDevices.largeText;
      
      await tester.setDeviceConfig(device);
      
      await tester.pumpWidget(
        goldenTestWrapper(
          device: device,
          child: Scaffold(
            body: const Center(child: Text('Content')),
            bottomNavigationBar: buildBottomNav(
              viewPadding: device.viewPadding,
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/bottom_nav_large_text.png'),
      );
    });
  });
}
