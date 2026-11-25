import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/onboarding_details_service.dart';
import 'package:flyprox_app/services/storage_service.dart';
import 'package:flyprox_app/services/storefront_service.dart';
import 'fakes/fake_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(useFakeSecureStorage);
  test(
    'server waiting state overrides local completed onboarding and survives a new session',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      await storage.saveToken('account-session-1');
      final api = ApiService(storage);
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) => handler.resolve(
            Response(
              requestOptions: request,
              data: {
                'status': 'waiting',
                'country': 'GB',
                'school': {'id': 'GB-1', 'name': 'Closed Campus'},
                'graduationYear': 2030,
                'votingAllowed': false,
                'campusAvailable': false,
                'profileComplete': true,
                'reviewerSkipsAllowed': false,
              },
            ),
          ),
        ),
      );
      final service = OnboardingDetailsService(api, storage);
      addTearDown(service.dispose);
      await service.draft({
        'stage': 'done',
        'status': 'selected',
        'country': 'US',
      });
      expect(await service.restore(requireOnline: true), isTrue);
      expect((await service.read())['stage'], 'waiting');
      expect(await service.votingAllowed(), isFalse);
      await service.setCountry('US');
      expect(await service.country(), 'GB');
      await storage.saveToken('account-session-2');
      await service.restore(requireOnline: true);
      expect((await service.read())['status'], 'waiting');
      expect(await service.votingAllowed(), isFalse);
    },
  );
  test(
    'storefront suggests study country once and never replaces waiting enrollment',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      final service = OnboardingDetailsService(ApiService(storage), storage);
      addTearDown(service.dispose);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            StorefrontService.channel,
            (call) async => 'GBR',
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(StorefrontService.channel, null),
      );
      await service.setCountry('US');
      await service.suggestStorefrontCountry();
      expect(await service.country(), 'GB');
      await service.draft({'status': 'waiting', 'country': 'US'});
      await service.suggestStorefrontCountry();
      expect(await service.country(), 'US');
    },
  );
  test(
    'unsupported storefront requires an explicit country confirmation',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      final service = OnboardingDetailsService(ApiService(storage), storage);
      addTearDown(service.dispose);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            StorefrontService.channel,
            (call) async => 'THA',
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(StorefrontService.channel, null),
      );
      await service.suggestStorefrontCountry();
      expect((await service.read())['unsupportedStorefront'], isTrue);
      expect((await service.read())['countryConfirmed'], isFalse);
    },
  );
  test(
    'StoreKit country mapping does not guess US for an unsupported country',
    () {
      expect(StorefrontService.normalize('USA'), 'US');
      expect(StorefrontService.normalize('GBR'), 'GB');
      expect(StorefrontService.normalize('CAN'), 'CA');
      expect(StorefrontService.normalize('THA'), isNull);
      expect(StorefrontService.normalize(null), isNull);
    },
  );
}
