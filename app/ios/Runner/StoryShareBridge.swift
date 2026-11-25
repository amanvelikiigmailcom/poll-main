import Flutter
import UIKit

/// Hands a result screenshot to the Instagram story composer.
///
/// The image travels on a short-lived pasteboard item, then the
/// `instagram-stories://share` URL opens the composer with it attached.
/// Snapchat exposes no equivalent direct-story API, so Snapchat sharing
/// stays in Dart on the system share sheet.
final class StoryShareBridge: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let bridge = StoryShareBridge()
    let channel = FlutterMethodChannel(
      name: "flyprox/story_share",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(bridge, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "shareInstagramStory" else {
      result(FlutterMethodNotImplemented)
      return
    }
    let args = call.arguments as? [String: Any] ?? [:]
    let data =
      (args["png"] as? FlutterStandardTypedData)?.data ?? args["png"] as? Data
    guard let data, !data.isEmpty, data.count <= 10 * 1024 * 1024 else {
      result(
        FlutterError(code: "invalid", message: "Invalid image.", details: nil)
      )
      return
    }
    guard let url = URL(string: "instagram-stories://share"),
      UIApplication.shared.canOpenURL(url)
    else {
      result("unavailable")
      return
    }
    UIPasteboard.general.setItems(
      [["com.instagram.sharedSticker.backgroundImage": data]],
      options: [.expirationDate: Date().addingTimeInterval(300)]
    )
    UIApplication.shared.open(url, options: [:]) { opened in
      result(opened ? "shared" : "unavailable")
    }
  }
}
