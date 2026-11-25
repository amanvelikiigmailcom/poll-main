import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/fake_secure_storage.dart';
import 'fakes/http_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageService storage;
  late ApiService api;
  late ProviderContainer container;
  setUp(() async {
    useFakeSecureStorage();
    SharedPreferences.setMockInitialValues({'local_star_balance': 9000});
    storage = StorageService();
    await storage.init();
    api = ApiService(storage);
    container = ProviderContainer(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
        apiServiceProvider.overrideWithValue(api),
      ],
    );
    container.listen(starBalanceProvider, (_, _) {});
  });
  tearDown(() {
    container.dispose();
    api.dio.close(force: true);
    storage.dispose();
  });

  test(
    'real provider isolates offline caches by hashed credential across logout',
    () async {
      var offline = false;
      final adapter = TestHttpAdapter((request) async {
        if (offline) {
          throw DioException(
            requestOptions: request,
            type: DioExceptionType.connectionError,
          );
        }
        expect(request.headers['Authorization'], 'Bearer session-A');
        return ResponseBody.fromString(
          '{"starsCount":1234}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });
      api.dio.httpClientAdapter = adapter;
      expect(await container.read(starBalanceProvider.future), 9000);
      expect(adapter.requests, isEmpty);
      await storage.saveToken('session-A');
      expect(await container.read(starBalanceProvider.future), 1234);
      final prefs = await SharedPreferences.getInstance();
      final cacheKey =
          'verified_stars_v1_${sha256.convert(utf8.encode('session-A'))}';
      expect(prefs.getInt(cacheKey), 1234);
      expect(prefs.getKeys().any((key) => key.contains('session-A')), isFalse);
      expect(
        prefs
            .getKeys()
            .map(prefs.get)
            .whereType<String>()
            .any((value) => value.contains('session-A')),
        isFalse,
      );
      offline = true;
      container.invalidate(starBalanceProvider);
      expect(await container.read(starBalanceProvider.future), 1234);
      await storage.saveToken('session-B');
      expect(await container.read(starBalanceProvider.future), isNull);
      await storage.clearSession();
      expect(await container.read(starBalanceProvider.future), 9000);
      expect(prefs.getInt('local_star_balance'), 9000);
      await storage.saveToken('session-A');
      expect(await container.read(starBalanceProvider.future), 1234);
    },
  );

  test(
    'late balance A cannot write cache or replace visible balance B',
    () async {
      final started = Completer<void>();
      final reply = Completer<ResponseBody>();
      api.dio.httpClientAdapter = TestHttpAdapter((request) {
        if (request.headers['Authorization'] == 'Bearer session-A') {
          started.complete();
          return reply.future;
        }
        return Future.value(
          ResponseBody.fromString(
            '{"starsCount":222}',
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          ),
        );
      });
      await storage.saveToken('session-A');
      final oldBalance = container.read(starBalanceProvider.future);
      await started.future;
      await storage.saveToken('session-B');
      expect(await container.read(starBalanceProvider.future), 222);
      reply.complete(
        ResponseBody.fromString(
          '{"starsCount":9999}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );
      await oldBalance;
      expect(await container.read(starBalanceProvider.future), 222);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getInt(
          'verified_stars_v1_${sha256.convert(utf8.encode('session-A'))}',
        ),
        isNull,
      );
    },
  );
}
