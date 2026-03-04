/// Category definitions for the interest selection screen.
///
/// These string keys MUST match the topic classifier strings used
/// by the backend (app/ranking/interest.py). Do not change them
/// without a corresponding backend update.
library;

/// A single selectable category shown on the interest selection screen.
final class AppCategory {
  const AppCategory({
    required this.id,
    required this.label,
    required this.emoji,
  });

  /// Backend topic string (e.g. "AI"). Sent to the preferences API.
  final String id;

  /// Human-readable label shown to the user.
  final String label;

  /// Decorative emoji prefix for the chip.
  final String emoji;
}

/// All categories available for selection, ordered by expected popularity.
const List<AppCategory> kAllCategories = [
  AppCategory(id: 'AI', label: 'Artificial Intelligence', emoji: '🤖'),
  AppCategory(id: 'Security', label: 'Cybersecurity', emoji: '🔒'),
  AppCategory(id: 'Cloud', label: 'Cloud & Infrastructure', emoji: '☁️'),
  AppCategory(id: 'Open Source', label: 'Open Source', emoji: '🌐'),
  AppCategory(id: 'Dev Tools', label: 'Dev Tools', emoji: '🛠️'),
  AppCategory(id: 'Mobile', label: 'Mobile', emoji: '📱'),
  AppCategory(id: 'Web', label: 'Web', emoji: '🌍'),
  AppCategory(id: 'Data', label: 'Data & Analytics', emoji: '📊'),
  AppCategory(id: 'Startups', label: 'Startups', emoji: '🚀'),
  AppCategory(id: 'Hardware', label: 'Hardware', emoji: '💾'),
];
