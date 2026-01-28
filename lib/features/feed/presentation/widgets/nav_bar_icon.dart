import 'package:blips_mobile/core/theme/theme.dart';
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
    
    // Clamp text scaling for nav icons to prevent layout overflow
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.2,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: AppSpacing.allMd,
          child: Icon(
            isSelected ? selectedIcon : icon,
            size: AppSizes.iconLg,
            color: isSelected
                ? theme.selectedItemColor
                : theme.unselectedItemColor,
          ),
        ),
      ),
    );
  }
}
