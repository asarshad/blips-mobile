/// Bottom sheet for reporting content to the moderation queue.
///
/// Call [ContentReportSheet.show] from any surface (articles, videos,
/// reels, or chat). The sheet presents a list of reason options; on
/// selection it calls [onReport] with the chosen reason key and
/// dismisses itself.
library;

import 'package:flutter/material.dart';

/// Reason options shown in the report sheet.
class _ReportReason {
  const _ReportReason({
    required this.key,
    required this.label,
    required this.icon,
  });

  final String key;
  final String label;
  final IconData icon;
}

const _reasons = [
  _ReportReason(
    key: 'hateful',
    label: 'Hateful or discriminatory',
    icon: Icons.block_outlined,
  ),
  _ReportReason(
    key: 'violence',
    label: 'Promotes violence or self-harm',
    icon: Icons.warning_amber_outlined,
  ),
  _ReportReason(
    key: 'explicit',
    label: 'Sexually explicit content',
    icon: Icons.no_adult_content_outlined,
  ),
  _ReportReason(
    key: 'spam',
    label: 'Spam or misleading',
    icon: Icons.report_gmailerrorred_outlined,
  ),
  _ReportReason(
    key: 'misinformation',
    label: 'Dangerous misinformation',
    icon: Icons.fact_check_outlined,
  ),
  _ReportReason(
    key: 'other',
    label: 'Other',
    icon: Icons.more_horiz,
  ),
];

class ContentReportSheet extends StatelessWidget {
  const ContentReportSheet({
    required this.onReport,
    super.key,
  });

  /// Called with the chosen reason key when the user selects a reason.
  /// The sheet is already dismissed at this point.
  final void Function(String reason) onReport;

  /// Convenience method: shows the sheet and awaits the user's choice.
  ///
  /// Returns the reason key the user chose, or `null` if they dismissed.
  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => ContentReportSheet(
        onReport: (reason) => Navigator.of(sheetContext).pop(reason),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Report content',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'What\'s wrong with this content?',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          const Divider(height: 1),
          ..._reasons.map(
            (r) => ListTile(
              leading: Icon(r.icon, color: colorScheme.onSurfaceVariant),
              title: Text(r.label),
              onTap: () => onReport(r.key),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
