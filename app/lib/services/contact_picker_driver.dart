import 'package:flutter_native_contact_picker/model/contact.dart';

/// OS contact picker behind a seam tests can fake.
///
/// The native picker shows the system address-book UI; the user taps
/// contacts and the app returns only that final selection.
/// iOS 18 requests limited contacts access; older versions use a one-time
/// picker. [isAvailable] describes platform support, not authorization.
abstract class ContactPickerDriver {
  /// Whether the OS picker exists on this device (false on web/desktop).
  bool get isAvailable;

  /// Whether one picker session can return several contacts (iOS only).
  bool get supportsMultiPick;

  /// One multi-select session; null when the user cancels.
  Future<List<Contact>?> pickMany({int maxNames = 50});

  /// One single-contact session; null when the user cancels.
  Future<Contact?> pickOne();
}
