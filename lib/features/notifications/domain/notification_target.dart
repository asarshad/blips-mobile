import 'dart:convert';

/// Feed surfaces supported by push notifications.
enum NotificationSurface {
  articles,
  videos;

  static NotificationSurface? tryParse(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'articles' => NotificationSurface.articles,
      'videos' => NotificationSurface.videos,
      _ => null,
    };
  }

  int get tabIndex => switch (this) {
        NotificationSurface.articles => 0,
        NotificationSurface.videos => 1,
      };
}

/// Parsed target from an incoming push notification.
class NotificationTarget {
  const NotificationTarget({
    required this.surface,
    required this.contentId,
    this.payloadVersion = 1,
  });

  factory NotificationTarget.fromJson(Map<String, dynamic> json) {
    final surface = NotificationSurface.tryParse(json['surface']?.toString());
    final contentId = int.tryParse(json['contentId']?.toString() ?? '');
    final payloadVersion = int.tryParse(
          json['payloadVersion']?.toString() ??
              json['payload_version']?.toString() ??
              '1',
        ) ??
        1;
    if (surface == null || contentId == null || contentId <= 0) {
      throw const FormatException('Invalid notification target');
    }
    return NotificationTarget(
      surface: surface,
      contentId: contentId,
      payloadVersion: payloadVersion,
    );
  }

  factory NotificationTarget.fromEncodedPayload(String payload) {
    return NotificationTarget.fromJson(
      jsonDecode(payload) as Map<String, dynamic>,
    );
  }

  static NotificationTarget? tryFromMessageData(Map<String, dynamic> data) {
    try {
      return NotificationTarget.fromJson(data);
    } on FormatException {
      return null;
    }
  }

  static NotificationTarget? tryFromPayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) return null;
    try {
      return NotificationTarget.fromEncodedPayload(payload);
    } on FormatException {
      return null;
    }
  }

  final NotificationSurface surface;
  final int contentId;
  final int payloadVersion;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'surface': surface.name,
        'contentId': contentId,
        'payloadVersion': payloadVersion,
      };

  String toEncodedPayload() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) {
    return other is NotificationTarget &&
        other.surface == surface &&
        other.contentId == contentId &&
        other.payloadVersion == payloadVersion;
  }

  @override
  int get hashCode => Object.hash(surface, contentId, payloadVersion);
}
