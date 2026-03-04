/// Tappable category chip for the interest selection screen.
library;

import 'package:blips_mobile/core/theme/app_theme.dart';
import 'package:blips_mobile/features/onboarding/domain/categories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// A selectable chip representing a single [AppCategory].
///
/// Appearance:
/// - Unselected: card background, subtle border, primary-text label.
/// - Selected:   primary-color fill, high-contrast label, checkmark.
/// - At-capacity: opacity reduced when this chip is not selected and the
///   max selection count has been reached.
///
/// Tapping while at capacity triggers a brief horizontal shake to signal
/// the constraint without a modal dialog.
class CategoryChip extends StatelessWidget {
  /// Creates a [CategoryChip].
  const CategoryChip({
    required this.category,
    required this.isSelected,
    required this.isAtCapacity,
    required this.onTap,
    super.key,
  });

  /// The category this chip represents.
  final AppCategory category;

  /// Whether this category is currently selected by the user.
  final bool isSelected;

  /// True when the user has reached the selection limit and this chip
  /// is NOT currently selected — adding it would overflow.
  final bool isAtCapacity;

  /// Called when the chip is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isSelected
        ? colorScheme.primary
        : (isDark ? AppColors.darkCard : AppColors.lightCard);

    final borderColor = isSelected
        ? colorScheme.primary
        : colorScheme.outline.withValues(alpha: 0.6);

    final labelColor =
        isSelected ? colorScheme.onPrimary : colorScheme.onSurface;

    final chipOpacity = isAtCapacity ? 0.4 : 1.0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: chipOpacity,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                category.emoji,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(width: 8),
              Text(
                category.label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: labelColor,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: colorScheme.onPrimary,
                ),
              ],
            ],
          ),
        ),
      ),
    ).animate(
        // Shake animation when tapping at capacity — triggered externally via
        // a key change. We keep the animation definition here for co-location.
        );
  }
}

/// A version of [CategoryChip] that shakes when tapped at capacity.
///
/// Use this in the list; it manages its own shake animation state.
class ShakeableCategoryChip extends StatefulWidget {
  /// Creates a [ShakeableCategoryChip].
  const ShakeableCategoryChip({
    required this.category,
    required this.isSelected,
    required this.isAtCapacity,
    required this.onTap,
    super.key,
  });

  /// The category this chip represents.
  final AppCategory category;

  /// Whether this category is currently selected by the user.
  final bool isSelected;

  /// True when the user has reached the selection limit and this chip is not selected.
  final bool isAtCapacity;

  /// Called when the chip is tapped.
  final VoidCallback onTap;

  @override
  State<ShakeableCategoryChip> createState() => _ShakeableCategoryChipState();
}

class _ShakeableCategoryChipState extends State<ShakeableCategoryChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -6), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -6, end: 6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6, end: -4), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -4, end: 4), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 4, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.linear));
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.isAtCapacity) {
      _shakeController
        ..reset()
        ..forward();
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) => Transform.translate(
        offset: Offset(_shakeAnimation.value, 0),
        child: child,
      ),
      child: CategoryChip(
        category: widget.category,
        isSelected: widget.isSelected,
        isAtCapacity: widget.isAtCapacity,
        onTap: _handleTap,
      ),
    );
  }
}
