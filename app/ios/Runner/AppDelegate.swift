import Flutter
import UIKit
import StoreKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var rewardPlayer: AVAudioPlayer?
  private var appInfoChannel: FlutterMethodChannel?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    PushTapBridge.installEarly(launchOptions: launchOptions)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let infoRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "FlyproxAppInfo") {
      let channel = FlutterMethodChannel(name: "flyprox/app_info", binaryMessenger: infoRegistrar.messenger())
      channel.setMethodCallHandler { call, result in
        if call.method == "playRewardSound" {
          do {
            let key = infoRegistrar.lookupKey(forAsset: "assets/sounds/reward.wav")
            guard let path = Bundle.main.path(forResource: key, ofType: nil) else { result(false); return }
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)
            self.rewardPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
            self.rewardPlayer?.prepareToPlay()
            result(self.rewardPlayer?.play() ?? false)
          } catch { result(false) }
          return
        }
        if call.method == "getStorefrontCountry" {
          if #available(iOS 15.0, *) {
            Task {
              let storefront = await Storefront.current
              await MainActor.run { result(storefront?.countryCode) }
            }
          } else { result(SKPaymentQueue.default().storefront?.countryCode) }
          return
        }
        if call.method == "getTimezone" { result(TimeZone.current.identifier); return }
        if call.method == "requestReview" {
          DispatchQueue.main.async {
            if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
              if #available(iOS 16.0, *) { AppStore.requestReview(in: scene) }
              else { SKStoreReviewController.requestReview(in: scene) }
            }
            result(nil)
          }
          return
        }
        guard call.method == "getVersion" else { result(FlutterMethodNotImplemented); return }
        result(["version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
                "buildNumber": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""])
      }
      appInfoChannel = channel
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PushTapBridge") {
      PushTapBridge.register(with: registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ContactAccessBridge") {
      ContactAccessBridge.register(with: registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "InvitationBridge") {
      InvitationBridge.register(with: registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "StoryShareBridge") {
      StoryShareBridge.register(with: registrar)
    }
  }
}
