import 'package:flutter_native_contact_picker/model/contact.dart';
import 'package:flyprox_app/services/contact_picker_driver.dart';

/// Scripted OS picker: multi and single sessions return canned contacts.
/// Null entries simulate the user cancelling that session.
class FakeContactPickerDriver implements ContactPickerDriver {
  FakeContactPickerDriver({
    this.available = true,
    this.multiPick = true,
    this.manyResult,
    this.oneResults = const [],
  });

  bool available;
  bool multiPick;
  List<Contact>? manyResult;
  List<Contact?> oneResults;

  int pickManyCalls = 0;
  int pickOneCalls = 0;

  @override
  bool get isAvailable => available;

  @override
  bool get supportsMultiPick => multiPick;

  @override
  Future<List<Contact>?> pickMany({int maxNames = 50}) async {
    pickManyCalls++;
    return manyResult;
  }

  @override
  Future<Contact?> pickOne() async {
    if (pickOneCalls >= oneResults.length) return null;
    return oneResults[pickOneCalls++];
  }
}

/// Driver that always throws: proves the service never throws.
class ThrowingContactPickerDriver implements ContactPickerDriver {
  @override
  bool get isAvailable => true;

  @override
  bool get supportsMultiPick => true;

  @override
  Future<List<Contact>?> pickMany({int maxNames = 50}) => throw StateError('no native side');

  @override
  Future<Contact?> pickOne() => throw StateError('no native side');
}
