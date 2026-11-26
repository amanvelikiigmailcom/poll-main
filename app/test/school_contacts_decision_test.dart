import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/local_game_service.dart';
import 'package:flyprox_app/services/onboarding_details_service.dart';
import 'package:flyprox_app/services/storage_service.dart';
import 'fakes/fake_secure_storage.dart';

const _school = {'id': 'US-1', 'name': 'Central High', 'country': 'US'};

Map<String, dynamic> _state({bool ready = false}) => {
  'status': 'selected',
  'school': _school,
  'country': 'US',
  'graduationYear': 2030,
  'profileComplete': true,
  'reviewerSkipsAllowed': false,
  'votingAllowed': true,
  'contactsRequirement': {
    'required': !ready,
    'mode': ready ? 'school' : 'contacts',
    'joined': ready ? 5 : 4,
    'threshold': 5,
  },
};

void main() {
  setUp(() {
    useFakeSecureStorage();
    SharedPreferences.setMockInitialValues({});
  });

  Future<(StorageService, ApiService, OnboardingDetailsService)> setup() async {
    final storage = StorageService();
    await storage.init();
    await storage.saveToken('owner');
    final api = ApiService(storage);
    final service = OnboardingDetailsService(api, storage);
    addTearDown(service.dispose);
    await service.draft({'stage': 'school', 'status': 'pending'});
    return (storage, api, service);
  }

  for (final ready in [false, true]) {
    test(
      'save and restored registration use server contacts decision: school=$ready',
      () async {
        final (storage, api, service) = await setup();
        final requests = <RequestOptions>[];
        api.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (req, h) {
              requests.add(req);
              h.resolve(
                Response(
                  requestOptions: req,
                  data: _state(ready: ready),
                ),
              );
            },
          ),
        );
        await service.selectSchool(_school, 2030);
        expect(
          (await service.read())['stage'],
          ready ? 'username' : 'contacts',
        );
        expect((await service.contactsDecision()).school, ready);
        expect(
          requests.length,
          1,
          reason: 'reuse save result, without a mode GET',
        );
        final restarted = OnboardingDetailsService(api, storage);
        addTearDown(restarted.dispose);
        expect((await restarted.contactsDecision()).school, ready);
        expect(
          (await restarted.read())['stage'],
          ready ? 'username' : 'contacts',
        );
        expect(requests.map((r) => r.path), everyElement('/api/onboarding'));
        expect(requests.map((r) => r.method), ['PUT', 'GET']);
      },
    );
  }

  test(
    'fresh restore overrides stale contacts stage with school mode',
    () async {
      final (_, api, service) = await setup();
      await service.draft({
        'stage': 'contacts',
        'contactsRequirement': _state()['contactsRequirement'],
      });
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (req, h) {
            h.resolve(Response(requestOptions: req, data: _state(ready: true)));
          },
        ),
      );
      expect(await service.restore(requireOnline: true), isTrue);
      expect((await service.read())['stage'], 'username');
    },
  );

  test('completed registration is not reset when population drops', () async {
    final (_, api, service) = await setup();
    await service.draft({'stage': 'done'});
    api.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (req, h) {
          h.resolve(Response(requestOptions: req, data: _state()));
        },
      ),
    );
    await service.restore(requireOnline: true);
    expect((await service.read())['stage'], 'done');
  });

  test(
    'saved contacts permit resuming username even below threshold',
    () async {
      final (_, api, service) = await setup();
      await LocalGameService.instance.savePlayerAndFriends(
        playerName: 'player',
        friends: ['Alex', 'Sam', 'Jordan', 'Taylor'],
      );
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (req, h) {
            h.resolve(Response(requestOptions: req, data: _state()));
          },
        ),
      );
      await service.restore(requireOnline: true);
      expect((await service.read())['stage'], 'username');
    },
  );

  for (final invalid in [
    null,
    {'required': false, 'mode': 'contacts', 'joined': 4, 'threshold': 5},
    {'required': false, 'mode': 'school', 'joined': 4, 'threshold': 5},
  ]) {
    test(
      'missing or invalid decision cannot silently open contacts: $invalid',
      () async {
        final (_, api, service) = await setup();
        api.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (req, h) {
              h.resolve(
                Response(
                  requestOptions: req,
                  data: {..._state(), 'contactsRequirement': invalid},
                ),
              );
            },
          ),
        );
        await expectLater(
          service.selectSchool(_school, 2030),
          throwsA(isA<ApiException>()),
        );
        expect((await service.read())['stage'], 'school');
        await expectLater(
          service.restore(requireOnline: true),
          throwsA(isA<ApiException>()),
        );
        expect((await service.read())['stage'], 'school');
      },
    );
  }

  test(
    'timeout keeps school stage and retry consumes the confirmed save response',
    () async {
      final (_, api, service) = await setup();
      var fail = true;
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (req, h) {
            if (fail) {
              h.reject(
                DioException(
                  requestOptions: req,
                  type: DioExceptionType.receiveTimeout,
                ),
              );
            } else {
              h.resolve(
                Response(requestOptions: req, data: _state(ready: true)),
              );
            }
          },
        ),
      );
      await expectLater(
        service.selectSchool(_school, 2030),
        throwsA(isA<ApiException>()),
      );
      expect((await service.read())['stage'], 'school');
      fail = false;
      await service.selectSchool(_school, 2030);
      expect((await service.read())['stage'], 'username');
    },
  );

  test(
    'waiting response takes priority without a population decision',
    () async {
      final (_, api, service) = await setup();
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (req, h) {
            h.resolve(
              Response(
                requestOptions: req,
                data: {
                  'status': 'waiting',
                  'school': _school,
                  'votingAllowed': false,
                },
              ),
            );
          },
        ),
      );
      await service.selectSchool(_school, 2030);
      expect((await service.read())['stage'], 'waiting');
      expect(await service.votingAllowed(), isFalse);
    },
  );

  for (final restoring in [false, true]) {
    test(
      'late ${restoring ? 'restore' : 'school save'} cannot change another account',
      () async {
        final (storage, api, service) = await setup();
        final entered = Completer<void>();
        final response = Completer<Map<String, dynamic>>();
        api.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (req, h) async {
              entered.complete();
              h.resolve(
                Response(requestOptions: req, data: await response.future),
              );
            },
          ),
        );
        final pending = restoring
            ? service.restore(requireOnline: true)
            : service.selectSchool(_school, 2030);
        final checked = restoring
            ? expectLater(pending, completion(isFalse))
            : expectLater(pending, throwsA(isA<ApiException>()));
        await entered.future;
        await storage.saveToken('other');
        await service.draft({'stage': 'profile', 'firstName': 'Other'});
        response.complete(_state(ready: true));
        await checked;
        expect((await service.read())['stage'], 'profile');
        expect((await service.read())['firstName'], 'Other');
      },
    );
  }
}
