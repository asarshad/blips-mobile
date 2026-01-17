import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Resolves YouTube URLs to direct stream URLs.
/// 
/// Handles various YouTube URL formats and caches resolved URLs.
class YoutubeUrlResolver {
  YoutubeUrlResolver() : _youtubeExplode = YoutubeExplode();

  final YoutubeExplode _youtubeExplode;
  static const Duration _cacheTtl = Duration(minutes: 10);

  // Cache by videoId to avoid duplicate work across URL variants (watch/shorts/youtu.be).
  final Map<String, ({String url, DateTime cachedAt})> _cacheById = {};

  // De-dupe concurrent resolves for the same videoId.
  final Map<String, Future<String>> _inFlightById = {};
  bool _isDisposed = false;

  /// Resolves a YouTube URL to a direct stream URL.
  /// 
  /// Returns cached result if available.
  /// Throws if URL is invalid or resolution fails.
  Future<String> resolve(String url) async {
    if (_isDisposed) {
      throw StateError('YoutubeUrlResolver has been disposed');
    }

    final videoId = extractVideoId(url);
    if (videoId == null) {
      throw ArgumentError('Invalid YouTube URL: $url');
    }

    // Check cache first (respect TTL)
    final cached = _cacheById[videoId];
    if (cached != null) {
      final age = DateTime.now().difference(cached.cachedAt);
      if (age <= _cacheTtl) {
        return cached.url;
      }
      _cacheById.remove(videoId);
    }

    // If already resolving this videoId, await the same Future.
    final inFlight = _inFlightById[videoId];
    if (inFlight != null) {
      return inFlight;
    }

    final future = _resolveUncached(videoId);
    _inFlightById[videoId] = future;
    try {
      final streamUrl = await future;
      _cacheById[videoId] = (url: streamUrl, cachedAt: DateTime.now());
      return streamUrl;
    } finally {
      _inFlightById.remove(videoId);
    }
  }

  Future<String> _resolveUncached(String videoId) async {

    try {
      debugPrint('YoutubeResolver: Fetching manifest for videoId=$videoId');
      final manifest =
          await _youtubeExplode.videos.streamsClient.getManifest(videoId);

      // Prefer muxed streams for faster loading (video + audio combined)
      // Choose medium quality for balance of speed and quality
      final streams = manifest.muxed.toList();
      
      if (streams.isEmpty) {
        debugPrint('YoutubeResolver: No muxed streams for $videoId, trying audio-only');
        // Fallback: some videos only have separate audio/video streams
        final audioStreams = manifest.audioOnly.toList();
        if (audioStreams.isEmpty) {
          throw Exception('No playable streams found for video $videoId');
        }
        // For now, we need muxed streams - audio-only won't work for video display
        throw Exception('Video $videoId has no muxed streams (may be restricted)');
      }
      
      streams.sort((a, b) => b.bitrate.compareTo(a.bitrate));

      // Find a good quality stream (720p or lower for fast loading)
      final stream = streams.firstWhere(
        (s) =>
            s.videoResolution.height <= 720 &&
            s.videoResolution.height >= 360,
        orElse: () => streams.first,
      );

      debugPrint('YoutubeResolver: Found stream ${stream.videoResolution.height}p for $videoId');
      final streamUrl = stream.url.toString();
      return streamUrl;
    } catch (e) {
      debugPrint('YoutubeResolver ERROR for videoId=$videoId: $e');
      rethrow;
    }
  }

  /// Extracts video ID from various YouTube URL formats.
  /// 
  /// Supports:
  /// - youtube.com/shorts/VIDEO_ID
  /// - youtube.com/watch?v=VIDEO_ID
  /// - youtu.be/VIDEO_ID
  String? extractVideoId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    // youtube.com/shorts/VIDEO_ID (check this BEFORE regular youtube.com)
    if (uri.host.contains('youtube.com') &&
        uri.pathSegments.contains('shorts')) {
      final shortsIndex = uri.pathSegments.indexOf('shorts');
      if (uri.pathSegments.length > shortsIndex + 1) {
        return uri.pathSegments[shortsIndex + 1];
      }
    }

    // youtube.com/watch?v=VIDEO_ID
    if (uri.host.contains('youtube.com')) {
      final videoId = uri.queryParameters['v'];
      if (videoId != null && videoId.isNotEmpty) {
        return videoId;
      }
    }

    // youtu.be/VIDEO_ID
    if (uri.host.contains('youtu.be')) {
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        return segments.first;
      }
    }

    return null;
  }

  /// Clears the URL cache.
  void clearCache() {
    _cacheById.clear();
    _inFlightById.clear();
  }

  /// Clears a specific URL from cache.
  void clearUrlFromCache(String url) {
    final videoId = extractVideoId(url);
    if (videoId == null) return;
    _cacheById.remove(videoId);
    _inFlightById.remove(videoId);
  }

  /// Disposes resources.
  void dispose() {
    _isDisposed = true;
    _cacheById.clear();
    _inFlightById.clear();
    _youtubeExplode.close();
  }
}
