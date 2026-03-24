import 'dart:async';

import 'package:blips_mobile/core/config/remote_app_config.dart';
import 'package:blips_mobile/core/error/error.dart';
import 'package:blips_mobile/core/network/dio_provider.dart';
import 'package:blips_mobile/core/services/device_id_service.dart';
import 'package:blips_mobile/features/ads/providers/ads_providers.dart';
import 'package:blips_mobile/features/notifications/domain/notification_target.dart';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kStoredPushTokenKey = 'push_last_synced_token';
const _kAndroidChannelId = 'blips_news_updates';
const _kAndroidChannelName = 'News updates';
const _kAndroidChannelDescription =
    'Alerts for newly published articles and videos.';

/// Coordinates push permissions, token sync, and notification open intents.
class PushNotificationsController {
  PushNotificationsController(
    this._ref, {
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  })  : _messagingOverride = messaging,
        _localNotifications =
            localNotifications ?? FlutterLocalNotificationsPlugin();

  final Ref _ref;
  final FirebaseMessaging? _messagingOverride;
  final FlutterLocalNotificationsPlugin _localNotifications;

  StreamSubscription<RemoteMessage>? _onMessageSubscription;
  StreamSubscription<RemoteMessage>? _onMessageOpenedSubscription;
  StreamSubscription<String>? _onTokenRefreshSubscription;
  Future<void>? _startupFuture;

  Future<void> ensureStarted() {
    final inFlight = _startupFuture;
    if (inFlight != null) return inFlight;

    final future = _start();
    _startupFuture = future;
    future.whenComplete(() {
      if (identical(_startupFuture, future)) {
        _startupFuture = null;
      }
    });
    return future;
  }

  Future<void> onEligibleShellEntered() async {
    await ensureStarted();
    final messaging = _resolveMessaging();
    if (messaging == null) return;

    final config = await _fetchPushConfig();
    if (!config.enabled) {
      await unregisterCurrentSubscription();
      return;
    }

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    await _syncPermissionAndToken(
      settings: settings,
      config: config,
    );
  }

  Future<void> handleAppResume() async {
    await ensureStarted();
    final messaging = _resolveMessaging();
    if (messaging == null) return;

    final config = await _fetchPushConfig();
    if (!config.enabled) {
      await unregisterCurrentSubscription();
      return;
    }

    final settings = await messaging.getNotificationSettings();
    await _syncPermissionAndToken(
      settings: settings,
      config: config,
    );
  }

  Future<void> unregisterCurrentSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString(_kStoredPushTokenKey);
    if (storedToken == null || storedToken.isEmpty) return;

    try {
      final dio = _ref.read(dioProvider);
      final deviceId = await _ref.read(deviceIdProvider.future);
      dio.options.headers['X-Device-ID'] = deviceId;
      await dio.delete<void>(
        '/notifications/subscription',
        data: <String, dynamic>{'token': storedToken},
      );
    } on DioException catch (e, stack) {
      logger.warning(
        'Failed to delete push subscription',
        category: LogCategory.network,
        error: e,
        stackTrace: stack,
      );
    } catch (e, stack) {
      logger.warning(
        'Unexpected push unregistration failure',
        category: LogCategory.app,
        error: e,
        stackTrace: stack,
      );
    } finally {
      await prefs.remove(_kStoredPushTokenKey);
    }
  }

  void consumePendingTarget(NotificationTarget target) {
    final state = _ref.read(pendingNotificationTargetProvider);
    if (state == target) {
      _ref.read(pendingNotificationTargetProvider.notifier).state = null;
    }
  }

  Future<void> dispose() async {
    await _onMessageSubscription?.cancel();
    await _onMessageOpenedSubscription?.cancel();
    await _onTokenRefreshSubscription?.cancel();
  }

  Future<void> _start() async {
    final messaging = _resolveMessaging();
    if (messaging == null) {
      logger.info(
        'Push notifications skipped: Firebase is not configured',
        category: LogCategory.lifecycle,
      );
      return;
    }

    await _initializeLocalNotifications();
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    _onMessageSubscription ??=
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    _onMessageOpenedSubscription ??=
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpened);
    _onTokenRefreshSubscription ??=
        messaging.onTokenRefresh.listen(_handleTokenRefresh);

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpened(initialMessage);
    }

    final launchDetails =
        await _localNotifications.getNotificationAppLaunchDetails();
    final response = launchDetails?.notificationResponse;
    final target = NotificationTarget.tryFromPayload(response?.payload);
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      _setPendingTarget(target);
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings();

    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final target = NotificationTarget.tryFromPayload(response.payload);
        _setPendingTarget(target);
      },
    );

    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _kAndroidChannelId,
        _kAndroidChannelName,
        description: _kAndroidChannelDescription,
        importance: Importance.high,
      ),
    );
  }

  Future<PushConfig> _fetchPushConfig() async {
    final repo = _ref.read(appConfigRepositoryProvider);
    final config = await repo.fetchAppConfig();
    return config.push;
  }

  Future<void> _syncPermissionAndToken({
    required NotificationSettings settings,
    required PushConfig config,
    String? refreshedToken,
  }) async {
    if (!config.enabled) {
      await unregisterCurrentSubscription();
      return;
    }

    if (!_isAuthorizationGranted(settings.authorizationStatus)) {
      await unregisterCurrentSubscription();
      return;
    }

    final messaging = _resolveMessaging();
    if (messaging == null) return;

    final token = refreshedToken ?? await messaging.getToken();
    if (token == null || token.isEmpty) {
      return;
    }
    await _registerToken(token);
  }

  Future<void> _registerToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final previousToken = prefs.getString(_kStoredPushTokenKey);
    final dio = _ref.read(dioProvider);
    final deviceId = await _ref.read(deviceIdProvider.future);
    dio.options.headers['X-Device-ID'] = deviceId;

    if (previousToken != null &&
        previousToken.isNotEmpty &&
        previousToken != token) {
      try {
        await dio.delete<void>(
          '/notifications/subscription',
          data: <String, dynamic>{'token': previousToken},
        );
      } catch (_) {
        // Keep going; the new token should still win.
      }
    }

    try {
      await dio.put<void>(
        '/notifications/subscription',
        data: <String, dynamic>{
          'token': token,
          'platform': _platformLabel,
        },
      );
      await prefs.setString(_kStoredPushTokenKey, token);
    } on DioException catch (e, stack) {
      logger.warning(
        'Failed to register push token',
        category: LogCategory.network,
        error: e,
        stackTrace: stack,
      );
    } catch (e, stack) {
      logger.warning(
        'Unexpected push registration failure',
        category: LogCategory.app,
        error: e,
        stackTrace: stack,
      );
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final target = NotificationTarget.tryFromMessageData(message.data);
    if (target == null) return;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final title =
            message.notification?.title ?? message.data['title']?.toString();
        final body =
            message.notification?.body ?? message.data['body']?.toString();
        await _localNotifications.show(
          target.contentId,
          title ?? 'Blips update',
          body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _kAndroidChannelId,
              _kAndroidChannelName,
              channelDescription: _kAndroidChannelDescription,
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          payload: target.toEncodedPayload(),
        );
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        break;
    }
  }

  Future<void> _handleTokenRefresh(String token) async {
    final messaging = _resolveMessaging();
    if (messaging == null) return;

    final config = await _fetchPushConfig();
    final settings = await messaging.getNotificationSettings();
    await _syncPermissionAndToken(
      settings: settings,
      config: config,
      refreshedToken: token,
    );
  }

  void _handleMessageOpened(RemoteMessage message) {
    final target = NotificationTarget.tryFromMessageData(message.data);
    _setPendingTarget(target);
  }

  void _setPendingTarget(NotificationTarget? target) {
    if (target == null) return;
    _ref.read(pendingNotificationTargetProvider.notifier).state = target;
  }

  bool _isAuthorizationGranted(AuthorizationStatus status) {
    return status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
  }

  String get _platformLabel {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => 'android',
    };
  }

  FirebaseMessaging? _resolveMessaging() {
    if (_messagingOverride != null) {
      return _messagingOverride;
    }
    if (Firebase.apps.isEmpty) {
      return null;
    }
    return FirebaseMessaging.instance;
  }
}

final pendingNotificationTargetProvider =
    StateProvider<NotificationTarget?>((ref) => null);
