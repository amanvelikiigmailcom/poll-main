import 'dart:io';
import 'package:flutter/services.dart';

import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:flutter_native_contact_picker/model/contact.dart';

import 'contact_picker_driver.dart';

ContactPickerDriver createContactPickerDriver() => NativeContactPickerDriver();

/// iOS 18 uses ContactsUI limited access; older iOS uses the one-time picker.
class NativeContactPickerDriver implements ContactPickerDriver {
  NativeContactPickerDriver({bool? isIOS}) : _isIOS = isIOS ?? Platform.isIOS;

  final bool _isIOS;
  final FlutterNativeContactPicker _picker = FlutterNativeContactPicker();
  static const accessChannel = MethodChannel('flyprox/contact_access');

  @override
  bool get isAvailable => Platform.isAndroid || _isIOS;

  @override
  bool get supportsMultiPick => _isIOS;

  Future<List<Contact>?> _pick({required bool single, int maxNames = 50}) async {
    if (_isIOS) {
      try {
        final rows = await accessChannel.invokeListMethod<dynamic>(
          'pickContacts',
          {'limit': single ? 1 : maxNames.clamp(1, 50)},
        );
        return (rows ?? []).map((raw) {
          final row = Map<String, dynamic>.from(raw as Map);
          return Contact(
            fullName: row['fullName'] as String?,
            phoneNumbers: (row['phoneNumbers'] as List?)?.cast<String>(),
          );
        }).toList();
      } on PlatformException catch (error) {
        if (error.code != 'unsupported_ios') rethrow;
      }
    }
    if (single) {
      final contact = await _picker.selectContact();
      return contact == null ? null : [contact];
    }
    return _picker.selectContacts();
  }

  @override
  Future<List<Contact>?> pickMany({int maxNames = 50}) => _pick(single: false, maxNames: maxNames);

  @override
  Future<Contact?> pickOne() async {
    final contacts = await _pick(single: true);
    return contacts == null || contacts.isEmpty ? null : contacts.first;
  }
}
