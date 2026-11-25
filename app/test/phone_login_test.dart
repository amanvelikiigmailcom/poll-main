import 'fakes/reviewer_storage.dart';
import 'fakes/mock_storage_service.dart';
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
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pinput/pinput.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/router/app_router.dart';
import 'fakes/test_app.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/phone_auth_service.dart';
import 'package:flyprox_app/services/phone_auth_driver.dart';
import 'package:flyprox_app/services/storage_service.dart';
import 'fakes/fake_phone_auth_driver.dart';

class MockApiService extends Mock implements ApiService {}

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
  bool reviewer = true,
}) async {
  final storage = reviewer ? ReviewerStorageService() : StorageService();
  await storage.init();
  testAppRouter.go(AppRoutes.phone);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
        if (phoneAuth != null)
          phoneAuthServiceProvider.overrideWithValue(phoneAuth),
      ],
      child: MaterialApp.router(routerConfig: testAppRouter),
    ),
  );
  await tester.pumpAndSettle();
}

PhoneAuthService makeService({
  required FakePhoneAuthDriver driver,
  required MockApiService api,
  required MockStorageService storage,
}) {
  return PhoneAuthService(api: api, storage: storage, driver: driver);
}

void main() {
  setUp(setUpTestApp);
  setUp(markEligiblePlayer);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ContentService.instance.debugClear();
  });

  testWidgets(
    'ordinary users never get guest bypass even when its remote switch is enabled',
    (tester) async {
      ContentService.instance.debugSetOverrides({'guest_enabled': 'true'});
      await mountNames(tester, reviewer: false);
      expect(find.text('Continue without login'), findsNothing);
      expect(find.text('Send code'), findsOneWidget);
    },
  );

  testWidgets(
    'phone privacy and terms open their URLs directly without an intermediate screen',
    (tester) async {
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      final launched = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (call.method == 'launch') {
          launched.add((call.arguments as Map)['url'] as String);
          return true;
        }
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await mountNames(tester);
      for (final link in [
        ('Privacy Policy', 'url_privacy'),
        ('Terms of Use', 'url_terms'),
      ]) {
        await tester.ensureVisible(find.text(link.$1));
        await tester.tap(find.text(link.$1));
        await tester.pumpAndSettle();
        expect(launched.last, ContentService.instance.text(link.$2));
        expect(
          testAppRouter.routeInformationProvider.value.uri.path,
          AppRoutes.phone,
        );
        expect(find.text('Send code'), findsOneWidget);
      }
      expect(launched, hasLength(2));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('changing country revalidates and keeps the entered number', (
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
    expect(driver.sendCalls, 0);
    expect(
      find.text('Check the number and the selected country code.'),
      findsOneWidget,
    );
    expect(field.controller!.text, '6505551234');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'empty and malformed phone never send; formatted paste can be corrected',
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
      Future<void> submit() async {
        await tester.ensureVisible(find.text('Send code'));
        await tester.tap(find.text('Send code'));
        await pumpRoute(tester);
      }

      await submit();
      expect(find.text('Enter your phone number.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '650');
      await submit();
      expect(
        find.textContaining('Enter the full phone number'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), '650x');
      await submit();
      expect(
        find.text('Check the number and the selected country code.'),
        findsOneWidget,
      );
      expect(driver.sendCalls, 0);
      await tester.enterText(find.byType(TextField), '+1 (650) 555-1234');
      await submit();
      expect(driver.lastPhone, '+16505551234');
      expect(driver.sendCalls, 1);
      expect(find.byType(Pinput), findsOneWidget);
    },
  );

  testWidgets(
    'SMS field explains incomplete and wrong codes without losing the input',
    (tester) async {
      final driver = FakePhoneAuthDriver()
        ..confirmError = const PhoneAuthException('Wrong code. Try again.');
      await mountNames(
        tester,
        phoneAuth: makeService(
          driver: driver,
          api: MockApiService(),
          storage: MockStorageService(),
        ),
      );
      await tester.enterText(find.byType(TextField), '6505551234');
      await tester.ensureVisible(find.text('Send code'));
      await tester.tap(find.text('Send code'));
      await pumpRoute(tester);
      await tester.ensureVisible(find.text('Verify'));
      await tester.tap(find.text('Verify'));
      await pumpRoute(tester);
      expect(find.text('Enter all 6 digits from the SMS.'), findsOneWidget);
      expect(driver.confirmCalls, 0);
      final pin = tester.widget<Pinput>(find.byType(Pinput)).controller!;
      pin.text = '012345';
      await pumpRoute(tester);
      if (driver.confirmCalls == 0) {
        await tester.ensureVisible(find.text('Verify'));
        await tester.tap(find.text('Verify'));
        await pumpRoute(tester);
      }
      expect(find.textContaining('Wrong code. Try again.'), findsOneWidget);
      expect(pin.text, '012345');
      expect(driver.confirmCalls, 1);
      await tester.ensureVisible(find.text('Resend code'));
      await tester.tap(find.text('Resend code'));
      await pumpRoute(tester);
      expect(find.text('A new code is on its way.'), findsOneWidget);
      expect(pin.text, isEmpty);
      expect(driver.sendCalls, 2);
    },
  );

  for (final sample in [
    // Example mobile from the parser's GB metadata; the provider is fake.
    ('GB', '07400123456', '+447400123456'),
    ('NZ', '0211234567', '+64211234567'),
    ('CA', '(416) 555-0123', '+14165550123'),
    ('SG', '8123 4567', '+6581234567'),
    ('HK', '9123 4567', '+85291234567'),
  ]) {
    testWidgets('national phone format is normalized for ${sample.$1}', (
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

  testWidgets('guest exit opens the profile form before contacts', (
    tester,
  ) async {
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
    expect(find.text('About you'), findsOneWidget);
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
    expect(find.text('About you'), findsOneWidget);
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
      expect(find.text('About you'), findsOneWidget);
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

  testWidgets(
    'same phone route preserves input; backing out of OTP and reopening resets the code',
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
      testAppRouter.go(AppRoutes.phone);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '6505551234',
      );
      await tester.tap(find.text('Send code'));
      await pumpRoute(tester);
      expect(find.text('Enter the code'), findsOneWidget);
      tester.widget<Pinput>(find.byType(Pinput)).controller!.text = '123';
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Log in with phone'), findsOneWidget);
      expect(find.text('Enter the code'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '6505551234',
      );
      await tester.tap(find.text('Send code'));
      await pumpRoute(tester);
      expect(find.text('Enter the code'), findsOneWidget);
      expect(
        tester.widget<Pinput>(find.byType(Pinput)).controller!.text,
        isEmpty,
      );
      expect(driver.sendCalls, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'typed number receives a code and verifies into the profile form',
    (tester) async {
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
      expect(find.text('About you'), findsOneWidget);
      verify(() => storage.saveToken('backend-token')).called(1);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'new player verifies SMS, chooses age, then reaches the profile form without an early push prompt',
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
      expect(find.text('Know when you’re picked'), findsNothing);
      expect(find.text('Add your contacts'), findsNothing);
      await tester.tap(find.text('13'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('About you'), findsOneWidget);
      expect(find.byKey(const Key('onboarding-first-name')), findsOneWidget);
      expect(find.byKey(const Key('onboarding-last-name')), findsOneWidget);
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
