import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/quiz_preferences_service.dart';
import 'fakes/social_storage.dart';

Map<String, dynamic> quizPreferencesPayload([String value = 'all']) => {
  'genderFilter': value,
  'prioritizeGraduationYear': true,
  'appliesTo': 'next_round',
  'options': [
    {'value': 'all', 'label': 'Everyone'},
    {'value': 'female', 'label': 'Girls'},
    {'value': 'male', 'label': 'Boys'},
    {'value': 'nonbinary', 'label': 'Non-binary'},
  ],
};

void main() {
  test(
    'loads server options and saves exact payload under opening credential',
    () async {
      final storage = SessionStorage();
      final api = ApiService(storage);
      final calls = <RequestOptions>[];
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            calls.add(request);
            expect(request.path, '/api/quiz-preferences');
            expect(request.headers['Authorization'], 'Bearer first-account');
            handler.resolve(
              Response(
                requestOptions: request,
                data: quizPreferencesPayload(
                  request.method == 'PUT'
                      ? request.data['genderFilter'] as String
                      : 'all',
                ),
              ),
            );
          },
        ),
      );
      final service = QuizPreferencesService(api, storage);
      expect((await service.load('first-account')).genderFilter, 'all');
      expect(
        (await service.save('first-account', 'female')).genderFilter,
        'female',
      );
      expect(calls.map((call) => call.method), ['GET', 'PUT']);
      expect(calls.last.data, {'genderFilter': 'female'});
    },
  );

  test(
    'missing, corrupt and duplicate options cannot silently become Everyone',
    () {
      for (final body in [
        <String, dynamic>{},
        {...quizPreferencesPayload(), 'genderFilter': 'unexpected'},
        {
          ...quizPreferencesPayload(),
          'options': [
            for (var i = 0; i < 4; i++) {'value': 'all', 'label': 'Everyone'},
          ],
        },
      ]) {
        expect(
          () => QuizPreferencesData.fromJson(body),
          throwsA(isA<ApiException>()),
        );
      }
    },
  );

  test(
    'stale success is rejected and stale 401 cannot clear the next account',
    () async {
      for (final failure in [false, true]) {
        final storage = SessionStorage();
        final api = ApiService(storage);
        api.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              storage.token = 'second-account';
              if (failure) {
                handler.reject(
                  DioException(
                    requestOptions: request,
                    type: DioExceptionType.badResponse,
                    response: Response(
                      requestOptions: request,
                      statusCode: 401,
                      data: {'message': 'Private old error'},
                    ),
                  ),
                );
              } else {
                handler.resolve(
                  Response(
                    requestOptions: request,
                    data: quizPreferencesPayload(),
                  ),
                );
              }
            },
          ),
        );
        await expectLater(
          QuizPreferencesService(api, storage).load('first-account'),
          throwsA(
            isA<ApiException>().having(
              (e) => e.message,
              'message',
              contains('Account changed'),
            ),
          ),
        );
        expect(await storage.getToken(), 'second-account');
      }
    },
  );

  test('changed credential before save prevents network access', () async {
    final storage = SessionStorage()..token = 'second-account';
    final api = ApiService(storage);
    var calls = 0;
    api.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          calls++;
          handler.resolve(
            Response(requestOptions: request, data: quizPreferencesPayload()),
          );
        },
      ),
    );
    await expectLater(
      QuizPreferencesService(api, storage).save('first-account', 'female'),
      throwsA(isA<ApiException>()),
    );
    expect(calls, 0);
  });

  test(
    'a malformed server response is an explicit error, not a local default',
    () async {
      final storage = SessionStorage();
      final api = ApiService(storage);
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            handler.resolve(
              Response<dynamic>(requestOptions: request, data: ['invalid']),
            );
          },
        ),
      );
      await expectLater(
        QuizPreferencesService(api, storage).load('first-account'),
        throwsA(isA<ApiException>()),
      );
    },
  );
}
