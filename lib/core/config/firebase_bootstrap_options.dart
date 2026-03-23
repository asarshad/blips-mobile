import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Build-time Firebase configuration.
///
/// The app fails closed when any required value is missing for the current
/// platform, so push stays disabled rather than partially initializing.
class FirebaseBootstrapOptions {
  FirebaseBootstrapOptions._();

  static FirebaseOptions? get currentPlatform {
    if (kIsWeb) return null;

    const projectId = String.fromEnvironment('BLIPS_FIREBASE_PROJECT_ID');
    const senderId = String.fromEnvironment('BLIPS_FIREBASE_SENDER_ID');
    const apiKey = String.fromEnvironment('BLIPS_FIREBASE_API_KEY');
    const storageBucket =
        String.fromEnvironment('BLIPS_FIREBASE_STORAGE_BUCKET');
    const androidAppId =
        String.fromEnvironment('BLIPS_FIREBASE_ANDROID_APP_ID');
    const iosAppId = String.fromEnvironment('BLIPS_FIREBASE_IOS_APP_ID');
    const iosBundleId = String.fromEnvironment('BLIPS_FIREBASE_IOS_BUNDLE_ID');

    if (projectId.isEmpty || senderId.isEmpty || apiKey.isEmpty) {
      return null;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        if (androidAppId.isEmpty) return null;
        return FirebaseOptions(
          apiKey: apiKey,
          appId: androidAppId,
          messagingSenderId: senderId,
          projectId: projectId,
          storageBucket: storageBucket.isEmpty ? null : storageBucket,
        );
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        if (iosAppId.isEmpty || iosBundleId.isEmpty) return null;
        return FirebaseOptions(
          apiKey: apiKey,
          appId: iosAppId,
          messagingSenderId: senderId,
          projectId: projectId,
          storageBucket: storageBucket.isEmpty ? null : storageBucket,
          iosBundleId: iosBundleId,
        );
      default:
        return null;
    }
  }
}
