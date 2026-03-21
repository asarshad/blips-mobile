enum AdsMode {
  production,
  admobTest,
  mock,
}

class AdsRuntimeConfig {
  const AdsRuntimeConfig({
    required this.mode,
    this.forceFeedAds = false,
    this.testDeviceIds = const <String>[],
  });

  factory AdsRuntimeConfig.fromEnvironment() {
    const modeName = String.fromEnvironment(
      'BLIPS_ADS_MODE',
      defaultValue: 'production',
    );
    const testDeviceIdsRaw = String.fromEnvironment(
      'BLIPS_ADMOB_TEST_DEVICE_IDS',
      defaultValue: '',
    );

    return AdsRuntimeConfig(
      mode: AdsModeX.parse(modeName),
      forceFeedAds: const bool.fromEnvironment(
        'BLIPS_FORCE_ADS',
        defaultValue: false,
      ),
      testDeviceIds: testDeviceIdsRaw
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
    );
  }

  final AdsMode mode;
  final bool forceFeedAds;
  final List<String> testDeviceIds;

  bool get usesMockAds => mode == AdsMode.mock;

  bool get usesSdkAds => mode != AdsMode.mock;

  bool get usesTestAdUnits => mode == AdsMode.admobTest;

  bool get shouldForceFeedAds => forceFeedAds || mode != AdsMode.production;

  bool get showTestingTools => mode != AdsMode.production;

  String get displayName => switch (mode) {
        AdsMode.production => 'production',
        AdsMode.admobTest => 'admob_test',
        AdsMode.mock => 'mock',
      };
}

extension AdsModeX on AdsMode {
  static AdsMode parse(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'mock':
        return AdsMode.mock;
      case 'admob_test':
      case 'admob-test':
      case 'admobtest':
      case 'test':
        return AdsMode.admobTest;
      default:
        return AdsMode.production;
    }
  }
}
