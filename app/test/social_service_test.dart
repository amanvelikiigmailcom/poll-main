import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/social_service.dart';
import 'fakes/social_storage.dart';

// Exercise the actual Dio response/error chain, including auth interceptors.
class SocialHttpAdapter implements HttpClientAdapter {
  SocialHttpAdapter(this.respond);
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

ResponseBody jsonResponse(int status, Map<String, dynamic> data) =>
    ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
void main() {
  test('guest search never sends HTTP', () async {
    final storage = SessionStorage()..token = null;
    final api = ApiService(storage);
    var sent = false;
    api.dio.httpClientAdapter = SocialHttpAdapter((_) async {
      sent = true;
      return jsonResponse(200, {});
    });
    await expectLater(
      SocialService(api, storage).search('alex_123'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
    );
    expect(sent, isFalse);
  });
  test('late search response is rejected after account change', () async {
    final storage = SessionStorage();
    final api = ApiService(storage);
    final started = Completer<void>();
    final release = Completer<void>();
    api.dio.httpClientAdapter = SocialHttpAdapter((request) async {
      expect(request.headers['Authorization'], 'Bearer first-account');
      expect(request.uri.queryParameters['username'], '@alex_123');
      started.complete();
      await release.future;
      return jsonResponse(200, {
        'users': [
          {'id': 'private', 'username': 'alex_123'},
        ],
      });
    });
    final pending = SocialService(api, storage).search('@alex_123');
    final assertion = expectLater(
      pending,
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)),
    );
    await started.future;
    storage.token = 'second-account';
    release.complete();
    await assertion;
  });
  test('late 401 cannot log out the next account', () async {
    final storage = SessionStorage();
    final api = ApiService(storage);
    final started = Completer<void>();
    final release = Completer<void>();
    api.dio.httpClientAdapter = SocialHttpAdapter((request) async {
      started.complete();
      await release.future;
      return jsonResponse(401, {'message': 'Unauthorized'});
    });
    final pending = SocialService(api, storage).list('friends');
    final assertion = expectLater(pending, throwsA(isA<ApiException>()));
    await started.future;
    storage.token = 'second-account';
    release.complete();
    await assertion;
    expect(storage.token, 'second-account');
  });
  test(
    'unauthorized response for the current session clears that session',
    () async {
      final storage = SessionStorage();
      final api = ApiService(storage);
      api.dio.httpClientAdapter = SocialHttpAdapter(
        (_) async => jsonResponse(401, {'message': 'Unauthorized'}),
      );
      await expectLater(
        SocialService(api, storage).list('friends'),
        throwsA(isA<ApiException>()),
      );
      expect(storage.token, isNull);
    },
  );
  test('occupied handle preserves server error', () async {
    final storage = SessionStorage();
    final api = ApiService(storage);
    api.dio.httpClientAdapter = SocialHttpAdapter((request) async {
      expect(request.method, 'PUT');
      return jsonResponse(409, {
        'message': 'This username is taken. Choose another.',
      });
    });
    await expectLater(
      SocialService(api, storage).saveHandle('alex_123'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'status', 409)
            .having((e) => e.message, 'message', contains('taken')),
      ),
    );
  });
}
