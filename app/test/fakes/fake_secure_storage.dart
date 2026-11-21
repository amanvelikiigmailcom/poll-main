import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';

/// Binds secure storage to an in-memory map so login/token checks settle in
/// widget tests (the real channel has no native side here and never settles).
/// Returns the backing map for arrange/assert.
Map<String, String> useFakeSecureStorage() {
  final data = <String, String>{};
  FlutterSecureStoragePlatform.instance =
      TestFlutterSecureStoragePlatform(data);
  return data;
}
