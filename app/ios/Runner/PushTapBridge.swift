import Flutter
import UIKit
import UserNotifications

/// Routes taps on plain APNs pushes (Appwrite Messaging, no FCM message id).
/// FlutterFire only forwards FCM taps to Dart, so this delegate captures the
/// rest: it is installed before plugin registration, FlutterFire keeps it as
/// the original delegate and forwards non-FCM taps back here.
final class PushTapBridge: NSObject, UNUserNotificationCenterDelegate {
  static let shared = PushTapBridge()

  private var channel: FlutterMethodChannel?
  private var pendingType: String?
  private var liveArmed = false
  private let lock = NSLock()

  /// Installs the tap delegate before FlutterFire captures it. Call first in
  /// application(didFinishLaunching:), before the engine registers plugins.
  static func installEarly(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
    UNUserNotificationCenter.current().delegate = shared
    if let remote = launchOptions?[.remoteNotification] as? [AnyHashable: Any],
      let type = pushType(from: remote)
    {
      shared.lock.lock()
      shared.pendingType = type
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
    if let type = Self.pushType(from: userInfo) {
      deliver(type: type)
    }
    completionHandler()
  }

  /// Reads the backend push type defensively: Appwrite custom data may arrive
  /// as a top-level key or nested. Unknown shapes stay unrouted (nil).
  static func pushType(from userInfo: [AnyHashable: Any]) -> String? {
    if let type = userInfo["type"] as? String, !type.isEmpty { return type }
    if let data = userInfo["data"] as? [AnyHashable: Any],
      let type = data["type"] as? String, !type.isEmpty
    {
      return type
    }
    return nil
  }

  private func deliver(type: String) {
    lock.lock()
    let armed = liveArmed
    if !armed { pendingType = type }
    let channel = self.channel
    lock.unlock()
    if armed {
      DispatchQueue.main.async { channel?.invokeMethod("onPushTap", arguments: type) }
    }
  }

  private func takePending() -> String? {
    lock.lock()
    defer { lock.unlock() }
    let type = pendingType
    pendingType = nil
    return type
  }
}
