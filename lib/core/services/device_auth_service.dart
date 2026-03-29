import 'dart:async';
import 'dart:convert';

import 'package:blips_mobile/core/error/error.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';

const _kDeviceAuthBundleKey = 'blips_device_auth_bundle';

class DeviceAuthBundle {
  const DeviceAuthBundle({
    required this.deviceId,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.platform,
  });

  factory DeviceAuthBundle.fromJson(Map<String, dynamic> json) {
    return DeviceAuthBundle(
      deviceId: json['device_id'] as String,
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String).toUtc(),
      platform: json['platform'] as String,
    );
  }

  final String deviceId;
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String platform;

  bool get isExpiringSoon => DateTime.now()
      .toUtc()
      .isAfter(expiresAt.subtract(const Duration(seconds: 30)));

  Map<String, dynamic> toJson() => <String, dynamic>{
        'device_id': deviceId,
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'expires_at': expiresAt.toUtc().toIso8601String(),
        'platform': platform,
      };
}

abstract class DeviceAuthStorage {
  const DeviceAuthStorage();

  Future<DeviceAuthBundle?> read();
  Future<void> write(DeviceAuthBundle bundle);
  Future<void> delete();
}

class SecureDeviceAuthStorage extends DeviceAuthStorage {
  const SecureDeviceAuthStorage([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  @override
  Future<DeviceAuthBundle?> read() async {
    final raw = await _storage.read(key: _kDeviceAuthBundleKey);
    if (raw == null || raw.isEmpty) return null;
    return DeviceAuthBundle.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  @override
  Future<void> write(DeviceAuthBundle bundle) async {
    await _storage.write(
      key: _kDeviceAuthBundleKey,
      value: jsonEncode(bundle.toJson()),
    );
  }

  @override
  Future<void> delete() => _storage.delete(key: _kDeviceAuthBundleKey);
}

const defaultDeviceAuthStorage = SecureDeviceAuthStorage();

class DeviceAuthService {
  DeviceAuthService(
    this._dio, {
    DeviceAuthStorage storage = defaultDeviceAuthStorage,
  }) : _storage = storage;

  final Dio _dio;
  final DeviceAuthStorage _storage;

  Future<DeviceAuthBundle>? _bootstrapFuture;
  Future<DeviceAuthBundle>? _refreshFuture;

  Future<DeviceAuthBundle?> readBundle() => _storage.read();

  Future<DeviceAuthBundle> ensureAuthenticated() async {
    final existing = await _storage.read();
    if (existing != null && !existing.isExpiringSoon) {
      return existing;
    }
    if (existing != null) {
      return refresh();
    }
    return bootstrap();
  }

  Future<DeviceAuthBundle> bootstrap() {
    final inFlight = _bootstrapFuture;
    if (inFlight != null) return inFlight;

    final future = _bootstrap();
    _bootstrapFuture = future;
    future.whenComplete(() {
      if (identical(_bootstrapFuture, future)) {
        _bootstrapFuture = null;
      }
    });
    return future;
  }

  Future<DeviceAuthBundle> refresh() {
    final inFlight = _refreshFuture;
    if (inFlight != null) return inFlight;

    final future = _refresh();
    _refreshFuture = future;
    future.whenComplete(() {
      if (identical(_refreshFuture, future)) {
        _refreshFuture = null;
      }
    });
    return future;
  }

  Future<void> revoke() async {
    final bundle = await _storage.read();
    if (bundle == null) return;

    try {
      await _dio.post<void>(
        '/auth/session/revoke',
        data: <String, dynamic>{'refresh_token': bundle.refreshToken},
        options: Options(
          headers: <String, dynamic>{
            'Authorization': 'Bearer ${bundle.accessToken}',
          },
          extra: const <String, dynamic>{'skipAuth': true},
        ),
      );
    } finally {
      await _storage.delete();
    }
  }

  Future<void> resetLocalState() => _storage.delete();

  Future<DeviceAuthBundle> _bootstrap() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/session',
      data: <String, dynamic>{
        'platform': _platformLabel(),
        'app_version': _appVersion(packageInfo),
      },
      options: Options(extra: const <String, dynamic>{'skipAuth': true}),
    );
    final bundle = _bundleFromResponse(
      response.data,
      fallbackPlatform: _platformLabel(),
    );
    await _storage.write(bundle);
    return bundle;
  }

  Future<DeviceAuthBundle> _refresh() async {
    final existing = await _storage.read();
    if (existing == null) {
      return bootstrap();
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/session/refresh',
        data: <String, dynamic>{'refresh_token': existing.refreshToken},
        options: Options(extra: const <String, dynamic>{'skipAuth': true}),
      );
      final bundle = _bundleFromResponse(
        response.data,
        fallbackPlatform: existing.platform,
      );
      await _storage.write(bundle);
      return bundle;
    } on DioException catch (error, stackTrace) {
      await _storage.delete();
      logger.warning(
        'Session refresh failed; local auth state cleared',
        category: LogCategory.network,
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  DeviceAuthBundle _bundleFromResponse(
    Map<String, dynamic>? json, {
    required String fallbackPlatform,
  }) {
    if (json == null) {
      throw StateError('Session auth response body was empty');
    }
    final expiresIn = (json['expires_in'] as num?)?.toInt() ?? 0;
    return DeviceAuthBundle(
      deviceId: json['device_id'] as String,
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresAt: DateTime.now().toUtc().add(Duration(seconds: expiresIn)),
      platform: (json['platform'] as String?) ?? fallbackPlatform,
    );
  }

  String _platformLabel() {
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      TargetPlatform.android => 'android',
      _ => 'android',
    };
  }

  String _appVersion(PackageInfo packageInfo) {
    if (packageInfo.buildNumber.isEmpty) {
      return packageInfo.version;
    }
    return '${packageInfo.version}+${packageInfo.buildNumber}';
  }
}
