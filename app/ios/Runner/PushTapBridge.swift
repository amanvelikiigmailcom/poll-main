import Flutter
import UIKit
import UserNotifications
import Foundation

/// Routes taps on plain APNs pushes (Appwrite Messaging, no FCM message id).
/// FlutterFire only forwards FCM taps to Dart, so this delegate captures the
/// rest: it is installed before plugin registration, FlutterFire keeps it as
/// the original delegate and forwards non-FCM taps back here.
final class PushTapBridge: NSObject, UNUserNotificationCenterDelegate {
  static let shared = PushTapBridge()

  private var channel: FlutterMethodChannel?
  private var pendingPayload: [String: String]?
  private var liveArmed = false
  private let lock = NSLock()

  /// Installs the tap delegate before FlutterFire captures it. Call first in
  /// application(didFinishLaunching:), before the engine registers plugins.
  static func installEarly(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
    UNUserNotificationCenter.current().delegate = shared
    if let remote = launchOptions?[.remoteNotification] as? [AnyHashable: Any],
      let payload = PushTapPayload.decode(remote)
    {
      shared.lock.lock()
      shared.pendingPayload = payload
      shared.lock.unlock()
    }
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "flyprox/push_tap", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "getInitialPush":
        result(shared.takePending())
      case "setArmed":
        shared.lock.lock()
        shared.liveArmed = (call.arguments as? Bool) ?? false
        shared.lock.unlock()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    shared.channel = channel
  }

  /// Only taps are captured; foreground presentation stays with the
  /// Firebase-configured options. Always calls completionHandler: when
  /// FlutterFire forwards a tap here, this side owns completion.
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    #if DEBUG
      NSLog(
        "[PushTap] tap keys: %@",
        userInfo.keys.map { String(describing: $0) }.sorted().joined(separator: ","))
    #endif
    if let payload = PushTapPayload.decode(userInfo) {
      deliver(payload: payload)
    }
    completionHandler()
  }

  private func deliver(payload: [String: String]) {
    lock.lock()
    let armed = liveArmed
    if !armed { pendingPayload = payload }
    let channel = self.channel
    lock.unlock()
    if armed {
      DispatchQueue.main.async { channel?.invokeMethod("onPushTap", arguments: payload) }
    }
  }

  private func takePending() -> [String: String]? {
    lock.lock()
    defer { lock.unlock() }
    let payload = pendingPayload
    pendingPayload = nil
    return payload
  }
}


// Foundation-only decoder; exercised separately without building the iOS app.
enum PushTapPayload {
  static func decode(_ userInfo: [AnyHashable: Any]) -> [String: String]? {
    let data: [AnyHashable: Any]
    if userInfo["type"] != nil {
      data = userInfo
    } else if let nested = userInfo["data"] as? [AnyHashable: Any] {
      data = nested
    } else if let json = userInfo["data"] as? String,
      let bytes = json.data(using: .utf8),
      let nested = (try? JSONSerialization.jsonObject(with: bytes)) as? [String: Any] {
      data = nested
    } else {
      return nil
    }
    guard let rawType = data["type"] as? String else { return nil }
    let type = rawType.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !type.isEmpty, type.count <= 64 else { return nil }
    var payload = ["type": type]
    for key in ["recipientId", "eventId", "actorId"] {
      if let value = data[key] {
        guard let text = value as? String,
          text.range(of: "^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$", options: .regularExpression)?.upperBound == text.endIndex
        else { return nil }
        payload[key] = text
      }
    }
    return payload
  }
}
