import 'dart:async';

import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flyprox_app/models/user.dart';
import 'package:flyprox_app/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/fake_secure_storage.dart';

class FailingSecureStorage extends TestFlutterSecureStoragePlatform {
  FailingSecureStorage(super.data);

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async => throw StateError('Keychain unavailable');
}

class DelayedSecureStorage extends TestFlutterSecureStoragePlatform {
  DelayedSecureStorage(super.data);
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    started.complete();
    await release.future;
    await super.write(key: key, value: value, options: options);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, String> secure;
  late StorageService storage;
  setUp(() async {
    secure = useFakeSecureStorage();
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
  });
  tearDown(() => storage.dispose());

  test(
    'token round trip and removal use secure storage, not preferences',
    () async {
      await storage.saveToken('session-A');
      expect(await storage.getToken(), 'session-A');
      expect(secure['auth_token'], 'session-A');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isNot(contains('auth_token')));
      await storage.clearToken();
      expect(await storage.getToken(), isNull);
      expect(secure.containsKey('auth_token'), isFalse);
    },
  );

  test(
    'failed secure write does not announce a new session or reviewer grant',
    () async {
      await storage.saveToken('session-A');
      await storage.savePhone('+16505550001');
      final user = User.fromJson({'id': 'A', 'firstName': 'Alice'});
      await storage.saveUser(user);
      var changes = 0;
      storage.addListener(() => changes++);
      FlutterSecureStoragePlatform.instance = FailingSecureStorage(secure);
      final generation = storage.beginAuthentication();
      await expectLater(
        storage.saveAuthenticatedSession(
          generation,
          token: 'session-B',
          phone: '+16505550002',
          reviewerAccess: true,
        ),
        throwsStateError,
      );
      expect(await storage.getToken(), 'session-A');
      expect(storage.getPhone(), '+16505550001');
      expect(storage.getUser(), user);
      expect(storage.reviewerSkipsAllowed, isFalse);
      expect(changes, 0);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().where((k) => k.startsWith('reviewer_access_v2_')),
        isEmpty,
      );
    },
  );

  test(
    'new session clears old profile and phone before notifying listeners',
    () async {
      await storage.saveToken('session-A');
      await storage.savePhone('+16505550001');
      await storage.saveUser(User.fromJson({'id': 'A'}));
      storage.addListener(() {
        expect(storage.getUser(), isNull);
        expect(storage.getPhone(), isNull);
      });
      expect(
        await storage.saveAuthenticatedSession(
          storage.beginAuthentication(),
          token: 'session-B',
        ),
        isTrue,
      );
      expect(await storage.getToken(), 'session-B');
    },
  );

  test(
    'logout serializes behind an in-flight secure write and cancels it',
    () async {
      final delayed = DelayedSecureStorage(secure);
      FlutterSecureStoragePlatform.instance = delayed;
      final login = storage.saveAuthenticatedSession(
        storage.beginAuthentication(),
        token: 'session-A',
        phone: '+16505550001',
      );
      await delayed.started.future;
      final logout = storage.clearSession();
      delayed.release.complete();
      expect(await login, isFalse);
      await logout;
      expect(await storage.getToken(), isNull);
      expect(storage.getPhone(), isNull);
    },
  );

  test('failed write does not poison later credential operations', () async {
    FlutterSecureStoragePlatform.instance = FailingSecureStorage(secure);
    await expectLater(storage.saveToken('failed'), throwsStateError);
    useFakeSecureStorage();
    await storage.saveToken('session-B');
    expect(await storage.getToken(), 'session-B');
    await storage.clearAll();
    expect(await storage.getToken(), isNull);
    expect(storage.reviewerSkipsAllowed, isFalse);
  });
}
