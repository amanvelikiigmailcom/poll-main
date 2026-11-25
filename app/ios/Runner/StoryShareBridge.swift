import Flutter
import UIKit

/// Editor handoff, never automatic publication. No tracking identifiers.
final class StoryShareBridge: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "flyprox/story_share", binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(StoryShareBridge(), channel: channel)
  }

  private func configured(_ key: String) -> String? {
    guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
      !value.isEmpty, !value.contains("$(") else { return nil }
    return value
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "shareStory" else { result(FlutterMethodNotImplemented); return }
    guard let args = call.arguments as? [String: Any],
      let data = (args["png"] as? FlutterStandardTypedData)?.data,
      !data.isEmpty, data.count <= 10 * 1024 * 1024 else {
      result(FlutterError(code: "invalid", message: "Invalid image.", details: nil))
      return
    }
    let target = args["target"] as? String
    var components: URLComponents
    var item: [String: Any]
    if target == "instagram", let appID = configured("FlyproxMetaAppID"),
      let url = URLComponents(string: "instagram-stories://share") {
      components = url
      components.queryItems = [URLQueryItem(name: "source_application", value: appID)]
      item = ["com.instagram.sharedSticker.backgroundImage": data]
    } else if target == "snapchat", let clientID = configured("FlyproxSnapClientID"),
      let url = URLComponents(string: "snapchat://creativekit/preview/1") {
      components = url
      components.queryItems = [
        URLQueryItem(name: "clientId", value: clientID),
        URLQueryItem(name: "appDisplayName", value: "Flyprox")
      ]
      item = [
        "com.snapchat.creativekit.clientID": clientID,
        "com.snapchat.creativekit.backgroundImage": data
      ]
    } else { result("unavailable"); return }

    guard let checkURL = components.url, UIApplication.shared.canOpenURL(checkURL) else {
      result("unavailable"); return
    }
    UIPasteboard.general.setItems([item], options: [
      .expirationDate: Date().addingTimeInterval(300), .localOnly: true
    ])
    if target == "snapchat" {
      components.queryItems?.append(URLQueryItem(
        name: "checkcount", value: String(UIPasteboard.general.changeCount)
      ))
    }
    guard let url = components.url else { result("unavailable"); return }
    UIApplication.shared.open(url, options: [:]) { opened in
      result(opened ? "opened" : "unavailable")
    }
  }
}
