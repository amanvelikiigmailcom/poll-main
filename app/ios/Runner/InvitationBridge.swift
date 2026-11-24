import Flutter
import MessageUI
import ContactsUI
import UIKit

/// One explicit recipient per invitation. No address-book enumeration and no
/// delivery claims: MessageUI only reports the compose result.
final class InvitationBridge: NSObject, FlutterPlugin, MFMessageComposeViewControllerDelegate, CNContactPickerDelegate, UIAdaptivePresentationControllerDelegate {
  private var pending: FlutterResult?
  private var pickingContact = false

  static func register(with registrar: FlutterPluginRegistrar) {
    let bridge = InvitationBridge()
    let channel = FlutterMethodChannel(name: "flyprox/invitations", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(bridge, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard pending == nil else {
      result(FlutterError(code: "busy", message: "Finish the current invitation first.", details: nil)); return
    }
    guard let presenter = Self.presenter(), presenter.presentedViewController == nil else {
      result(FlutterError(code: "busy", message: "Close the current sheet first.", details: nil)); return
    }
    if call.method == "pickRecipient" {
      let picker = CNContactPickerViewController()
      picker.delegate = self
      picker.displayedPropertyKeys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey]
      picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
      picker.predicateForSelectionOfContact = NSPredicate(value: false)
      picker.predicateForSelectionOfProperty = NSPredicate(format: "key == 'phoneNumbers'")
      pending = result
      pickingContact = true
      presenter.present(picker, animated: true)
      picker.presentationController?.delegate = self
    } else if call.method == "openWhatsApp" {
      let args = call.arguments as? [String: Any] ?? [:]
      guard let recipient = args["recipient"] as? String,
            recipient.range(of: "^\\+[1-9][0-9]{7,14}$", options: .regularExpression) != nil,
            let body = args["body"] as? String, body.count <= 4096 else {
        result(FlutterError(code: "invalid", message: "Invalid invitation.", details: nil)); return
      }
      var components = URLComponents()
      components.scheme = "whatsapp"
      components.host = "send"
      components.queryItems = [URLQueryItem(name: "phone", value: String(recipient.dropFirst())), URLQueryItem(name: "text", value: body)]
      guard let url = components.url, UIApplication.shared.canOpenURL(url) else {
        result("unavailable"); return
      }
      UIApplication.shared.open(url, options: [:]) { opened in result(opened ? "opened" : "unavailable") }
    } else if call.method == "share" {
      let args = call.arguments as? [String: Any] ?? [:]
      guard let body = args["body"] as? String, body.count <= 4096 else {
        result(FlutterError(code: "invalid", message: "Invalid invitation.", details: nil)); return
      }
      let sheet = UIActivityViewController(activityItems: [body], applicationActivities: nil)
      sheet.popoverPresentationController?.sourceView = presenter.view
      sheet.popoverPresentationController?.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 1, height: 1)
      pending = result
      pickingContact = false
      sheet.completionWithItemsHandler = { [weak self] _, completed, _, error in
        let callback = self?.pending
        self?.pending = nil
        callback?(error != nil ? "failed" : completed ? "shared" : "cancelled")
      }
      presenter.present(sheet, animated: true)
    } else if call.method == "compose" {
      guard MFMessageComposeViewController.canSendText() else { result("unavailable"); return }
      let args = call.arguments as? [String: Any] ?? [:]
      guard let body = args["body"] as? String, body.count <= 4096 else {
        result(FlutterError(code: "invalid", message: "Invalid invitation text.", details: nil)); return
      }
      let composer = MFMessageComposeViewController()
      composer.messageComposeDelegate = self
      composer.body = body
      if let recipient = args["recipient"] as? String { composer.recipients = [recipient] }
      pending = result
      pickingContact = false
      presenter.present(composer, animated: true)
      composer.presentationController?.delegate = self
    } else {
      result(FlutterMethodNotImplemented)
    }
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    let callback = pending
    pending = nil
    callback?(pickingContact ? nil : "cancelled")
  }

  private static func presenter() -> UIViewController? {
    UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
      .filter { $0.activationState == .foregroundActive }
      .flatMap { $0.windows }.first { $0.isKeyWindow }?.rootViewController
  }

  func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
    let value: String
    switch result {
    case .sent: value = "sent"
    case .cancelled: value = "cancelled"
    case .failed: value = "failed"
    @unknown default: value = "failed"
    }
    let callback = pending
    pending = nil
    controller.dismiss(animated: true) { callback?(value) }
  }

  func contactPicker(_ picker: CNContactPickerViewController, didSelect contactProperty: CNContactProperty) {
    let contact = contactProperty.contact
    let callback = pending
    pending = nil
    let value: [String: String] = [
      "name": CNContactFormatter.string(from: contact, style: .fullName) ?? "Friend",
      "phone": (contactProperty.value as? CNPhoneNumber)?.stringValue ?? ""
    ]
    picker.dismiss(animated: true) { callback?(value) }
  }

  func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
    let callback = pending
    pending = nil
    picker.dismiss(animated: true) { callback?(nil) }
  }
}
