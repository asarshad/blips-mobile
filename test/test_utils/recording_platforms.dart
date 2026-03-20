import 'package:share_plus/share_plus.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

final class RecordingUrlLauncherPlatform extends UrlLauncherPlatform {
  final List<
      ({
        String url,
        bool useSafariVC,
        bool useWebView,
        bool enableJavaScript,
        bool enableDomStorage,
        bool universalLinksOnly,
        Map<String, String> headers,
        String? webOnlyWindowName,
      })> launches = [];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) async {
    launches.add((
      url: url,
      useSafariVC: useSafariVC,
      useWebView: useWebView,
      enableJavaScript: enableJavaScript,
      enableDomStorage: enableDomStorage,
      universalLinksOnly: universalLinksOnly,
      headers: headers,
      webOnlyWindowName: webOnlyWindowName,
    ));
    return true;
  }

  @override
  Future<void> closeWebView() async {}
}

final class RecordingSharePlatform extends SharePlatform {
  final List<ShareParams> shares = [];

  @override
  Future<ShareResult> share(ShareParams params) async {
    shares.add(params);
    return const ShareResult('test', ShareResultStatus.success);
  }
}

SharePlus buildRecordingSharePlus(RecordingSharePlatform platform) {
  return SharePlus.custom(platform);
}
