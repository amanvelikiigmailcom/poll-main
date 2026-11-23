import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flyprox_app/widgets/common/age_gated_startup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/router/app_router.dart';
import 'fakes/test_app.dart';
import 'package:flyprox_app/services/age_gate_service.dart';
import 'package:flyprox_app/services/storage_service.dart';
import 'package:flyprox_app/widgets/common/bottom_nav_bar.dart';
import 'fakes/fake_age_gate_store.dart';
import 'package:flyprox_app/services/onboarding_flow.dart';

Future<void> mountAgeRoute(WidgetTester tester, String route) async {
  final storage = StorageService();
  await storage.init();
  if (route == AppRoutes.age) OnboardingFlow.instance.completePhoneStep();
  testAppRouter.go(route);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [storageServiceProvider.overrideWithValue(storage)],
      child: MaterialApp.router(routerConfig: testAppRouter),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> pickAge(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Continue'));
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(setUpTestApp);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    OnboardingFlow.instance.restart();
    AgeGateService.instance.debugStore(InMemoryAgeGateStore());
    AgeGateService.instance.statusListenable.value = AgeGateStatus.unknown;
    AgeGateService.instance.replayIntroOnLaunch = false;
  });
  tearDown(() => AgeGateService.instance.resetForTest());

  testWidgets(
    'intro opens phone; guest choice then opens an unselected age question',
    (tester) async {
      await mountAgeRoute(tester, AppRoutes.onboarding);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.text('Log in with phone'), findsOneWidget);
      await tester.ensureVisible(find.text('Continue without login'));
      await tester.tap(find.text('Continue without login'));
      await tester.pumpAndSettle();
      expect(find.text('How old are you?'), findsOneWidget);
      expect(find.text('12 or younger'), findsOneWidget);
      expect(find.text('13'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Continue'),
            )
            .onPressed,
        isNull,
      );
      expect(find.byType(AppBottomNavBar), findsNothing);
      expect(find.text('Log in with phone'), findsNothing);
    },
  );

  testWidgets('under 13 blocks all protected routes in this run', (
    tester,
  ) async {
    await mountAgeRoute(tester, AppRoutes.age);
    await pickAge(tester, '12 or younger');
    expect(find.text('Flyprox isn’t available for your age'), findsOneWidget);
    expect(find.textContaining('aged 13 and older'), findsOneWidget);
    expect(find.text('Close'), findsNothing);
    expect(find.byType(AppBottomNavBar), findsNothing);
    for (final route in [
      AppRoutes.home,
      AppRoutes.phone,
      AppRoutes.namesEntry,
      AppRoutes.vote,
      AppRoutes.premium,
      AppRoutes.age,
    ]) {
      testAppRouter.go(route);
      await tester.pumpAndSettle();
      expect(
        testAppRouter.routeInformationProvider.value.uri.path,
        AppRoutes.ageBlocked,
      );
    }
    await tester.tap(find.text('For Parents'));
    await tester.pumpAndSettle();
    expect(find.text('For parents'), findsOneWidget);
    expect(find.byType(AppBottomNavBar), findsNothing);
  });

  testWidgets(
    'fresh launch after refusal replays intro and permits a new age answer',
    (tester) async {
      await mountAgeRoute(tester, AppRoutes.age);
      await pickAge(tester, '12 or younger');
      await tester.pumpWidget(const SizedBox());
      await AgeGateService.instance.load();
      await mountAgeRoute(tester, AppRoutes.splash);
      expect(find.text('Who’s most\nlikely to…?'), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Continue without login'));
      await tester.tap(find.text('Continue without login'));
      await tester.pumpAndSettle();
      await pickAge(tester, '13');
      expect(find.text('About you'), findsOneWidget);
      expect(AgeGateService.instance.status, AgeGateStatus.verified);
    },
  );

  testWidgets(
    'eligible SDK bootstrap completes before the real setup route mounts',
    (tester) async {
      final storage = StorageService();
      await storage.init();
      final ready = Completer<void>();
      var initialized = 0;
      OnboardingFlow.instance.completePhoneStep();
      testAppRouter.go(AppRoutes.age);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [storageServiceProvider.overrideWithValue(storage)],
          child: AgeGatedStartup(
            initialize: () {
              initialized++;
              return ready.future;
            },
            child: MaterialApp.router(routerConfig: testAppRouter),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('13'));
      await tester.pump();
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(initialized, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      ready.complete();
      await tester.pumpAndSettle();
      expect(find.text('About you'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'direct game or age entry starts at phone until that step completes',
    (tester) async {
      await mountAgeRoute(tester, AppRoutes.home);
      expect(find.text('Log in with phone'), findsOneWidget);
      testAppRouter.go(AppRoutes.age);
      await tester.pumpAndSettle();
      expect(find.text('How old are you?'), findsNothing);
      expect(find.text('Log in with phone'), findsOneWidget);
    },
  );
}
