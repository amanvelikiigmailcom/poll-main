import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flyprox_app/providers/auth_provider.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/auth_service.dart';
import 'package:flyprox_app/services/phone_auth_service.dart';
import 'package:flyprox_app/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/fake_phone_auth_driver.dart';
import 'fakes/fake_secure_storage.dart';
import 'fakes/http_adapter.dart';

ResponseBody jsonBody(Map<String, dynamic> data, [int status = 200]) =>
    ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

class DelayedInstallationStorage extends StorageService {
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<String> notificationInstallationId() async {
    started.complete();
    await release.future;
    return 'test-installation';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageService storage;
  late ApiService api;
  late AuthService auth;
  late PhoneAuthService phone;
  late TestHttpAdapter adapter;

  setUp(() async {
    useFakeSecureStorage();
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
    api = ApiService(storage);
    auth = AuthService(api, storage);
    phone = PhoneAuthService(
      api: api,
      storage: storage,
      driver: FakePhoneAuthDriver(),
    );
  });
  tearDown(() {
    api.dio.close(force: true);
    storage.dispose();
  });

  test(
    'logout cancels a pending login even when both start as guest',
    () async {
      final started = Completer<void>();
      final reply = Completer<ResponseBody>();
      adapter = TestHttpAdapter((_) {
        started.complete();
        return reply.future;
      });
      api.dio.httpClientAdapter = adapter;
      final pending = phone.loginWithIdToken(
        'firebase-A',
        phone: '+16505550001',
      );
      await started.future;
      await auth.logout();
      reply.complete(
        jsonBody({'token': 'session-A', 'reviewerSkipsAllowed': true}),
      );
      expect((await pending).success, isFalse);
      expect(await storage.getToken(), isNull);
      expect(storage.getPhone(), isNull);
      expect(storage.reviewerSkipsAllowed, isFalse);
      expect(adapter.requests, hasLength(1));
    },
  );

  test('logout during request preparation prevents any backend call', () async {
    final delayed = DelayedInstallationStorage();
    await delayed.init();
    addTearDown(delayed.dispose);
    final delayedApi = ApiService(delayed);
    addTearDown(() => delayedApi.dio.close(force: true));
    final delayedAdapter = TestHttpAdapter(
      (_) async => jsonBody({'token': 'cancelled-session'}),
    );
    delayedApi.dio.httpClientAdapter = delayedAdapter;
    final service = PhoneAuthService(
      api: delayedApi,
      storage: delayed,
      driver: FakePhoneAuthDriver(),
    );
    final login = service.loginWithIdToken('firebase-A');
    await delayed.started.future;
    await AuthService(delayedApi, delayed).logout();
    delayed.release.complete();
    expect((await login).success, isFalse);
    expect(delayedAdapter.requests, isEmpty);
    expect(await delayed.getToken(), isNull);
  });

  test('newer login wins when responses arrive in reverse order', () async {
    final requests = <Completer<ResponseBody>>[];
    final firstStarted = Completer<void>();
    final secondStarted = Completer<void>();
    api.dio.httpClientAdapter = TestHttpAdapter((_) {
      final reply = Completer<ResponseBody>();
      requests.add(reply);
      (requests.length == 1 ? firstStarted : secondStarted).complete();
      return reply.future;
    });
    final first = phone.loginWithIdToken('firebase-A', phone: '+16505550001');
    await firstStarted.future;
    final second = phone.loginWithIdToken('firebase-B', phone: '+16505550002');
    await secondStarted.future;
    requests[1].complete(jsonBody({'token': 'session-B'}));
    expect((await second).success, isTrue);
    requests[0].complete(
      jsonBody({'token': 'session-A', 'reviewerSkipsAllowed': true}),
    );
    expect((await first).success, isFalse);
    expect(await storage.getToken(), 'session-B');
    expect(storage.getPhone(), '+16505550002');
    expect(storage.reviewerSkipsAllowed, isFalse);
  });

  for (final status in [200, 401, 503]) {
    test('late logout response $status cannot clear a new login', () async {
      await storage.saveToken('session-A');
      await storage.savePhone('+16505550001');
      final started = Completer<void>();
      final reply = Completer<ResponseBody>();
      api.dio.httpClientAdapter = TestHttpAdapter((request) {
        expect(request.path, '/api/auth/logout');
        expect(request.headers['Authorization'], 'Bearer session-A');
        started.complete();
        return reply.future;
      });
      final pending = auth.logout();
      await started.future;
      expect(await storage.getToken(), isNull);
      expect(storage.getPhone(), isNull);
      await storage.saveToken('session-B');
      await storage.savePhone('+16505550002');
      reply.complete(jsonBody({}, status));
      await pending;
      expect(await storage.getToken(), 'session-B');
      expect(storage.getPhone(), '+16505550002');
    });
  }

  test('offline logout still clears only local credentials', () async {
    await storage.saveToken('session-A');
    await storage.savePhone('+16505550001');
    api.dio.httpClientAdapter = TestHttpAdapter((request) async {
      throw DioException(
        requestOptions: request,
        type: DioExceptionType.connectionError,
      );
    });
    await auth.logout();
    expect(await storage.getToken(), isNull);
    expect(storage.getPhone(), isNull);
    expect(storage.getUser(), isNull);
  });

  test(
    'legacy OTP and Firebase share cancellation of older attempts',
    () async {
      final started = Completer<void>();
      final oldReply = Completer<ResponseBody>();
      api.dio.httpClientAdapter = TestHttpAdapter((request) async {
        if (request.path.endsWith('verify-otp')) {
          started.complete();
          return oldReply.future;
        }
        return jsonBody({'token': 'session-B'});
      });
      final old = auth.verifyOtp('+16505550001', '123456');
      await started.future;
      expect((await phone.loginWithIdToken('firebase-B')).success, isTrue);
      oldReply.complete(jsonBody({'token': 'session-A'}));
      expect((await old).success, isFalse);
      expect(await storage.getToken(), 'session-B');
    },
  );

  test('late logout cannot overwrite the new authenticated UI state', () async {
    await storage.saveToken('session-A');
    final started = Completer<void>();
    final logoutReply = Completer<ResponseBody>();
    api.dio.httpClientAdapter = TestHttpAdapter((request) async {
      if (request.path.endsWith('/logout')) {
        started.complete();
        return logoutReply.future;
      }
      return jsonBody({'token': 'session-B'});
    });
    final notifier = AuthNotifier(auth, phoneAuth: phone);
    addTearDown(notifier.dispose);
    final logout = notifier.logout();
    await started.future;
    expect(
      (await notifier.verifyFirebaseCode(
        verificationId: 'verification-B',
        code: '123456',
      )).success,
      isTrue,
    );
    logoutReply.complete(jsonBody({}));
    await logout;
    expect(notifier.state.status, AuthStatus.authenticated);
    expect(await storage.getToken(), 'session-B');
  });

  test('cancelled login cannot authenticate the UI after logout', () async {
    final started = Completer<void>();
    final reply = Completer<ResponseBody>();
    api.dio.httpClientAdapter = TestHttpAdapter((_) {
      started.complete();
      return reply.future;
    });
    final notifier = AuthNotifier(auth, phoneAuth: phone);
    addTearDown(notifier.dispose);
    final login = notifier.verifyFirebaseCode(
      verificationId: 'verification-A',
      code: '123456',
    );
    await started.future;
    await notifier.logout();
    reply.complete(jsonBody({'token': 'session-A'}));
    expect((await login).success, isFalse);
    expect(notifier.state.status, AuthStatus.unauthenticated);
    expect(await storage.getToken(), isNull);
  });
}
