/// Data models for the share feature.
///
/// These models define the structure of shareable content and results.
library;

/// Result of a share operation.
///
/// Named BlipsShareResult to avoid collision with share_plus.ShareResult.
sealed class BlipsShareResult {
  const BlipsShareResult();
}

/// Share completed successfully.
class BlipsShareSuccess extends BlipsShareResult {
  const BlipsShareSuccess();
}

/// Share was cancelled by the user.
class BlipsShareCancelled extends BlipsShareResult {
  const BlipsShareCancelled();
}

/// Share failed with an error.
class BlipsShareError extends BlipsShareResult {
  const BlipsShareError(this.message);

  /// Error description.
  final String message;
}

/// Data required to render and share an article.
class ArticleShareData {
  const ArticleShareData({
    required this.title,
    required this.summary,
    required this.sourceUrl,
    required this.imageUrl,
    required this.sourceName,
  });

  /// Article title (max 2 lines on card).
  final String title;

  /// Article summary (max ~6 lines on card).
  final String summary;

  /// Source URL to share as text.
  final String sourceUrl;

  /// Hero image URL for the card.
  final String imageUrl;

  /// Source publication name (e.g., "TechCrunch").
  final String sourceName;
}

/// Data required to render and share a video.
class VideoShareData {
  const VideoShareData({
    required this.title,
    required this.summary,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.channelName,
  });

  /// Video title.
  final String title;

  /// Video summary snippet.
  final String summary;

  /// Video URL to share as text.
  final String videoUrl;

  /// Thumbnail image URL for the card.
  final String thumbnailUrl;

  /// Channel/publisher name.
  final String channelName;
}

/// Data required to share a reel (URL only).
class ReelShareData {
  const ReelShareData({
    required this.title,
    required this.videoUrl,
  });

  /// Reel title for share subject.
  final String title;

  /// Video URL to share.
  final String videoUrl;
}
