import Contacts
import ContactsUI
import Flutter
import SwiftUI
import UIKit

/// iOS 18 limited-access UI. The legacy plugin remains the iOS 15–17 fallback.
final class ContactAccessBridge: NSObject, FlutterPlugin, UIAdaptivePresentationControllerDelegate {
  private var pending: FlutterResult?
  private var host: UIViewController?
  private let store = CNContactStore()

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flyprox/contact_access", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(ContactAccessBridge(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "pickContacts" else { result(FlutterMethodNotImplemented); return }
    guard #available(iOS 18.0, *) else {
      result(FlutterError(code: "unsupported_ios", message: "Requires iOS 18", details: nil)); return
    }
    guard pending == nil else {
      result(FlutterError(code: "picker_busy", message: "Contact selection is already open", details: nil)); return
    }
    guard let presenter = Self.presenter() else {
      result(FlutterError(code: "no_presenter", message: "Cannot open contact selection", details: nil)); return
    }
    let args = call.arguments as? [String: Any] ?? [:]
    let limit = min(max(args["limit"] as? Int ?? 10, 1), 10)
    pending = result
    let model = ContactAccessModel(store: store, limit: limit)
    let view = ContactAccessSelection(model: model, onCancel: { [weak self] in
      self?.finish([])
    }, onDone: { [weak self] identifiers in
      self?.readSelection(identifiers)
    })
    let controller = UIHostingController(rootView: view)
    host = controller
    presenter.present(controller, animated: true)
    controller.presentationController?.delegate = self
  }

  private static func presenter() -> UIViewController? {
    var current = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .filter { $0.activationState == .foregroundActive }
      .flatMap { $0.windows }.first { $0.isKeyWindow }?.rootViewController
    while let presented = current?.presentedViewController { current = presented }
    return current
  }

  private func readSelection(_ ids: [String]) {
    // Only explicitly checked rows. No phone numbers are read while browsing.
    guard !ids.isEmpty else { finish([]); return }
    let keys = [CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
                CNContactPhoneNumbersKey as CNKeyDescriptor]
    do {
      let contacts = try store.unifiedContacts(matching: CNContact.predicateForContacts(withIdentifiers: ids), keysToFetch: keys)
      let byId = Dictionary(contacts.map { ($0.identifier, $0) }, uniquingKeysWith: { first, _ in first })
      let values: [[String: Any]] = ids.compactMap { id in
        guard let contact = byId[id] else { return nil } // access may have been revoked
        return ["fullName": CNContactFormatter.string(from: contact, style: .fullName) ?? "",
                "phoneNumbers": contact.phoneNumbers.prefix(1).map { $0.value.stringValue }]
      }
      finish(values)
    } catch {
      finish(FlutterError(code: "contacts_unavailable", message: "Contact access changed. Try selecting again.", details: nil))
    }
  }

  private func finish(_ value: Any?) {
    guard let result = pending else { return }
    pending = nil
    let controller = host
    host = nil
    if let controller, controller.presentingViewController != nil {
      controller.dismiss(animated: true) { result(value) }
    } else { result(value) }
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) { finish([]) }
}

@available(iOS 18.0, *)
private struct ContactName: Identifiable, Sendable {
  let id: String
  let name: String
}

@available(iOS 18.0, *)
@MainActor
private final class ContactAccessModel: ObservableObject {
  @Published var status = CNContactStore.authorizationStatus(for: .contacts)
  @Published var contacts: [ContactName] = []
  @Published var selected: Set<String> = []
  @Published var query = ""
  @Published var showAccessPicker = false
  @Published var loading = false
  @Published var message: String?
  let limit: Int
  private let store: CNContactStore
  private var started = false
  private var generation = 0
  private var selectFirstShared = false
  private let queue = DispatchQueue(label: "com.flyprox.selected-contact-names", qos: .userInitiated)

  init(store: CNContactStore, limit: Int) { self.store = store; self.limit = limit }

  func start() async {
    guard !started else { return }
    started = true
    if status == .notDetermined {
      do { _ = try await store.requestAccess(for: .contacts) }
      catch { message = "Contacts access was not granted. You can add names instead." }
      status = CNContactStore.authorizationStatus(for: .contacts)
      reload(selectInitialLimited: status == .limited) // initial permission UI already selected contacts
    } else if status == .limited {
      reload()
      showAccessPicker = true
    } else { reload() }
  }

  func reload(selecting identifiers: [String] = [], selectInitialLimited: Bool = false) {
    for id in identifiers where selected.count < limit { selected.insert(id) }
    if selectInitialLimited { selectFirstShared = true }
    status = CNContactStore.authorizationStatus(for: .contacts)
    generation += 1
    let requestGeneration = generation
    let access = status
    let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
    // Full access is not an invitation to enumerate the address book.
    // Require an actual name query, stop after 50 results, fetch names only.
    guard access == .limited || (access == .authorized && !text.isEmpty) else {
      contacts = []; loading = false
      if access == .denied || access == .restricted { selected = [] }
      return
    }
    loading = true
    queue.async { [weak self] in
      let store = CNContactStore()
      var rows: [ContactName] = []
      var failed = false
      do {
        let request = CNContactFetchRequest(keysToFetch: [CNContactFormatter.descriptorForRequiredKeys(for: .fullName)])
        request.sortOrder = .userDefault
        if access == .authorized { request.predicate = CNContact.predicateForContacts(matchingName: text) }
        try store.enumerateContacts(with: request) { contact, stop in
          let name = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
          if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            rows.append(ContactName(id: contact.identifier, name: name))
          }
          if access == .authorized && rows.count >= 50 { stop.pointee = true }
        }
      } catch { failed = true }
      DispatchQueue.main.async { [weak self] in
        guard let self, self.generation == requestGeneration else { return }
        self.contacts = rows
        // Filtering a full-access search must not remove choices from other queries.
        if access == .limited {
          self.selected.formIntersection(Set(rows.map(\.id)))
          if self.selectFirstShared {
            self.selected.formUnion(rows.prefix(self.limit).map(\.id))
            self.selectFirstShared = false
          }
        }
        self.loading = false
        self.message = failed ? "Couldn’t load contacts. Check access in Settings and try again." : nil
      }
    }
  }

  var visible: [ContactName] {
    guard status == .limited, !query.isEmpty else { return contacts }
    return contacts.filter { $0.name.localizedCaseInsensitiveContains(query) }
  }

  func toggle(_ id: String) {
    if selected.contains(id) { selected.remove(id) }
    else if selected.count < limit { selected.insert(id) }
  }
}

@available(iOS 18.0, *)
private struct ContactAccessSelection: View {
  @ObservedObject var model: ContactAccessModel
  let onCancel: () -> Void
  let onDone: ([String]) -> Void
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    NavigationStack {
      List {
        Section {
          Text("Choose up to \(model.limit) participants. Only the names you confirm are added to your game.")
            .font(.subheadline).foregroundStyle(.secondary)
        }
        if model.status == .limited {
          Section {
            Button("Choose more contacts…") { model.showAccessPicker = true }
            if !model.query.isEmpty {
              // Apple performs the search for contacts not yet shared with the app.
              ContactAccessButton(queryString: model.query) { identifiers in model.reload(selecting: identifiers) }
            }
          } footer: { Text("You control which contacts Flyprox can access in iPhone Settings.") }
        }
        if model.status == .denied || model.status == .restricted {
          Section {
            Text("Contacts access is off. You can cancel and enter nicknames instead.")
            if model.status == .denied {
              Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
              }
            }
          }
        } else {
          Section {
            if model.loading { ProgressView() }
            ForEach(model.visible) { contact in
              Button { model.toggle(contact.id) } label: {
                HStack {
                  Text(contact.name).foregroundStyle(.primary)
                  Spacer()
                  Image(systemName: model.selected.contains(contact.id) ? "checkmark.circle.fill" : "circle")
                }.contentShape(Rectangle())
              }
              .accessibilityAddTraits(model.selected.contains(contact.id) ? .isSelected : [])
            }
            if !model.loading && model.visible.isEmpty {
              Text(model.status == .authorized && model.query.isEmpty
                ? "Search by name to choose contacts."
                : "No matching shared contacts. Try another name or choose more contacts.")
                .foregroundStyle(.secondary)
            }
          } header: { Text("Selected: \(model.selected.count) / \(model.limit)") }
        }
        if let message = model.message { Text(message).foregroundStyle(.secondary) }
      }
      .navigationTitle("Choose contacts")
      .navigationBarTitleDisplayMode(.inline)
      .searchable(text: $model.query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search contacts")
      .onChange(of: model.query) { _, _ in model.reload() }
      .onChange(of: scenePhase) { _, phase in if phase == .active { model.reload() } }
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) }
        ToolbarItem(placement: .confirmationAction) {
          Button("Add (\(model.selected.count))") { onDone(model.selected.sorted()) }
            .disabled(model.selected.isEmpty || model.loading)
        }
      }
      .contactAccessPicker(isPresented: $model.showAccessPicker) { identifiers in model.reload(selecting: identifiers) }
      .task { await model.start() }
    }
  }
}
