import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Configure video optimizations channel
    setupVideoOptimizationsChannel()
    
    // Pre-configure audio session for video playback
    configureAudioSession()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func setupVideoOptimizationsChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }
    
    let channel = FlutterMethodChannel(
      name: "blips/video_optimizations",
      binaryMessenger: controller.binaryMessenger
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
      
      // Configure for video playback with optimal settings
      try audioSession.setCategory(
        .playback,
        mode: .moviePlayback,
        options: [.mixWithOthers, .duckOthers]
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
