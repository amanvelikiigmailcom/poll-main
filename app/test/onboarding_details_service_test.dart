import 'fakes/reviewer_storage.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/content_service.dart';
import 'package:flyprox_app/services/onboarding_details_service.dart';
import 'package:flyprox_app/services/storage_service.dart';
import 'fakes/fake_secure_storage.dart';

void main() {
  setUp(() {
    useFakeSecureStorage();
    SharedPreferences.setMockInitialValues({});
    ContentService.instance.debugClear();
  });
  tearDown(() => ContentService.instance.debugClear());
  Future<(StorageService, ApiService, OnboardingDetailsService)> setup({
    bool reviewer = false,
  }) async {
    final storage = reviewer ? ReviewerStorageService() : StorageService();
    await storage.init();
    final api = ApiService(storage);
    final service = OnboardingDetailsService(api, storage);
    addTearDown(service.dispose);
    return (storage, api, service);
  }

  test(
    'guest profile, school and graduation year survive restart; skipped and requested schools do not unlock play',
    () async {
      final (storage, api, service) = await setup(reviewer: true);
      await service.setCountry('GB');
      await service.draft({'stage': 'profile'});
      await service.saveProfile('  Aman ', 'Smith', 'nonbinary');
      expect((await service.read())['firstName'], 'Aman');
      expect(await service.votingAllowed(), isFalse);
      await service.skipSchool();
      await service.finish();
      expect(await service.votingAllowed(), isFalse);
      final restored = OnboardingDetailsService(api, storage);
      addTearDown(restored.dispose);
      expect((await restored.read())['stage'], 'done');
      expect(await restored.country(), 'GB');
      await restored.requestSchool(
        name: 'Missing',
        city: 'London',
        region: 'London',
        year: 2030,
      );
      expect((await restored.read())['status'], 'requested');
      expect(await restored.votingAllowed(), isFalse);
      await restored.selectSchool({
        'id': 'GB-GIAS-1',
        'name': 'Real',
        'country': 'GB',
        'city': 'London',
        'region': 'London',
      }, 2030);
      expect(await restored.votingAllowed(), isTrue);
      expect((await restored.read())['graduationYear'], 2030);
    },
  );
  test(
    'server-disabled skip is rejected locally without advancing the stage',
    () async {
      final (_, _, service) = await setup();
      await service.saveProfile('Aman', 'Smith', 'male');
      ContentService.instance.debugSetOverrides({
        'school_skip_enabled': 'false',
      });
      await expectLater(service.skipSchool(), throwsA(isA<ApiException>()));
      expect((await service.read())['stage'], 'school');
    },
  );
  test(
    'late server save after account switch cannot write another account or discard its draft',
    () async {
      final (storage, api, service) = await setup();
      await storage.savePhone('+16505550001');
      await storage.saveToken('owner');
      final pending = Completer<Response<Map<String, dynamic>>>();
      final entered = Completer<void>();
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) async {
            entered.complete();
            handler.resolve(await pending.future);
          },
        ),
      );
      await service.draft({'stage': 'profile', 'firstName': 'Owner'});
      final save = service.saveProfile('Owner', 'Smith', 'male');
      final checked = expectLater(save, throwsA(isA<ApiException>()));
      await entered.future;
      await storage.savePhone('+16505550002');
      await storage.saveToken('other');
      await service.draft({'stage': 'profile', 'firstName': 'Other'});
      pending.complete(
        Response(
          requestOptions: RequestOptions(path: '/api/onboarding'),
          data: {'status': 'pending'},
        ),
      );
      await checked;
      expect((await service.read())['firstName'], 'Other');
      expect((await service.read())['stage'], 'profile');
    },
  );
  test(
    'server errors keep drafts and do not move to the school step',
    () async {
      final (storage, api, service) = await setup();
      await storage.saveToken('owner');
      await storage.savePhone('+16505550001');
      await service.draft({'stage': 'profile'});
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) => handler.reject(
            DioException(
              requestOptions: request,
              type: DioExceptionType.badResponse,
              response: Response(
                requestOptions: request,
                statusCode: 503,
                data: {'message': 'Offline'},
              ),
            ),
          ),
        ),
      );
      await expectLater(
        service.saveProfile('Aman', 'Smith', 'female'),
        throwsA(isA<ApiException>()),
      );
      expect((await service.read())['firstName'], 'Aman');
      expect((await service.read())['stage'], 'profile');
    },
  );
  test(
    'school email includes safely encoded school, country, city, region and graduation year only',
    () {
      final uri = OnboardingDetailsService.schoolEmail(
        email: 'support@flyprox.com',
        name: 'A & B School',
        country: 'GB',
        city: 'London',
        region: 'Greater London',
        year: '2030',
      );
      expect(uri.scheme, 'mailto');
      expect(uri.path, 'support@flyprox.com');
      final body = uri.queryParameters['body']!;
      for (final text in [
        'A & B School',
        'Country: GB',
        'City: London',
        'State / region: Greater London',
        'Graduation year: 2030',
      ]) {
        expect(body, contains(text));
      }
      expect(uri.queryParameters.keys, unorderedEquals(['subject', 'body']));
    },
  );
  test(
    'a new sign-in restores server school details by account without sharing the previous session draft',
    () async {
      final (storage, api, service) = await setup();
      await storage.saveToken('old-session');
      await storage.savePhone('+16505550001');
      await service.draft({
        'stage': 'profile',
        'firstName': 'Unsaved old draft',
      });
      await storage.saveToken('new-session');
      expect(await service.read(), isEmpty);
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) => handler.resolve(
            Response(
              requestOptions: request,
              data: {
                'country': 'GB',
                'status': 'selected',
                'school': {
                  'id': 'GB-GIAS-1',
                  'name': 'Real',
                  'city': 'London',
                  'region': 'London',
                  'country': 'GB',
                },
                'graduationYear': 2030,
                'firstName': 'Aman',
                'lastName': 'Smith',
                'gender': 'nonbinary',
                'profileComplete': true,
                'votingAllowed': true,
              },
            ),
          ),
        ),
      );
      await service.restore();
      final data = await service.read();
      expect(data['school']['id'], 'GB-GIAS-1');
      expect(data['firstName'], 'Aman');
      expect(data['stage'], 'school');
      expect(await service.votingAllowed(), isTrue);
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys().where(
        (k) => k.startsWith('onboarding_details_v1_'),
      )) {
        expect(key, isNot(contains('session')));
        expect(key, isNot(contains('+1650')));
      }
    },
  );
  test(
    'reviewer server restore removes stale form stages without writing dummy data; normal session stays gated',
    () async {
      final (storage, api, service) = await setup();
      await storage.saveToken('reviewer-session');
      await storage.saveReviewerAccess(true);
      await service.draft({'stage': 'school', 'status': 'pending'});
      final writes = <RequestOptions>[];
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            if (request.method != 'GET') writes.add(request);
            handler.resolve(
              Response(
                requestOptions: request,
                data: {
                  'status': 'pending',
                  'country': 'US',
                  'profileComplete': false,
                  'school': null,
                  'reviewerSkipsAllowed': storage.reviewerSkipsAllowed,
                  'votingAllowed': storage.reviewerSkipsAllowed,
                },
              ),
            );
          },
        ),
      );
      await service.prepareReviewer();
      expect((await service.read())['stage'], 'contacts');
      expect(await service.votingAllowed(), isTrue);
      expect(writes, isEmpty);
      await storage.saveToken('ordinary-session');
      expect(storage.reviewerSkipsAllowed, isFalse);
      expect(await service.read(), isEmpty);
      await service.restore(requireOnline: true);
      expect((await service.read())['stage'], 'profile');
      expect(await service.votingAllowed(), isFalse);
    },
  );

  test(
    'late reviewer onboarding restore cannot grant permissions to a different account',
    () async {
      final (storage, api, service) = await setup();
      await storage.saveToken('reviewer-session');
      await storage.saveReviewerAccess(true);
      final entered = Completer<void>();
      final pending = Completer<Map<String, dynamic>>();
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) async {
            entered.complete();
            handler.resolve(
              Response(requestOptions: request, data: await pending.future),
            );
          },
        ),
      );
      final restoring = service.restore(requireOnline: true);
      await entered.future;
      await storage.saveToken('ordinary-session');
      pending.complete({
        'status': 'pending',
        'reviewerSkipsAllowed': true,
        'votingAllowed': true,
      });
      expect(await restoring, isFalse);
      expect(storage.reviewerSkipsAllowed, isFalse);
      expect(await service.read(), isEmpty);
    },
  );
}
