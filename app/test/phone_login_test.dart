import 'fakes/eligible_player.dart';
import 'package:flyprox_app/services/content_service.dart';
import 'package:flyprox_app/services/age_gate_service.dart';
import 'package:flyprox_app/services/onboarding_flow.dart';
import 'fakes/fake_age_gate_store.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:flyprox_app/config/phone_regions.dart';
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pinput/pinput.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/router/app_router.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/phone_auth_service.dart';
import 'package:flyprox_app/services/phone_auth_driver.dart';
import 'package:flyprox_app/services/storage_service.dart';
import 'fakes/fake_phone_auth_driver.dart';
import 'fakes/fake_secure_storage.dart';

class MockApiService extends Mock implements ApiService {}

class MockStorageService extends Mock implements StorageService {}

Response<Map<String, dynamic>> _json(Map<String, dynamic> data) =>
    Response<Map<String, dynamic>>(
      requestOptions: RequestOptions(path: '/api/auth/firebase'),
      data: data,
    );

Future<void> pumpRoute(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> mountNames(
  WidgetTester tester, {
  PhoneAuthService? phoneAuth,
}) async {
  final storage = StorageService();
  await storage.init();
  appRouter.go(AppRoutes.phone);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
        if (phoneAuth != null)
          phoneAuthServiceProvider.overrideWithValue(phoneAuth),
      ],
      child: MaterialApp.router(routerConfig: appRouter),
    ),
  );
  await tester.pumpAndSettle();
}

PhoneAuthService makeService({
  required FakePhoneAuthDriver driver,
  required MockApiService api,
  required MockStorageService storage,
}) {
  when(() => storage.saveToken(any())).thenAnswer((_) async {});
  when(() => storage.savePhone(any())).thenAnswer((_) async {});
  return PhoneAuthService(api: api, storage: storage, driver: driver);
}

void main() {
  setUp(markEligiblePlayer);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ContentService.instance.debugClear();
    useFakeSecureStorage();
  });

  testWidgets(
    'changing country recomputes the dial code for the existing number',
    (tester) async {
      final driver = FakePhoneAuthDriver();
      await mountNames(
        tester,
        phoneAuth: makeService(
          driver: driver,
          api: MockApiService(),
          storage: MockStorageService(),
        ),
      );
      await tester.enterText(find.byType(TextField), '6505551234');
      await tester.pump();
      final field = tester.widget<IntlPhoneField>(find.byType(IntlPhoneField));
      expect(field.initialCountryCode, 'US');
      expect(field.countries?.length, 6);
      field.onCountryChanged!(
        PhoneRegions.countries.singleWhere((c) => c.code == 'GB'),
      );
      await tester.pump();
      await tester.ensureVisible(find.text('Send code'));
      await tester.tap(find.text('Send code'));
      await pumpRoute(tester);
      expect(driver.lastPhone, '+446505551234');
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final sample in [
    ('GB', '07911123456', '+447911123456'),
    ('NZ', '0211234567', '+64211234567'),
  ]) {
    testWidgets('national trunk zero is normalized for ${sample.$1}', (
      tester,
    ) async {
      final driver = FakePhoneAuthDriver();
      await mountNames(
        tester,
        phoneAuth: makeService(
          driver: driver,
          api: MockApiService(),
          storage: MockStorageService(),
        ),
      );
      await tester.enterText(find.byType(TextField), sample.$2);
      await tester.pump();
      final field = tester.widget<IntlPhoneField>(find.byType(IntlPhoneField));
      field.onCountryChanged!(
        PhoneRegions.countries.singleWhere((c) => c.code == sample.$1),
      );
      await tester.pump();
      await tester.ensureVisible(find.text('Send code'));
      await tester.tap(find.text('Send code'));
      await pumpRoute(tester);
      expect(driver.lastPhone, sample.$3);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('guest skip reveals the friends step underneath', (tester) async {
    await mountNames(
      tester,
      phoneAuth: makeService(
        driver: FakePhoneAuthDriver(),
        api: MockApiService(),
        storage: MockStorageService(),
      ),
    );
    expect(find.text('Log in with phone'), findsOneWidget);
    await tester.ensureVisible(find.text('Continue without login'));
    await tester.tap(find.text('Continue without login'));
    await tester.pumpAndSettle();
    expect(find.text('Add your contacts'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('unavailable login shows a notice and guest only', (
    tester,
  ) async {
    await mountNames(
      tester,
      phoneAuth: makeService(
        driver: FakePhoneAuthDriver()..available = false,
        api: MockApiService(),
        storage: MockStorageService(),
      ),
    );
    expect(
      find.textContaining('isn’t available in this build'),
      findsOneWidget,
    );
    final send = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Send code'),
    );
    expect(send.onPressed, isNull);
    await tester.ensureVisible(find.text('Continue without login'));
    await tester.tap(find.text('Continue without login'));
    await tester.pumpAndSettle();
    expect(find.text('Add your contacts'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'pending code request keeps guest exit and hides unavailable notice',
    (tester) async {
      final pending = Completer<CodeSent>();
      final driver = FakePhoneAuthDriver()..sendHandler = (_) => pending.future;
      await mountNames(
        tester,
        phoneAuth: makeService(
          driver: driver,
          api: MockApiService(),
          storage: MockStorageService(),
        ),
      );
      await tester.enterText(find.byType(TextField), '6505551234');
      await tester.pump();
      await tester.ensureVisible(find.text('Send code'));
      await tester.tap(find.text('Send code'));
      await tester.pump();
      expect(find.text('Sending…'), findsOneWidget);
      expect(
        find.textContaining('isn’t available in this build'),
        findsNothing,
      );
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.ensureVisible(find.text('Continue without login'));
      await tester.tap(find.text('Continue without login'));
      await pumpRoute(tester);
      expect(find.text('Add your contacts'), findsOneWidget);
      pending.complete(const CodeSent(verificationId: 'late-code'));
      await tester.pumpAndSettle();
      expect(find.text('Enter the code'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('code timeout restores send button instead of leaving it stuck', (
    tester,
  ) async {
    final pending = Completer<CodeSent>();
    final driver = FakePhoneAuthDriver()..sendHandler = (_) => pending.future;
    await mountNames(
      tester,
      phoneAuth: makeService(
        driver: driver,
        api: MockApiService(),
        storage: MockStorageService(),
      ),
    );
    await tester.enterText(find.byType(TextField), '6505551234');
    await tester.pump();
    await tester.ensureVisible(find.text('Send code'));
    await tester.tap(find.text('Send code'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 91));
    await tester.pump();
    expect(find.text('Sending…'), findsNothing);
    expect(find.textContaining('request timed out'), findsOneWidget);
    final send = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Send code'),
    );
    expect(send.onPressed, isNotNull);
    pending.complete(const CodeSent());
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('typed number receives a code and verifies into friends', (
    tester,
  ) async {
    final api = MockApiService();
    final storage = MockStorageService();
    final driver = FakePhoneAuthDriver();
    when(() => storage.saveToken(any())).thenAnswer((_) async {});
    when(() => storage.savePhone(any())).thenAnswer((_) async {});
    when(
      () => api.post<Map<String, dynamic>>(
        '/api/auth/firebase',
        data: any(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => _json({'token': 'backend-token', 'isNewUser': true}),
    );
    await mountNames(
      tester,
      phoneAuth: PhoneAuthService(api: api, storage: storage, driver: driver),
    );
    await tester.enterText(find.byType(TextField), '6505551234');
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Send code'));
    await pumpRoute(tester);
    expect(driver.lastPhone, '+16505551234');
    expect(find.text('Enter the code'), findsOneWidget);

    // Completing the controller exercises Pinput's automatic verification;
    // the next test also covers the explicit Verify action.
    tester.widget<Pinput>(find.byType(Pinput)).controller?.text = '123456';
    await pumpRoute(tester);
    await tester.pumpAndSettle();
    expect(find.text('Add your contacts'), findsOneWidget);
    verify(() => storage.saveToken('backend-token')).called(1);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'new player verifies SMS, chooses age, then reaches contacts without an early push prompt',
    (tester) async {
      final legacy = InMemoryAgeGateStore()
        ..values['age_gate_status'] = 'verified';
      AgeGateService.instance.debugStore(legacy);
      await AgeGateService.instance.load();
      expect(AgeGateService.instance.status, AgeGateStatus.unknown);
      AgeGateService.instance.statusListenable.value = AgeGateStatus.unknown;
      OnboardingFlow.instance.restart();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await AgeGateService.instance.resetForTest();
      });
      final api = MockApiService();
      final storage = MockStorageService();
      final driver = FakePhoneAuthDriver();
      when(
        () => api.post<Map<String, dynamic>>(
          '/api/auth/firebase',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => _json({'token': 'backend-token', 'isNewUser': true}),
      );
      await mountNames(
        tester,
        phoneAuth: makeService(driver: driver, api: api, storage: storage),
      );
      expect(find.text('Log in with phone'), findsOneWidget);
      expect(find.text('How old are you?'), findsNothing);
      await tester.enterText(find.byType(TextField), '6505551234');
      await tester.pump();
      await tester.tap(find.text('Send code'));
      await pumpRoute(tester);
      expect(find.text('Enter the code'), findsOneWidget);
      expect(find.text('How old are you?'), findsNothing);
      tester.widget<Pinput>(find.byType(Pinput)).controller!.text = '123456';
      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();
      expect(find.text('How old are you?'), findsOneWidget);
      expect(find.text('Never miss a vote'), findsNothing);
      expect(find.text('Add your contacts'), findsNothing);
      await tester.tap(find.text('13'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Add your contacts'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(tester.testTextInput.isVisible, isFalse);
      verify(() => storage.saveToken('backend-token')).called(1);
    },
  );

  testWidgets('SMS code screen remains usable with keyboard on a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await mountNames(
      tester,
      phoneAuth: makeService(
        driver: FakePhoneAuthDriver(),
        api: MockApiService(),
        storage: MockStorageService(),
      ),
    );
    await tester.enterText(find.byType(TextField), '6505551234');
    await tester.pump();
    await tester.ensureVisible(find.text('Send code'));
    await tester.tap(find.text('Send code'));
    await pumpRoute(tester);
    expect(find.text('Enter the code'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Verify'));
    await pumpRoute(tester);
    expect(find.text('Verify').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'automatic number verification also leads to age rather than skipping it',
    (tester) async {
      AgeGateService.instance.debugStore(InMemoryAgeGateStore());
      AgeGateService.instance.statusListenable.value = AgeGateStatus.unknown;
      OnboardingFlow.instance.restart();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await AgeGateService.instance.resetForTest();
      });
      final api = MockApiService();
      when(
        () => api.post<Map<String, dynamic>>(
          '/api/auth/firebase',
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => _json({'token': 'auto-session'}));
      await mountNames(
        tester,
        phoneAuth: makeService(
          driver: FakePhoneAuthDriver(
            codeResult: const CodeSent(autoIdToken: 'auto-id-token'),
          ),
          api: api,
          storage: MockStorageService(),
        ),
      );
      await tester.enterText(find.byType(TextField), '6505551234');
      await tester.pump();
      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();
      expect(find.text('How old are you?'), findsOneWidget);
      expect(find.text('Add your contacts'), findsNothing);
    },
  );
  testWidgets(
    'server guest switch removes the exit on number and code screens',
    (tester) async {
      addTearDown(ContentService.instance.debugClear);
      await mountNames(
        tester,
        phoneAuth: makeService(
          driver: FakePhoneAuthDriver(),
          api: MockApiService(),
          storage: MockStorageService(),
        ),
      );
      expect(find.text('Continue without login'), findsOneWidget);
      ContentService.instance.debugSetOverrides({'guest_enabled': 'false'});
      await tester.pump();
      expect(find.text('Continue without login'), findsNothing);
      await tester.enterText(find.byType(TextField), '6505551234');
      await tester.pump();
      await tester.tap(find.text('Send code'));
      await pumpRoute(tester);
      expect(find.text('Enter the code'), findsOneWidget);
      expect(find.text('Continue without login'), findsNothing);
      ContentService.instance.debugSetOverrides({'guest_enabled': 'true'});
      await tester.pump();
      expect(find.text('Continue without login'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
