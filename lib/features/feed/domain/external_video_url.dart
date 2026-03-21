Uri? resolvePreferredExternalVideoUri({
  required String sourceUrl,
  required String videoUrl,
  bool preferShorts = false,
}) {
  final normalizedSourceUrl = sourceUrl.trim();
  final normalizedVideoUrl = videoUrl.trim();

  final youtubeTarget = _extractYouTubeTarget(normalizedVideoUrl) ??
      _extractYouTubeTarget(normalizedSourceUrl);
  if (youtubeTarget != null) {
    final useShorts =
        preferShorts || youtubeTarget.surface == _YouTubeSurface.shorts;
    return Uri.parse(
      useShorts
          ? 'https://www.youtube.com/shorts/${youtubeTarget.videoId}'
          : 'https://www.youtube.com/watch?v=${youtubeTarget.videoId}',
    );
  }

  return _parseHttpUri(normalizedSourceUrl) ??
      _parseHttpUri(normalizedVideoUrl);
}

Uri? _parseHttpUri(String url) {
  if (url.isEmpty) return null;
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  return uri;
}

_YouTubeTarget? _extractYouTubeTarget(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;

  if (_isYouTubeHost(uri.host)) {
    final shortsIndex = uri.pathSegments.indexOf('shorts');
    if (shortsIndex >= 0 && uri.pathSegments.length > shortsIndex + 1) {
      final videoId = uri.pathSegments[shortsIndex + 1];
      if (videoId.isNotEmpty) {
        return _YouTubeTarget(
          videoId: videoId,
          surface: _YouTubeSurface.shorts,
        );
      }
    }

    final videoId = uri.queryParameters['v'];
    if (videoId != null && videoId.isNotEmpty) {
      return _YouTubeTarget(
        videoId: videoId,
        surface: _YouTubeSurface.watch,
      );
    }
  }

  if (uri.host.contains('youtu.be')) {
    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty);
    if (segments.isNotEmpty) {
      return _YouTubeTarget(
        videoId: segments.first,
        surface: _YouTubeSurface.watch,
      );
    }
  }

  return null;
}

bool _isYouTubeHost(String host) =>
    host.contains('youtube.com') || host.contains('youtube-nocookie.com');

enum _YouTubeSurface { watch, shorts }

final class _YouTubeTarget {
  const _YouTubeTarget({
    required this.videoId,
    required this.surface,
  });

  final String videoId;
  final _YouTubeSurface surface;
}
