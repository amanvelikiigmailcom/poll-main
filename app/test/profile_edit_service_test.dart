import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/profile_edit_service.dart';
import 'fakes/social_storage.dart';

void main() {
  test('editor requests preserve opening credential and reject stale success', () async {
    final storage = SessionStorage();
    final api = ApiService(storage);
    final started = Completer<void>();
    final release = Completer<void>();
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) async {
      expect(request.headers['Authorization'], 'Bearer first-account');
      expect(request.path, '/api/profile-edit');
      started.complete();
      await release.future;
      handler.resolve(Response(requestOptions: request, data: {'firstName': 'Old owner'}));
    }));
    final service = ProfileEditService(api, storage);
    final pending = service.request('first-account');
    final assertion = expectLater(pending, throwsA(isA<ApiException>().having(
      (error) => error.message, 'message', contains('Account changed'),
    )));
    await started.future;
    storage.token = 'second-account';
    release.complete();
    await assertion;
    expect(await storage.getToken(), 'second-account');
  });

  test('stale 401 cannot clear a different account or return old account errors', () async {
    final storage = SessionStorage();
    final api = ApiService(storage);
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      storage.token = 'second-account';
      handler.reject(DioException(
        requestOptions: request, type: DioExceptionType.badResponse,
        response: Response(requestOptions: request, statusCode: 401, data: {'message': 'Old private error'}),
      ));
    }));
    await expectLater(ProfileEditService(api, storage).request('first-account'),
      throwsA(isA<ApiException>().having((error) => error.message, 'message', contains('Account changed'))));
    expect(await storage.getToken(), 'second-account');
  });

  test('changed session before request prevents any network write', () async {
    final storage = SessionStorage()..token = 'second-account';
    final api = ApiService(storage);
    var writes = 0;
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      writes++;
      handler.resolve(Response(requestOptions: request, data: <String, dynamic>{}));
    }));
    await expectLater(ProfileEditService(api, storage).request(
      'first-account', method: 'PUT', data: {'changes': {'firstName': 'Alice'}},
    ), throwsA(isA<ApiException>()));
    expect(writes, 0);
  });
}
