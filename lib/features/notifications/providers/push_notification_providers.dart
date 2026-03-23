import 'package:blips_mobile/features/notifications/data/push_notifications_controller.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Shared push-notification controller.
final pushNotificationsControllerProvider =
    Provider<PushNotificationsController>((ref) {
  final controller = PushNotificationsController(ref);
  ref.onDispose(() {
    controller.dispose();
  });
  return controller;
});
