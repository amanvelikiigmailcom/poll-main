import 'fakes/mock_storage_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/phone_auth_driver.dart';
import 'package:flyprox_app/services/phone_auth_service.dart';
import 'fakes/fake_phone_auth_driver.dart';

class MockApiService extends Mock implements ApiService {}

Response<Map<String, dynamic>> _json(Map<String, dynamic> data) =>
    Response<Map<String, dynamic>>(
      requestOptions: RequestOptions(path: '/api/auth/firebase'),
      data: data,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockApiService api;
  late MockStorageService storage;
  late FakePhoneAuthDriver driver;
  late PhoneAuthService svc;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = MockApiService();
    storage = MockStorageService();
    driver = FakePhoneAuthDriver();
    svc = PhoneAuthService(api: api, storage: storage, driver: driver);
  });

  group('sendCode', () {
    test('returns verification id on success', () async {
      final r = await svc.sendCode('+77071234567');
      expect(r.success, isTrue);
      expect(r.verificationId, 'vid-1');
      expect(r.autoIdToken, isNull);
      expect(driver.lastPhone, '+77071234567');
    });

    test('passes driver errors through as messages', () async {
      driver.sendError = const PhoneAuthException('Too many attempts.');
      final r = await svc.sendCode('+77071234567');
      expect(r.success, isFalse);
      expect(r.message, 'Too many attempts.');
    });
  });

  group('verifyCode', () {
    test('exchanges the id token for a backend session', () async {
      when(
        () => storage.notificationInstallationId(),
      ).thenAnswer((_) async => 'test_installation_123456');
      when(
        () => api.post<Map<String, dynamic>>(
          '/api/auth/firebase',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => _json({'token': 'backend-token', 'isNewUser': true}),
      );
      final r = await svc.verifyCode(
        verificationId: 'vid-1',
        code: '123456',
        phone: '+77071234567',
      );
      expect(r.success, isTrue);
      expect(r.isNewUser, isTrue);
      expect(driver.lastVerificationId, 'vid-1');
      expect(driver.lastSmsCode, '123456');
      verify(() => storage.saveToken('backend-token')).called(1);
      verify(() => storage.savePhone('+77071234567')).called(1);
      final captured =
          verify(
                () => api.post<Map<String, dynamic>>(
                  '/api/auth/firebase',
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(captured['idToken'], 'id-token-1');
      expect(captured['schoolOnboardingVersion'], 1);
      expect(
        captured['notificationInstallationId'],
        'test_installation_123456',
      );
    });

    test('wrong code fails before any backend call', () async {
      driver.confirmError = const PhoneAuthException('Wrong code. Try again.');
      final r = await svc.verifyCode(verificationId: 'vid-1', code: '000000');
      expect(r.success, isFalse);
      expect(r.message, 'Wrong code. Try again.');
      verifyNever(
        () => api.post<Map<String, dynamic>>(
          '/api/auth/firebase',
          data: any(named: 'data'),
        ),
      );
      verifyNever(() => storage.saveToken(any()));
    });

    test('backend errors surface as messages', () async {
      when(
        () => api.post<Map<String, dynamic>>(
          '/api/auth/firebase',
          data: any(named: 'data'),
        ),
      ).thenThrow(const ApiException('No internet connection.'));
      final r = await svc.verifyCode(verificationId: 'vid-1', code: '123456');
      expect(r.success, isFalse);
      expect(r.message, 'No internet connection.');
      verifyNever(() => storage.saveToken(any()));
    });

    test('missing token in a 200 response is a failure', () async {
      when(
        () => api.post<Map<String, dynamic>>(
          '/api/auth/firebase',
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => _json({'message': 'Denied'}));
      final r = await svc.verifyCode(verificationId: 'vid-1', code: '123456');
      expect(r.success, isFalse);
      expect(r.message, 'Denied');
      verifyNever(() => storage.saveToken(any()));
    });
  });

  test('isAvailable delegates to the driver', () {
    expect(svc.isAvailable, isTrue);
    driver.available = false;
    expect(svc.isAvailable, isFalse);
  });
}
