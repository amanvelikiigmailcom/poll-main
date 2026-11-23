import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/services/storage_service.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/notification_preferences_service.dart';
import 'fakes/fake_secure_storage.dart';

void main() {
  setUp(() {
    useFakeSecureStorage();
    SharedPreferences.setMockInitialValues({});
  });
  Future<(StorageService, ApiService)> setup() async {
    final storage = StorageService();
    await storage.init();
    await storage.saveToken('owner');
    return (storage, ApiService(storage));
  }

  Map<String, bool> preferences() => {
    for (final key in notificationCategories.keys) key: true,
  };
  test(
    'loads and persists real server preferences without changing other account state',
    () async {
      final (storage, api) = await setup();
      var saved = preferences();
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (req, h) {
            expect(req.headers['Authorization'], 'Bearer owner');
            if (req.method == 'PUT') {
              saved = Map<String, bool>.from(req.data['preferences'] as Map);
            }
            h.resolve(
              Response(requestOptions: req, data: {'preferences': saved}),
            );
          },
        ),
      );
      final service = NotificationPreferencesService(
        api,
        storage,
        timezone: () async => 'Europe/London',
      );
      addTearDown(service.dispose);
      expect((await service.load())['votes'], true);
      await service.save({...saved, 'votes': false});
      expect(service.preferences!['votes'], false);
      expect(saved['friends'], true);
    },
  );
  test(
    'late success after switching accounts cannot restore old preferences or claim a review for the new account',
    () async {
      final (storage, api) = await setup();
      final entered = Completer<void>();
      RequestInterceptorHandler? handler;
      RequestOptions? request;
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (r, h) {
            request = r;
            handler = h;
            entered.complete();
          },
        ),
      );
      final service = NotificationPreferencesService(api, storage);
      addTearDown(service.dispose);
      final load = service.load();
      final checked = expectLater(load, throwsA(isA<ApiException>()));
      await entered.future;
      await storage.saveToken('other');
      handler!.resolve(
        Response(
          requestOptions: request!,
          data: {'preferences': preferences()},
        ),
      );
      await checked;
      expect(service.preferences, isNull);
    },
  );
  test(
    'a settings network failure preserves the last confirmed preferences instead of reporting a save',
    () async {
      final (storage, api) = await setup();
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (r, h) {
            if (r.method == 'PUT') {
              h.reject(
                DioException(
                  requestOptions: r,
                  type: DioExceptionType.badResponse,
                  response: Response(
                    requestOptions: r,
                    statusCode: 503,
                    data: {'message': 'Unavailable'},
                  ),
                ),
              );
            } else {
              h.resolve(
                Response(
                  requestOptions: r,
                  data: {'preferences': preferences()},
                ),
              );
            }
          },
        ),
      );
      final service = NotificationPreferencesService(
        api,
        storage,
        timezone: () async => 'UTC',
      );
      addTearDown(service.dispose);
      await service.load();
      await expectLater(
        service.save({...preferences(), 'votes': false}),
        throwsA(isA<ApiException>()),
      );
      expect(service.preferences!['votes'], true);
    },
  );
  test(
    'foreground activity and the server one-time claim request the native review only once, including concurrent resumes',
    () async {
      final (storage, api) = await setup();
      var claimed = false, prompts = 0, activity = 0;
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (r, h) {
            if (r.path.endsWith('/activity')) {
              activity++;
              expect(r.data['timezone'], 'UTC');
              h.resolve(Response(requestOptions: r, data: <String, dynamic>{}));
            } else {
              final allowed = !claimed;
              claimed = true;
              h.resolve(
                Response(requestOptions: r, data: {'requestReview': allowed}),
              );
            }
          },
        ),
      );
      final service = NotificationPreferencesService(
        api,
        storage,
        timezone: () async => 'UTC',
        requestReview: () async {
          prompts++;
        },
      );
      addTearDown(service.dispose);
      await Future.wait([
        service.recordActivityAndReview(),
        service.recordActivityAndReview(),
      ]);
      await service.recordActivityAndReview();
      expect(prompts, 1);
      expect(activity, 2);
    },
  );
  test(
    'signed-out users neither register activity nor attempt a review',
    () async {
      final (storage, api) = await setup();
      await storage.clearToken();
      var calls = 0;
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (r, h) {
            calls++;
            h.resolve(Response(requestOptions: r, data: <String, dynamic>{}));
          },
        ),
      );
      final service = NotificationPreferencesService(
        api,
        storage,
        requestReview: () async {
          throw StateError('must not prompt');
        },
      );
      addTearDown(service.dispose);
      await service.recordActivityAndReview();
      expect(calls, 0);
    },
  );
  test(
    'installation identifier is random, stable across service lifetimes, and contains no phone or push token',
    () async {
      final (storage, _) = await setup();
      await storage.savePhone('+16505550001');
      final id = await storage.notificationInstallationId();
      expect(id, matches(RegExp(r'^[a-f0-9]{32}$')));
      final next = StorageService();
      await next.init();
      expect(await next.notificationInstallationId(), id);
      expect(id, isNot(contains('1650555')));
    },
  );
}
