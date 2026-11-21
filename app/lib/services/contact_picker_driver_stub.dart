import 'package:flutter_native_contact_picker/model/contact.dart';

import 'contact_picker_driver.dart';

ContactPickerDriver createContactPickerDriver() => StubContactPickerDriver();

/// Web/desktop builds: the plugin has no native side here.
class StubContactPickerDriver implements ContactPickerDriver {
  @override
  bool get isAvailable => false;

  @override
  bool get supportsMultiPick => false;

  @override
  Future<List<Contact>?> pickMany() async => null;

  @override
  Future<Contact?> pickOne() async => null;
}
