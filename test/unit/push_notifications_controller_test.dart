@Tags(['unit'])
library push_notifications_controller_test;

import 'package:blips_mobile/core/network/dio_provider.dart';
import 'package:blips_mobile/core/services/device_id_service.dart';
import 'package:blips_mobile/features/notifications/data/push_notifications_controller.dart';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingDeleteInterceptor extends Interceptor {
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    requests.add(options);
    handler.resolve(
      Response<dynamic>(
        requestOptions: options,
        statusCode: 200,
        data: const <String, dynamic>{},
      ),
    );
  }
}

class _FakeFirebaseMessaging extends Fake implements FirebaseMessaging {}

class _FakeLocalNotificationsPlugin extends Fake
    implements FlutterLocalNotificationsPlugin {}

final _testPushControllerProvider =
    Provider<PushNotificationsController>((ref) {
  final controller = PushNotificationsController(
    ref,
    messaging: _FakeFirebaseMessaging(),
    localNotifications: _FakeLocalNotificationsPlugin(),
  );
  ref.onDispose(() {
    controller.dispose();
  });
  return controller;
});

void main() {
  test('unregisterCurrentSubscription deletes backend token and clears cache',
      () async {
    SharedPreferences.setMockInitialValues(
      const <String, Object>{
        'push_last_synced_token': 'token-123',
      },
    );
    final interceptor = _RecordingDeleteInterceptor();
    final dio = Dio()..interceptors.add(interceptor);
    final container = ProviderContainer(
      overrides: [
        dioProvider.overrideWithValue(dio),
        deviceIdProvider.overrideWith((ref) async => 'device-abc'),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(_testPushControllerProvider)
        .unregisterCurrentSubscription();

    expect(interceptor.requests, hasLength(1));
    final request = interceptor.requests.single;
    expect(request.method, 'DELETE');
    expect(request.path, '/notifications/subscription');
    expect(request.data, const <String, dynamic>{'token': 'token-123'});
    expect(request.headers['X-Device-ID'], 'device-abc');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('push_last_synced_token'), isNull);
  });
}
