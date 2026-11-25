import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flyprox_app/services/api_service.dart';

import 'fakes/http_adapter.dart';
import 'fakes/social_storage.dart';

void main() {
  late SessionStorage storage;
  late ApiService api;
  late TestHttpAdapter adapter;

  setUp(() {
    storage = SessionStorage();
    api = ApiService(storage);
    adapter = TestHttpAdapter(
      (_) async => ResponseBody.fromString(
        '{}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
    api.dio.httpClientAdapter = adapter;
  });
  tearDown(() {
    api.dio.close(force: true);
    storage.dispose();
  });

  Future<void> request(String method, {Options? options}) async {
    switch (method) {
      case 'GET':
        await api.get<dynamic>('/test', options: options);
      case 'POST':
        await api.post<dynamic>('/test', data: {'value': 1}, options: options);
      case 'PUT':
        await api.put<dynamic>('/test', data: {'value': 1}, options: options);
      case 'PATCH':
        await api.patch<dynamic>('/test', data: {'value': 1}, options: options);
      case 'DELETE':
        await api.delete<dynamic>(
          '/test',
          data: {'value': 1},
          options: options,
        );
    }
  }

  for (final method in ['GET', 'POST', 'PUT', 'PATCH', 'DELETE']) {
    test(
      '$method sends the current Bearer and preserves the payload',
      () async {
        await request(method);
        final sent = adapter.requests.single;
        expect(sent.method, method);
        expect(sent.headers['Authorization'], 'Bearer first-account');
        if (method != 'GET') expect(sent.data, {'value': 1});
      },
    );

    test('$method maps 401 and clears only its own session', () async {
      api.dio.httpClientAdapter = TestHttpAdapter(
        (_) async => ResponseBody.fromString(
          '{"message":"Expired"}',
          401,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );
      await expectLater(
        request(method),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'status', 401)
              .having((e) => e.message, 'message', 'Expired'),
        ),
      );
      expect(await storage.getToken(), isNull);
    });
  }

  test('an explicitly pinned Bearer is not replaced', () async {
    await request(
      'GET',
      options: Options(headers: {'Authorization': 'Bearer pinned-account'}),
    );
    expect(
      adapter.requests.single.headers['Authorization'],
      'Bearer pinned-account',
    );
  });

  for (final token in <String?>[null, '']) {
    test('missing/empty credential never sends a Bearer ($token)', () async {
      storage.token = token;
      await request('GET');
      expect(
        adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });
  }

  test('late 401 from A cannot clear B', () async {
    final started = Completer<void>();
    final release = Completer<ResponseBody>();
    api.dio.httpClientAdapter = TestHttpAdapter((_) {
      started.complete();
      return release.future;
    });
    final pending = request('GET');
    final assertion = expectLater(pending, throwsA(isA<ApiException>()));
    await started.future;
    storage.token = 'account-B';
    release.complete(ResponseBody.fromString('{}', 401));
    await assertion;
    expect(await storage.getToken(), 'account-B');
  });

  test(
    'callerHandlesUnauthorized leaves current credential to caller',
    () async {
      api.dio.httpClientAdapter = TestHttpAdapter(
        (_) async => ResponseBody.fromString('{}', 401),
      );
      await expectLater(
        request(
          'GET',
          options: Options(extra: {'callerHandlesUnauthorized': true}),
        ),
        throwsA(isA<ApiException>()),
      );
      expect(await storage.getToken(), 'first-account');
    },
  );

  for (final type in [
    DioExceptionType.connectionTimeout,
    DioExceptionType.sendTimeout,
    DioExceptionType.receiveTimeout,
    DioExceptionType.connectionError,
    DioExceptionType.cancel,
  ]) {
    test('$type is an ApiException and does not log out', () async {
      api.dio.httpClientAdapter = TestHttpAdapter((options) async {
        throw DioException(requestOptions: options, type: type);
      });
      await expectLater(
        request('GET'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            type == DioExceptionType.connectionError
                ? contains('No internet')
                : type == DioExceptionType.cancel
                ? contains('cancelled')
                : contains('timed out'),
          ),
        ),
      );
      expect(await storage.getToken(), 'first-account');
    });
  }

  for (final body in [
    {'message': 'Taken', 'error': 'fallback'},
    {'error': 'Taken'},
    {
      'message': 123,
      'error': ['unexpected'],
    },
    ['unexpected'],
    'unavailable',
  ]) {
    test('HTTP error safely maps body ${jsonEncode(body)}', () async {
      api.dio.httpClientAdapter = TestHttpAdapter(
        (_) async => ResponseBody.fromString(
          jsonEncode(body),
          409,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );
      await expectLater(
        request('PATCH'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'status', 409)
              .having(
                (e) => e.message,
                'message',
                body is Map && body.values.contains('Taken')
                    ? 'Taken'
                    : 'An error occurred. Please try again.',
              ),
        ),
      );
    });
  }
}
