import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/push_service.dart';
import 'fakes/fake_push_driver.dart';

class MockApiService extends Mock implements ApiService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockApiService api;
  late FakePushDriver driver;
  late PushService svc;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = MockApiService();
    driver = FakePushDriver();
    addTearDown(driver.dispose);
    svc = PushService(driver: driver, api: api);
    when(() => api.post<void>('/api/devices', data: any(named: 'data')))
        .thenAnswer((_) async => Response<void>(
            requestOptions: RequestOptions(path: '/api/devices')));
  });

  group('needsPrompt', () {
    test('true on first run when available and not authorized', () async {
      expect(await svc.needsPrompt(), isTrue);
    });

    test('false when already authorized', () async {
      driver.authorized = true;
      expect(await svc.needsPrompt(), isFalse);
    });

    test('false when unavailable', () async {
      driver.available = false;
      expect(await svc.needsPrompt(), isFalse);
    });
  });

  group('enable', () {
    test('granted uploads the token and marks seen', () async {
      expect(await svc.enable(), isTrue);
      expect(await svc.needsPrompt(), isFalse);
      final captured =
          verify(() => api.post<void>('/api/devices',
              data: captureAny(named: 'data'))).captured.single
              as Map<String, dynamic>;
      expect(captured, {'token': 'apns-token-1', 'platform': 'ios'});
    });

    test('denied uploads nothing but still marks seen', () async {
      driver.grantOnRequest = false;
      expect(await svc.enable(), isFalse);
      expect(await svc.needsPrompt(), isFalse);
      verifyNever(() => api.post<void>('/api/devices',
          data: any(named: 'data')));
    });
  });

  group('syncToken', () {
    test('skips silently without a token', () async {
      driver.authorized = true;
      driver.token = null;
      expect(await svc.syncToken(), isFalse);
      verifyNever(() => api.post<void>('/api/devices',
          data: any(named: 'data')));
    });

    test('network errors yield false without throwing', () async {
      driver.authorized = true;
      when(() => api.post<void>('/api/devices', data: any(named: 'data')))
          .thenThrow(const ApiException('No internet connection.'));
      expect(await svc.syncToken(), isFalse);
    });

    test('token refresh re-uploads', () async {
      driver.authorized = true;
      final sub = svc.startTokenRefreshSync();
      addTearDown(sub.cancel);
      driver.tokenRefresh.add('new-token');
      await Future<void>.delayed(Duration.zero);
      verify(() => api.post<void>('/api/devices',
          data: any(named: 'data'))).called(1);
    });
  });
}
