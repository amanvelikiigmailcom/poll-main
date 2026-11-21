import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/contact_picker_service.dart';
import 'package:flyprox_app/services/contact_sync_service.dart';

class MockApiService extends Mock implements ApiService {}

Response<Map<String, dynamic>> _json(Map<String, dynamic> data) =>
    Response<Map<String, dynamic>>(
      requestOptions: RequestOptions(path: '/api/contacts'),
      data: data,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('hashPhone', () {
    test('matches the backend vector', () {
      // Backend: sha256("flyprox-contacts-v1:+77071234567").
      expect(
        ContactSyncService.hashPhone('+77071234567'),
        '6b61d1a17e6f760a1d861e6d389f75043e820fa0fc66610da480272fe27edb3b',
      );
    });

    test('trims and differs per number', () {
      expect(ContactSyncService.hashPhone('  +77071234567  '),
          ContactSyncService.hashPhone('+77071234567'));
      expect(ContactSyncService.hashPhone('+77071234567'),
          isNot(ContactSyncService.hashPhone('+77071234568')));
    });
  });

  group('normalizePhone', () {
    test('international formats pass through', () {
      expect(ContactSyncService.normalizePhone('+7 707 123-45-67'),
          '+77071234567');
      expect(ContactSyncService.normalizePhone('+16505551234'),
          '+16505551234');
    });

    test('local formats use the default region', () {
      expect(
        ContactSyncService.normalizePhone('87071234567',
            defaultRegion: IsoCode.KZ),
        '+77071234567',
      );
    });

    test('garbage yields null', () {
      expect(ContactSyncService.normalizePhone(''), isNull);
      expect(ContactSyncService.normalizePhone('not a number'), isNull);
      expect(ContactSyncService.normalizePhone('123'), isNull);
    });
  });

  group('syncContacts', () {
    late MockApiService api;
    late ContactSyncService svc;

    setUp(() {
      api = MockApiService();
      svc = ContactSyncService(api);
    });

    test('uploads hashes and maps matches back to labels', () async {
      final hash = ContactSyncService.hashPhone('+77071234567');
      when(() => api.post<Map<String, dynamic>>(
            '/api/contacts',
            data: any(named: 'data'),
          )).thenAnswer((_) async => _json({
                'matches': [
                  {'hash': hash, 'displayName': 'Aman'},
                  {'hash': '0' * 64, 'displayName': 'Stranger'},
                ],
              }));
      final matches = await svc.syncContacts(
        [
          const PickedContact(name: 'Sam', phone: '+7 707 123-45-67'),
          const PickedContact(name: 'NoPhone'),
          const PickedContact(name: 'Garbage', phone: 'xyz'),
        ],
        defaultRegion: IsoCode.KZ,
      );
      expect(matches, hasLength(1));
      expect(matches.single.label, 'Sam');
      expect(matches.single.displayName, 'Aman');
      final captured =
          verify(() => api.post<Map<String, dynamic>>('/api/contacts',
              data: captureAny(named: 'data'))).captured.single
              as Map<String, dynamic>;
      final sent = captured['contacts'] as List;
      expect(sent, hasLength(1));
      expect(sent.single['hash'], hash);
      expect(sent.single['label'], 'Sam');
      // Matches persist for later screens.
      final cached = await svc.lastMatches();
      expect(cached, hasLength(1));
      expect(cached.single.displayName, 'Aman');
    });

    test('network errors yield empty without throwing', () async {
      when(() => api.post<Map<String, dynamic>>(
            '/api/contacts',
            data: any(named: 'data'),
          )).thenThrow(const ApiException('No internet connection.'));
      final matches = await svc.syncContacts(
        [const PickedContact(name: 'Sam', phone: '+77071234567')],
      );
      expect(matches, isEmpty);
    });

    test('nothing uploadable skips the request', () async {
      final matches = await svc.syncContacts(
        [const PickedContact(name: 'NoPhone')],
      );
      expect(matches, isEmpty);
      verifyNever(() => api.post<Map<String, dynamic>>(
          '/api/contacts', data: any(named: 'data')));
    });

    test('clearMatches drops the cache', () async {
      when(() => api.post<Map<String, dynamic>>(
            '/api/contacts',
            data: any(named: 'data'),
          )).thenAnswer((_) async => _json({'matches': []}));
      await svc.syncContacts(
        [const PickedContact(name: 'Sam', phone: '+77071234567')],
      );
      await svc.clearMatches();
      expect(await svc.lastMatches(), isEmpty);
    });
  });
}
