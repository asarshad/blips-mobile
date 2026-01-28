/// Debug overlay for development builds showing device metrics.
///
/// Displays:
/// - Screen size
/// - Device pixel ratio
/// - Text scale factor
/// - Safe area insets (viewPadding and padding)
library;

import 'package:blips_mobile/core/theme/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A debug overlay that shows device metrics when in debug mode.
///
/// Usage:
/// ```dart
/// Stack(
///   children: [
///     // Your main content
///     if (kDebugMode) const DeviceDebugOverlay(),
///   ],
/// )
/// ```
class DeviceDebugOverlay extends StatefulWidget {
  const DeviceDebugOverlay({super.key});

  @override
  State<DeviceDebugOverlay> createState() => _DeviceDebugOverlayState();
}

class _DeviceDebugOverlayState extends State<DeviceDebugOverlay> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    // Only show in debug mode
    if (!kDebugMode) return const SizedBox.shrink();

    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final viewPadding = mediaQuery.viewPadding;
    final padding = mediaQuery.padding;
    final viewInsets = mediaQuery.viewInsets;
    final devicePixelRatio = mediaQuery.devicePixelRatio;
    final textScaler = mediaQuery.textScaler;
    final orientation = mediaQuery.orientation;
    final platformBrightness = mediaQuery.platformBrightness;

    // Get text scale factor using the new textScaler API
    final textScaleFactor = textScaler.scale(1.0);

    return Positioned(
      top: viewPadding.top + AppSpacing.sm,
      right: AppSpacing.sm,
      child: GestureDetector(
        onTap: () => setState(() => _isExpanded = !_isExpanded),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: AppSpacing.allSm,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.85),
            borderRadius: AppRadius.borderMd,
            border: Border.all(color: Colors.cyan, width: 1),
          ),
          child: _isExpanded
              ? _buildExpandedContent(
                  size: size,
                  viewPadding: viewPadding,
                  padding: padding,
                  viewInsets: viewInsets,
                  devicePixelRatio: devicePixelRatio,
                  textScaleFactor: textScaleFactor,
                  orientation: orientation,
                  platformBrightness: platformBrightness,
                )
              : _buildCollapsedContent(),
        ),
      ),
    );
  }

  Widget _buildCollapsedContent() {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.bug_report, color: Colors.cyan, size: 16),
        SizedBox(width: 4),
        Text(
          'DEBUG',
          style: TextStyle(
            color: Colors.cyan,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedContent({
    required Size size,
    required EdgeInsets viewPadding,
    required EdgeInsets padding,
    required EdgeInsets viewInsets,
    required double devicePixelRatio,
    required double textScaleFactor,
    required Orientation orientation,
    required Brightness platformBrightness,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(),
        const SizedBox(height: AppSpacing.sm),
        _MetricRow(
            label: 'Screen',
            value: '${size.width.toInt()}×${size.height.toInt()}'),
        _MetricRow(label: 'DPR', value: devicePixelRatio.toStringAsFixed(2)),
        _MetricRow(
          label: 'Text Scale',
          value: textScaleFactor.toStringAsFixed(2),
          warning: textScaleFactor > 1.3,
        ),
        _MetricRow(label: 'Orientation', value: orientation.name),
        _MetricRow(label: 'Brightness', value: platformBrightness.name),
        const Divider(color: Colors.grey, height: 12),
        const Text(
          'viewPadding (system nav):',
          style: TextStyle(color: Colors.grey, fontSize: 9),
        ),
        _MetricRow(
          label: '  TLBR',
          value: '${viewPadding.top.toInt()} ${viewPadding.left.toInt()} '
              '${viewPadding.bottom.toInt()} ${viewPadding.right.toInt()}',
        ),
        const Text(
          'padding (safe area):',
          style: TextStyle(color: Colors.grey, fontSize: 9),
        ),
        _MetricRow(
          label: '  TLBR',
          value: '${padding.top.toInt()} ${padding.left.toInt()} '
              '${padding.bottom.toInt()} ${padding.right.toInt()}',
        ),
        const Text(
          'viewInsets (keyboard):',
          style: TextStyle(color: Colors.grey, fontSize: 9),
        ),
        _MetricRow(
          label: '  bottom',
          value: '${viewInsets.bottom.toInt()}',
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.bug_report, color: Colors.cyan, size: 14),
        const SizedBox(width: 4),
        const Text(
          'Device Metrics',
          style: TextStyle(
            color: Colors.cyan,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => setState(() => _isExpanded = false),
          child: const Icon(Icons.close, color: Colors.grey, size: 14),
        ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    this.warning = false,
  });

  final String label;
  final String value;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 10,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: warning ? Colors.orange : Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (warning)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.warning, color: Colors.orange, size: 10),
            ),
        ],
      ),
    );
  }
}
