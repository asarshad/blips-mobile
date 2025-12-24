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
    
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(
          isSelected ? selectedIcon : icon,
          size: 26,
          color: isSelected
              ? theme.selectedItemColor
              : theme.unselectedItemColor,
        ),
      ),
    );
  }
}
