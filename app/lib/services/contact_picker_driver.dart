import 'package:flutter_native_contact_picker/model/contact.dart';

/// OS contact picker behind a seam tests can fake.
///
/// The native picker shows the system address-book UI; the user taps
/// contacts and the OS hands the app only that final selection. No contacts
/// permission is involved, so [isAvailable] is purely about platform support.
abstract class ContactPickerDriver {
  /// Whether the OS picker exists on this device (false on web/desktop).
  bool get isAvailable;

  /// Whether one picker session can return several contacts (iOS only).
  bool get supportsMultiPick;

  /// One multi-select session; null when the user cancels.
  Future<List<Contact>?> pickMany();

  /// One single-contact session; null when the user cancels.
  Future<Contact?> pickOne();
}
