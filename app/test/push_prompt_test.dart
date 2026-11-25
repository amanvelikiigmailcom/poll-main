import 'dart:async';
import 'fakes/eligible_player.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/router/app_router.dart';
import 'fakes/test_app.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/push_service.dart';
import 'package:flyprox_app/services/storage_service.dart';
import 'fakes/fake_push_driver.dart';

class MockApiService extends Mock implements ApiService {}

class _PendingPermissionDriver extends FakePushDriver {
  @override
  Future<bool> requestPermission() => Completer<bool>().future;
}

Future<void> mountPrompt(
  WidgetTester tester, {
  required PushService push,
  double scale = 1,
}) async {
  final storage = StorageService();
  await storage.init();
  testAppRouter.go(AppRoutes.pushPrompt);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
        pushServiceProvider.overrideWithValue(push),
      ],
      child: MaterialApp.router(
        routerConfig: testAppRouter,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(setUpTestApp);
  setUp(markEligiblePlayer);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('notification prompt scrolls at 320px with doubled text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final driver = FakePushDriver();
    addTearDown(driver.dispose);
    await mountPrompt(
      tester,
      scale: 2,
      push: PushService(driver: driver, api: MockApiService()),
    );
    await tester.ensureVisible(find.text('Skip for now'));
    expect(find.text('Skip for now').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('optional notification enable never disables Skip', (
    tester,
  ) async {
    final driver = _PendingPermissionDriver();
    addTearDown(driver.dispose);
    await mountPrompt(
      tester,
      push: PushService(driver: driver, api: MockApiService()),
    );
    await tester.tap(find.text('Enable notifications'));
    await tester.pumpAndSettle();
    expect(find.text('Enabling…'), findsOneWidget);
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();
    expect(
      testAppRouter.routeInformationProvider.value.uri.path,
      AppRoutes.home,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('enable uploads the token', (tester) async {
    final api = MockApiService();
    when(
      () => api.post<void>('/api/devices', data: any(named: 'data')),
    ).thenAnswer(
      (_) async =>
          Response<void>(requestOptions: RequestOptions(path: '/api/devices')),
    );
    final driver = FakePushDriver();
    addTearDown(driver.dispose);
    await mountPrompt(
      tester,
      push: PushService(driver: driver, api: api),
    );
    expect(find.text('Never miss a vote'), findsOneWidget);
    await tester.tap(find.text('Enable notifications'));
    await tester.pumpAndSettle();
    expect(driver.requestCalls, 1);
    verify(
      () => api.post<void>('/api/devices', data: any(named: 'data')),
    ).called(greaterThanOrEqualTo(1));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('skip uploads nothing', (tester) async {
    final api = MockApiService();
    final driver = FakePushDriver();
    addTearDown(driver.dispose);
    await mountPrompt(
      tester,
      push: PushService(driver: driver, api: api),
    );
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();
    expect(driver.requestCalls, 0);
    verifyNever(() => api.post<void>('/api/devices', data: any(named: 'data')));
    await tester.pumpWidget(const SizedBox());
  });
}
