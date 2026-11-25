import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/profile_edit_service.dart';
import 'fakes/social_storage.dart';
import 'fakes/http_adapter.dart';

void main() {
  test(
    'taken username preserves backend 409 and its actionable message',
    () async {
      final storage = SessionStorage();
      final api = ApiService(storage);
      addTearDown(storage.dispose);
      addTearDown(() => api.dio.close(force: true));
      api.dio.httpClientAdapter = TestHttpAdapter((request) async {
        expect(request.method, 'PUT');
        expect(request.headers['Authorization'], 'Bearer first-account');
        expect(request.data, {
          'changes': {'username': 'taken'},
        });
        return ResponseBody.fromString(
          '{"message":"This username is already taken."}',
          409,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });
      await expectLater(
        ProfileEditService(api, storage).request(
          'first-account',
          method: 'PUT',
          data: {
            'changes': {'username': 'taken'},
          },
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'status', 409)
              .having(
                (e) => e.message,
                'message',
                'This username is already taken.',
              ),
        ),
      );
      expect(await storage.getToken(), 'first-account');
    },
  );
  test(
    'editor requests preserve opening credential and reject stale success',
    () async {
      final storage = SessionStorage();
      final api = ApiService(storage);
      final started = Completer<void>();
      final release = Completer<void>();
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) async {
            expect(request.headers['Authorization'], 'Bearer first-account');
            expect(request.path, '/api/profile-edit');
            started.complete();
            await release.future;
            handler.resolve(
              Response(
                requestOptions: request,
                data: {'firstName': 'Old owner'},
              ),
            );
          },
        ),
      );
      final service = ProfileEditService(api, storage);
      final pending = service.request('first-account');
      final assertion = expectLater(
        pending,
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            contains('Account changed'),
          ),
        ),
      );
      await started.future;
      storage.token = 'second-account';
      release.complete();
      await assertion;
      expect(await storage.getToken(), 'second-account');
    },
  );

  test(
    'stale 401 cannot clear a different account or return old account errors',
    () async {
      final storage = SessionStorage();
      final api = ApiService(storage);
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            storage.token = 'second-account';
            handler.reject(
              DioException(
                requestOptions: request,
                type: DioExceptionType.badResponse,
                response: Response(
                  requestOptions: request,
                  statusCode: 401,
                  data: {'message': 'Old private error'},
                ),
              ),
            );
          },
        ),
      );
      await expectLater(
        ProfileEditService(api, storage).request('first-account'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            contains('Account changed'),
          ),
        ),
      );
      expect(await storage.getToken(), 'second-account');
    },
  );

  test('changed session before request prevents any network write', () async {
    final storage = SessionStorage()..token = 'second-account';
    final api = ApiService(storage);
    var writes = 0;
    api.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          writes++;
          handler.resolve(
            Response(requestOptions: request, data: <String, dynamic>{}),
          );
        },
      ),
    );
    await expectLater(
      ProfileEditService(api, storage).request(
        'first-account',
        method: 'PUT',
        data: {
          'changes': {'firstName': 'Alice'},
        },
      ),
      throwsA(isA<ApiException>()),
    );
    expect(writes, 0);
  });
}
