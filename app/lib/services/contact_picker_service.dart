import 'package:flutter/foundation.dart';
import 'package:flutter_native_contact_picker/model/contact.dart';

import 'contact_picker_driver.dart';
import 'contact_picker_driver_stub.dart'
    if (dart.library.io) 'contact_picker_driver_io.dart'
    as driver_impl;

/// One picked contact: display name plus the first phone number when the
/// contact has one. Phones stay on the device unless the user syncs them.
class PickedContact {
  final String name;
  final String? phone;

  const PickedContact({required this.name, this.phone});
}

/// Participant names from the OS contact picker.
///
/// The user selects contacts in system UI; the app receives only that final
/// selection (names are used locally; selected phones can be hashed for matching). All
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
    final raw = await _pickRaw(maxNames: maxNames, excludeLower: excludeLower);
    return raw.map((c) => c.fullName!.trim()).toList();
  }

  /// Same as [pickNames] but keeps each contact's first phone number for
  /// optional server syncing. Phones are returned, never stored here.
  Future<List<PickedContact>> pickEntries({
    required int maxNames,
    Set<String> excludeLower = const {},
    bool single = false,
    bool Function(String phone)? isOwnPhone,
  }) async {
    final raw = await _pickRaw(
      maxNames: maxNames,
      excludeLower: excludeLower,
      single: single,
      isOwnPhone: isOwnPhone,
    );
    return raw.map((c) {
      String? phone;
      for (final p in c.phoneNumbers ?? const <String>[]) {
        final trimmed = p.trim();
        if (trimmed.isNotEmpty) {
          phone = trimmed;
          break;
        }
      }
      return PickedContact(name: c.fullName!.trim(), phone: phone);
    }).toList();
  }

  Future<List<Contact>> _pickRaw({
    required int maxNames,
    Set<String> excludeLower = const {},
    bool single = false,
    bool Function(String phone)? isOwnPhone,
  }) async {
    if (maxNames <= 0) return [];
    bool eligible(Contact contact) =>
        isOwnPhone == null ||
        !(contact.phoneNumbers ?? const <String>[]).any(isOwnPhone);
    try {
      if (single) {
        final picked = await _driver.pickOne();
        return picked == null || !eligible(picked)
            ? []
            : _dedupe([picked], excludeLower);
      }
      if (_driver.supportsMultiPick) {
        final picked = await _driver.pickMany(maxNames: maxNames);
        if (picked == null) return [];
        return _dedupe(
          picked.where(eligible),
          excludeLower,
        ).take(maxNames).toList();
      }
      final out = <Contact>[];
      final seen = <String>{...excludeLower};
      // Each round trips through visible system UI where the user can cancel;
      // the attempt cap only guards against a misbehaving driver.
      var attempts = 0;
      while (out.length < maxNames && attempts < maxNames + 10) {
        attempts++;
        final one = await _driver.pickOne();
        if (one == null) break;
        if (!eligible(one)) continue;
        final name = (one.fullName ?? '').trim();
        final key = name.toLowerCase();
        if (name.isEmpty || seen.contains(key)) continue;
        seen.add(key);
        out.add(one);
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  List<Contact> _dedupe(Iterable<Contact> contacts, Set<String> excludeLower) {
    final out = <Contact>[];
    final seen = <String>{...excludeLower};
    for (final c in contacts) {
      final name = (c.fullName ?? '').trim();
      final key = name.toLowerCase();
      if (name.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      out.add(c);
    }
    return out;
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
