import 'package:blips_mobile/core/theme/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Bottom navigation bar icon with selected/unselected states.
class NavBarIcon extends StatelessWidget {
  const NavBarIcon({
    super.key,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).bottomNavigationBarTheme;
    final isAndroidUi =
        !kIsWeb && Theme.of(context).platform == TargetPlatform.android;
    final iconSize = isAndroidUi ? AppSizes.iconMd : AppSizes.iconLg;
    final verticalPadding = isAndroidUi ? 10.0 : AppSpacing.sm;
    final horizontalPadding = isAndroidUi ? AppSpacing.md : AppSpacing.lg;

    // Clamp text scaling for nav icons to prevent layout overflow
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.2,
      child: Semantics(
        key: ValueKey('nav-$label'),
        button: true,
        label: label,
        selected: isSelected,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            child: Icon(
              isSelected ? selectedIcon : icon,
              size: iconSize,
              color: isSelected
                  ? theme.selectedItemColor
                  : theme.unselectedItemColor,
            ),
          ),
        ),
      ),
    );
  }
}
