import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/premium_service.dart';
import 'fakes/social_storage.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => respond(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody response(int code, Map<String, dynamic> data) =>
    ResponseBody.fromString(
      jsonEncode(data),
      code,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
Map<String, dynamic> status() => {
  'userId': 'owner',
  'active': true,
  'remaining': {'full': 2, 'initial': 5},
};

void main() {
  test(
    'reveal pins session, sends only kind and uses server counters',
    () async {
      final storage = SessionStorage();
      final api = ApiService(storage);
      api.dio.httpClientAdapter = _Adapter((request) async {
        expect(request.headers['Authorization'], 'Bearer first-account');
        expect(request.path, '/api/premium/votes/v1/reveal');
        expect(request.method, 'POST');
        expect(request.data, {'kind': 'initial'});
        return response(200, {
          ...status(),
          'initial': 'M',
          'revealed': 'initial',
          'graduationYear': 2028,
          'remaining': {'full': 2, 'initial': 4},
        });
      });
      final result = await PremiumService(api, storage).reveal('v1', 'initial');
      expect(result['initial'], 'M');
      expect((result['remaining'] as Map)['initial'], 4);
      expect(result['graduationYear'], 2028);
    },
  );
  for (final code in [200, 401]) {
    test(
      'stale $code after account A→out→A is rejected, not applied to new sign-in',
      () async {
        final storage = SessionStorage(),
            started = Completer<void>(),
            release = Completer<void>();
        final api = ApiService(storage);
        api.dio.httpClientAdapter = _Adapter((request) async {
          started.complete();
          await release.future;
          return response(
            code,
            code == 200 ? status() : {'message': 'Unauthorized'},
          );
        });
        final pending = PremiumService(api, storage).status();
        final assertion = expectLater(
          pending,
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 409),
          ),
        );
        await started.future;
        await storage.clearToken();
        storage.token = 'first-account';
        release.complete();
        await assertion;
        expect(storage.token, 'first-account');
      },
    );
  }
  test(
    'server failures and incomplete counters do not fabricate access or zero balances',
    () async {
      final storage = SessionStorage(), api = ApiService(SessionStorage());
      api.dio.httpClientAdapter = _Adapter(
        (_) async => response(503, {'message': 'Billing unavailable'}),
      );
      final service = PremiumService(api, storage);
      await expectLater(
        service.status(),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 503)),
      );
      api.dio.httpClientAdapter = _Adapter(
        (_) async => response(200, {'active': true}),
      );
      await expectLater(service.status(), throwsFormatException);
    },
  );
  test(
    'protected GET and POST keep counters and discard mixed identity fields',
    () async {
      final storage = SessionStorage();
      final api = ApiService(storage);
      api.dio.httpClientAdapter = _Adapter(
        (_) async => response(200, {
          ...status(),
          'status': 'PROTECTED_BY_PREMIUM',
          'message': 'This user also has Premium. Your reveal was not used.',
          'revealed': 'full',
          'name': 'Must not render',
          'initial': 'M',
          'voterId': 'private',
          'gender': 'female',
          'graduationYear': 2028,
        }),
      );
      final service = PremiumService(api, storage);
      for (final result in [
        await service.vote('v1'),
        await service.reveal('v1', 'full'),
      ]) {
        expect(result['status'], 'PROTECTED_BY_PREMIUM');
        expect(result['remaining'], {'full': 2, 'initial': 5});
        expect(result['revealed'], isNull);
        for (final key in [
          'name',
          'initial',
          'voterId',
          'gender',
          'graduationYear',
        ]) {
          expect(result.containsKey(key), isFalse, reason: key);
        }
      }
    },
  );
  test('guest never calls network or uses an SDK override', () async {
    final storage = SessionStorage()..token = null;
    final api = ApiService(storage);
    api.dio.httpClientAdapter = _Adapter(
      (_) async => throw StateError('Unexpected HTTP'),
    );
    await expectLater(
      PremiumService(api, storage).status(),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
    );
  });
}
