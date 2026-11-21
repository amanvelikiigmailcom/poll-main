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
  appRouter.go(AppRoutes.namesEntry);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      storageServiceProvider.overrideWithValue(storage),
      if (phoneAuth != null)
        phoneAuthServiceProvider.overrideWithValue(phoneAuth),
    ],
    child: MaterialApp.router(routerConfig: appRouter),
  ));
  await tester.pumpAndSettle();
}

Future<void> enterNickAndContinue(WidgetTester tester, String nick) async {
  await tester.enterText(find.byType(TextField), nick);
  await tester.pump();
  await tester.tap(find.text('Continue'));
  await tester.pump();
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
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    useFakeSecureStorage();
  });

  testWidgets('guest skip reveals the friends step underneath', (tester) async {
    await mountNames(tester,
        phoneAuth: makeService(
          driver: FakePhoneAuthDriver(),
          api: MockApiService(),
          storage: MockStorageService(),
        ));
    await enterNickAndContinue(tester, 'Captain');
    expect(find.text('Log in with phone'), findsOneWidget);
    await tester.ensureVisible(find.text('Continue without login'));
    await tester.tap(find.text('Continue without login'));
    await tester.pumpAndSettle();
    expect(find.text('Choose your friends'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('unavailable login shows a notice and guest only', (tester) async {
    await mountNames(tester,
        phoneAuth: makeService(
          driver: FakePhoneAuthDriver()..available = false,
          api: MockApiService(),
          storage: MockStorageService(),
        ));
    await enterNickAndContinue(tester, 'Captain');
    expect(find.textContaining('isn’t available in this build'),
        findsOneWidget);
    final send = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Send code'));
    expect(send.onPressed, isNull);
    await tester.ensureVisible(find.text('Continue without login'));
    await tester.tap(find.text('Continue without login'));
    await tester.pumpAndSettle();
    expect(find.text('Choose your friends'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('pending code request keeps guest exit and hides unavailable notice',
      (tester) async {
    final pending = Completer<CodeSent>();
    final driver = FakePhoneAuthDriver()
      ..sendHandler = (_) => pending.future;
    await mountNames(tester,
        phoneAuth: makeService(
          driver: driver,
          api: MockApiService(),
          storage: MockStorageService(),
        ));
    await enterNickAndContinue(tester, 'Captain');
    await tester.enterText(find.byType(TextField), '6505551234');
    await tester.pump();
    await tester.ensureVisible(find.text('Send code'));
    await tester.tap(find.text('Send code'));
    await tester.pump();
    expect(find.text('Sending…'), findsOneWidget);
    expect(find.textContaining('isn’t available in this build'), findsNothing);
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.ensureVisible(find.text('Continue without login'));
    await tester.tap(find.text('Continue without login'));
    await pumpRoute(tester);
    expect(find.text('Choose your friends'), findsOneWidget);
    pending.complete(const CodeSent(verificationId: 'late-code'));
    await tester.pumpAndSettle();
    expect(find.text('Enter the code'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('code timeout restores send button instead of leaving it stuck',
      (tester) async {
    final pending = Completer<CodeSent>();
    final driver = FakePhoneAuthDriver()
      ..sendHandler = (_) => pending.future;
    await mountNames(tester,
        phoneAuth: makeService(
          driver: driver,
          api: MockApiService(),
          storage: MockStorageService(),
        ));
    await enterNickAndContinue(tester, 'Captain');
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
        find.widgetWithText(ElevatedButton, 'Send code'));
    expect(send.onPressed, isNotNull);
    pending.complete(const CodeSent());
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('typed number receives a code and verifies into friends',
      (tester) async {
    final api = MockApiService();
    final storage = MockStorageService();
    final driver = FakePhoneAuthDriver();
    when(() => storage.saveToken(any())).thenAnswer((_) async {});
    when(() => storage.savePhone(any())).thenAnswer((_) async {});
    when(() => api.post<Map<String, dynamic>>(
          '/api/auth/firebase',
          data: any(named: 'data'),
        )).thenAnswer((_) async => _json({
              'token': 'backend-token',
              'isNewUser': true,
            }));
    await mountNames(tester,
        phoneAuth:
            PhoneAuthService(api: api, storage: storage, driver: driver));
    await enterNickAndContinue(tester, 'Captain');
    await tester.enterText(find.byType(TextField), '6505551234');
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Send code'));
    await pumpRoute(tester);
    expect(driver.lastPhone, '+16505551234');
    expect(find.text('Enter the code'), findsOneWidget);

    // Pinput's center doesn't hit-test, so tap() would miss: set its
    // controller directly, then press the explicit Verify button.
    tester
        .widget<Pinput>(find.byType(Pinput))
        .controller
        ?.text = '123456';
    await tester.pump();
    await tester.tap(find.text('Verify'));
    await pumpRoute(tester);
    await tester.pumpAndSettle();
    expect(find.text('Choose your friends'), findsOneWidget);
    verify(() => storage.saveToken('backend-token')).called(1);
    await tester.pumpWidget(const SizedBox());
  });
}
