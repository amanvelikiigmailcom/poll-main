import 'dart:io';

import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:flutter_native_contact_picker/model/contact.dart';

import 'contact_picker_driver.dart';

ContactPickerDriver createContactPickerDriver() =>
    NativeContactPickerDriver();

/// Production driver: the OS-native contact picker. No contacts permission
/// is requested; the app receives only the user's final selection.
class NativeContactPickerDriver implements ContactPickerDriver {
  final FlutterNativeContactPicker _picker = FlutterNativeContactPicker();

  @override
  bool get isAvailable => Platform.isAndroid || Platform.isIOS;

  @override
  bool get supportsMultiPick => Platform.isIOS;

  @override
  Future<List<Contact>?> pickMany() => _picker.selectContacts();

  @override
  Future<Contact?> pickOne() => _picker.selectContact();
}
