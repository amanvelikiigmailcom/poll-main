import 'package:flutter/foundation.dart';
import 'package:flutter_native_contact_picker/model/contact.dart';

import 'contact_picker_driver.dart';
import 'contact_picker_driver_stub.dart'
    if (dart.library.io) 'contact_picker_driver_io.dart' as driver_impl;

/// Participant names from the OS contact picker.
///
/// The user selects contacts in system UI; the app receives only that final
/// selection (names are used, phone numbers are dropped immediately). All
/// entry points are total: cancel, unsupported platform, or a plugin error
/// yields an empty list instead of throwing.
class ContactPickerService {
  ContactPickerService._({ContactPickerDriver? driver})
      : _driver = driver ?? driver_impl.createContactPickerDriver();

  static final ContactPickerService instance = ContactPickerService._();

  ContactPickerDriver _driver;

  /// Whether the OS picker exists on this device.
  bool get isAvailable => _driver.isAvailable;

  /// Opens the picker and returns up to [maxNames] fresh participant names.
  ///
  /// Names already in [excludeLower] (lowercased) are skipped. On Android the
  /// picker returns one contact per session, so sessions repeat until
  /// [maxNames] is reached or the user cancels.
  Future<List<String>> pickNames({
    required int maxNames,
    Set<String> excludeLower = const {},
  }) async {
    if (maxNames <= 0) return [];
    try {
      if (_driver.supportsMultiPick) {
        final picked = await _driver.pickMany();
        if (picked == null) return [];
        return namesFromContacts(picked, excludeLower: excludeLower)
            .take(maxNames)
            .toList();
      }
      final names = <String>[];
      final seen = <String>{...excludeLower};
      // Each round trips through visible system UI where the user can cancel;
      // the attempt cap only guards against a misbehaving driver.
      var attempts = 0;
      while (names.length < maxNames && attempts < maxNames + 10) {
        attempts++;
        final one = await _driver.pickOne();
        if (one == null) break;
        final mapped = namesFromContacts([one], excludeLower: seen);
        if (mapped.isEmpty) continue;
        names.addAll(mapped);
        seen.addAll(mapped.map((n) => n.toLowerCase()));
      }
      return names;
    } catch (_) {
      return [];
    }
  }

  /// Maps picked contacts to participant names: trimmed, non-empty,
  /// case-insensitively deduplicated, minus [excludeLower]. Pure.
  static List<String> namesFromContacts(
    Iterable<Contact> contacts, {
    Set<String> excludeLower = const {},
  }) {
    final names = <String>[];
    final seen = <String>{...excludeLower};
    for (final contact in contacts) {
      final name = contact.fullName?.trim() ?? '';
      if (name.isEmpty) continue;
      final key = name.toLowerCase();
      if (seen.contains(key)) continue;
      seen.add(key);
      names.add(name);
    }
    return names;
  }

  @visibleForTesting
  void debugDriver(ContactPickerDriver driver) {
    _driver = driver;
  }

  @visibleForTesting
  void resetDriverForTest() {
    _driver = driver_impl.createContactPickerDriver();
  }
}
