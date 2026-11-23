import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var appInfoChannel: FlutterMethodChannel?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let infoRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "FlyproxAppInfo") {
      let channel = FlutterMethodChannel(name: "flyprox/app_info", binaryMessenger: infoRegistrar.messenger())
      channel.setMethodCallHandler { call, result in
        guard call.method == "getVersion" else { result(FlutterMethodNotImplemented); return }
        result(["version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
                "buildNumber": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""])
      }
      appInfoChannel = channel
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ContactAccessBridge") {
      ContactAccessBridge.register(with: registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "InvitationBridge") {
      InvitationBridge.register(with: registrar)
    }
  }
}
