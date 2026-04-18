import Flutter
import UIKit
import AVFoundation
import GoogleMobileAds
import google_mobile_ads

final class BlipsNativeAdFactory: NSObject, FLTNativeAdFactory {
  static let factoryId = "blipsFeedNative"

  func createNativeAd(
    _ nativeAd: NativeAd,
    customOptions: [AnyHashable: Any]? = nil
  ) -> NativeAdView? {
    let nativeAdView = NativeAdView(frame: .zero)
    nativeAdView.backgroundColor = UIColor(
      red: 15 / 255,
      green: 23 / 255,
      blue: 42 / 255,
      alpha: 1
    )

    let mediaContainer = UIView()
    mediaContainer.translatesAutoresizingMaskIntoConstraints = false
    mediaContainer.backgroundColor = UIColor(
      red: 16 / 255,
      green: 36 / 255,
      blue: 59 / 255,
      alpha: 1
    )
    nativeAdView.addSubview(mediaContainer)

    let mediaView = MediaView()
    mediaView.translatesAutoresizingMaskIntoConstraints = false
    mediaContainer.addSubview(mediaView)

    let sponsoredLabel = PaddingLabel()
    sponsoredLabel.translatesAutoresizingMaskIntoConstraints = false
    sponsoredLabel.text = "Sponsored"
    sponsoredLabel.textColor = .white
    sponsoredLabel.font = .systemFont(ofSize: 12, weight: .bold)
    sponsoredLabel.backgroundColor = UIColor(white: 0, alpha: 0.55)
    sponsoredLabel.layer.cornerRadius = 14
    sponsoredLabel.clipsToBounds = true
    sponsoredLabel.insets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
    mediaContainer.addSubview(sponsoredLabel)

    let contentContainer = UIStackView()
    contentContainer.translatesAutoresizingMaskIntoConstraints = false
    contentContainer.axis = .vertical
    contentContainer.spacing = 14
    nativeAdView.addSubview(contentContainer)

    let placementLabel = UILabel()
    placementLabel.text = "Sponsored placement"
    placementLabel.font = .systemFont(ofSize: 13, weight: .bold)
    placementLabel.textColor = UIColor(
      red: 79 / 255,
      green: 209 / 255,
      blue: 232 / 255,
      alpha: 1
    )
    contentContainer.addArrangedSubview(placementLabel)

    let metadataStack = UIStackView()
    metadataStack.axis = .horizontal
    metadataStack.spacing = 12
    metadataStack.alignment = .center
    contentContainer.addArrangedSubview(metadataStack)

    let iconView = UIImageView()
    iconView.translatesAutoresizingMaskIntoConstraints = false
    iconView.contentMode = .scaleAspectFill
    iconView.clipsToBounds = true
    iconView.layer.cornerRadius = 12
    NSLayoutConstraint.activate([
      iconView.widthAnchor.constraint(equalToConstant: 44),
      iconView.heightAnchor.constraint(equalToConstant: 44),
    ])
    metadataStack.addArrangedSubview(iconView)

    let advertiserLabel = UILabel()
    advertiserLabel.font = .systemFont(ofSize: 14, weight: .bold)
    advertiserLabel.textColor = UIColor(
      red: 203 / 255,
      green: 213 / 255,
      blue: 225 / 255,
      alpha: 1
    )
    advertiserLabel.numberOfLines = 2
    metadataStack.addArrangedSubview(advertiserLabel)

    let headlineLabel = UILabel()
    headlineLabel.font = .systemFont(ofSize: 28, weight: .bold)
    headlineLabel.textColor = UIColor(
      red: 248 / 255,
      green: 250 / 255,
      blue: 252 / 255,
      alpha: 1
    )
    headlineLabel.numberOfLines = 3
    contentContainer.addArrangedSubview(headlineLabel)

    let bodyLabel = UILabel()
    bodyLabel.font = .systemFont(ofSize: 17, weight: .regular)
    bodyLabel.textColor = UIColor(
      red: 203 / 255,
      green: 213 / 255,
      blue: 225 / 255,
      alpha: 1
    )
    bodyLabel.numberOfLines = 8
    contentContainer.addArrangedSubview(bodyLabel)

    let callToActionButton = UIButton(type: .system)
    callToActionButton.backgroundColor = UIColor(
      red: 14 / 255,
      green: 116 / 255,
      blue: 144 / 255,
      alpha: 1
    )
    callToActionButton.setTitleColor(.white, for: .normal)
    callToActionButton.layer.cornerRadius = 14
    callToActionButton.contentEdgeInsets = UIEdgeInsets(
      top: 14,
      left: 18,
      bottom: 14,
      right: 18
    )
    callToActionButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
    callToActionButton.isUserInteractionEnabled = false
    contentContainer.addArrangedSubview(callToActionButton)

    NSLayoutConstraint.activate([
      mediaContainer.topAnchor.constraint(equalTo: nativeAdView.topAnchor),
      mediaContainer.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor),
      mediaContainer.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor),
      mediaContainer.heightAnchor.constraint(equalTo: nativeAdView.heightAnchor, multiplier: 0.35),

      mediaView.topAnchor.constraint(equalTo: mediaContainer.topAnchor),
      mediaView.leadingAnchor.constraint(equalTo: mediaContainer.leadingAnchor),
      mediaView.trailingAnchor.constraint(equalTo: mediaContainer.trailingAnchor),
      mediaView.bottomAnchor.constraint(equalTo: mediaContainer.bottomAnchor),

      sponsoredLabel.topAnchor.constraint(equalTo: mediaContainer.topAnchor, constant: 16),
      sponsoredLabel.leadingAnchor.constraint(equalTo: mediaContainer.leadingAnchor, constant: 16),

      contentContainer.topAnchor.constraint(equalTo: mediaContainer.bottomAnchor, constant: 20),
      contentContainer.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor, constant: 20),
      contentContainer.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor, constant: -20),
      contentContainer.bottomAnchor.constraint(lessThanOrEqualTo: nativeAdView.bottomAnchor, constant: -24),
    ])

    nativeAdView.mediaView = mediaView
    nativeAdView.headlineView = headlineLabel
    nativeAdView.bodyView = bodyLabel
    nativeAdView.callToActionView = callToActionButton
    nativeAdView.iconView = iconView
    nativeAdView.advertiserView = advertiserLabel

    headlineLabel.text = nativeAd.headline
    mediaView.mediaContent = nativeAd.mediaContent

    if let body = nativeAd.body, !body.isEmpty {
      bodyLabel.text = body
      bodyLabel.isHidden = false
    } else {
      bodyLabel.isHidden = true
    }

    if let callToAction = nativeAd.callToAction, !callToAction.isEmpty {
      callToActionButton.setTitle(callToAction, for: .normal)
      callToActionButton.isHidden = false
    } else {
      callToActionButton.isHidden = true
    }

    if let icon = nativeAd.icon?.image {
      iconView.image = icon
      iconView.isHidden = false
    } else {
      iconView.isHidden = true
    }

    if let advertiser = nativeAd.advertiser, !advertiser.isEmpty {
      advertiserLabel.text = advertiser
      advertiserLabel.isHidden = false
    } else {
      advertiserLabel.isHidden = true
    }

    nativeAdView.nativeAd = nativeAd
    return nativeAdView
  }
}

final class PaddingLabel: UILabel {
  var insets = UIEdgeInsets.zero

  override func drawText(in rect: CGRect) {
    super.drawText(in: rect.inset(by: insets))
  }

  override var intrinsicContentSize: CGSize {
    let size = super.intrinsicContentSize
    return CGSize(
      width: size.width + insets.left + insets.right,
      height: size.height + insets.top + insets.bottom
    )
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Pre-configure audio session for video playback
    configureAudioSession()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let nativeAdFactory = BlipsNativeAdFactory()
    FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
      engineBridge.pluginRegistry,
      factoryId: BlipsNativeAdFactory.factoryId,
      nativeAdFactory: nativeAdFactory
    )

    setupVideoOptimizationsChannel(engineBridge)
    setupUIChannel(engineBridge)
  }

  /// Channel: blips/ui
  /// dismissPresentedViewController — dismisses whatever native view controller
  /// is currently presented over Flutter (e.g. the share sheet).  Used when
  /// the user taps the exposed area behind an iOS page-sheet share dialog on
  /// screens that contain a PlatformView (YouTube WebView), which otherwise
  /// intercepts those taps and prevents the sheet from self-dismissing.
  private func setupUIChannel(_ engineBridge: FlutterImplicitEngineBridge) {
    let channel = FlutterMethodChannel(
      name: "blips/ui",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )

    channel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "dismissPresentedViewController":
        DispatchQueue.main.async {
          // iOS 13+: windows are scene-managed; AppDelegate.window may be nil.
          let keyWindow: UIWindow?
          if #available(iOS 13.0, *) {
            keyWindow = UIApplication.shared.connectedScenes
              .compactMap { $0 as? UIWindowScene }
              .flatMap { $0.windows }
              .first { $0.isKeyWindow }
          } else {
            keyWindow = UIApplication.shared.keyWindow
          }

          // Walk to the topmost presented VC so we dismiss it directly.
          var topVC = keyWindow?.rootViewController
          while let next = topVC?.presentedViewController {
            topVC = next
          }

          if let vc = topVC, vc.presentingViewController != nil {
            vc.dismiss(animated: true) { result(nil) }
          } else {
            result(nil)
          }
        }

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func setupVideoOptimizationsChannel(_ engineBridge: FlutterImplicitEngineBridge) {
    let channel = FlutterMethodChannel(
      name: "blips/video_optimizations",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )

    channel.setMethodCallHandler { [weak self] (call, result) in
      switch call.method {
      case "configureAudioSession":
        self?.configureAudioSession()
        result(nil)

      case "prewarmVideoPipeline":
        self?.prewarmVideoPipeline()
        result(nil)

      case "setPreferredBufferDuration":
        if let args = call.arguments as? [String: Any],
           let seconds = args["seconds"] as? Double {
          // Note: Buffer duration is typically managed by the video_player plugin
          // This is a placeholder for custom implementations
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing seconds", details: nil))
        }
        
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func configureAudioSession() {
    do {
      let audioSession = AVAudioSession.sharedInstance()

      // Take a normal foreground media playback session so in-app
      // video volume matches native media apps more closely.
      try audioSession.setCategory(
        .playback,
        mode: .moviePlayback,
        options: []
      )

      // Activate the session
      try audioSession.setActive(true)

      print("Audio session configured for video playback")
    } catch {
      print("Failed to configure audio session: \(error)")
    }
  }

  private func prewarmVideoPipeline() {
    // Pre-warm AVPlayer by creating and immediately releasing a player
    // This loads the video decoder into memory
    DispatchQueue.global(qos: .background).async {
      let tempPlayer = AVPlayer()
      _ = tempPlayer.currentItem
      // Player will be deallocated, but decoder remains warm
    }
    print("Video pipeline pre-warmed")
  }
}
