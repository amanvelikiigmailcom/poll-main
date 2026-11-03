import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/router/app_router.dart';
import 'package:flyprox_app/screens/onboarding/onboarding_screen.dart';
import 'package:flyprox_app/services/local_game_service.dart';
import 'package:flyprox_app/services/storage_service.dart';
import 'package:flyprox_app/theme/app_theme.dart';

Future<StorageService> mountApp(WidgetTester tester) async {
  final storage = StorageService();
  await storage.init();
  appRouter.go(AppRoutes.splash);
  await tester.pumpWidget(ProviderScope(
    overrides: [storageServiceProvider.overrideWithValue(storage)],
    child:
        MaterialApp.router(routerConfig: appRouter, theme: AppTheme.lightTheme),
  ));
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
  return storage;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
      'first launch opens intro; Skip persists across a fresh app mount',
      (tester) async {
    final storage = await mountApp(tester);
    expect(find.text('Who’s most\nlikely to…?'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(storage.isOnboardingDone(), isTrue);
    expect(appRouter.routeInformationProvider.value.uri.path,
        AppRoutes.namesEntry);
    await tester.pumpWidget(const SizedBox());
    await mountApp(tester);
    expect(appRouter.routeInformationProvider.value.uri.path,
        AppRoutes.namesEntry);
    expect(find.byType(OnboardingScreen), findsNothing);
  });

  testWidgets('Next, Back and swipe reach three pages; finish opens setup',
      (tester) async {
    final storage = await mountApp(tester);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Make it\nyour circle.'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Who’s most\nlikely to…?'), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Make it\nyour circle.'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Play. Collect.\nRepeat.'), findsOneWidget);
    expect(find.text('3 / 3'), findsOneWidget);
    expect(find.text('Next'), findsNothing);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(storage.isOnboardingDone(), isTrue);
    expect(appRouter.routeInformationProvider.value.uri.path,
        AppRoutes.namesEntry);
  });

  testWidgets('existing players bypass intro; replay keeps their game data',
      (tester) async {
    await LocalGameService.instance.savePlayerAndFriends(
        username: 'alex_01',
        playerName: 'Alex',
        friends: ['Sam', 'Jamie', 'Taylor']);
    await mountApp(tester);
    expect(appRouter.routeInformationProvider.value.uri.path, AppRoutes.home);
    appRouter.push(AppRoutes.onboarding);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(appRouter.routeInformationProvider.value.uri.path, AppRoutes.home);
    expect(
        await LocalGameService.instance.getNames(), ['Sam', 'Jamie', 'Taylor']);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('all pages fit a small screen at text scale $scale',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final storage = StorageService();
      await storage.init();
      await tester.pumpWidget(ProviderScope(
        overrides: [storageServiceProvider.overrideWithValue(storage)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: const OnboardingScreen(),
        ),
      ));
      for (var i = 0; i < 3; i++) {
        await tester.pumpAndSettle();
        final button = find.widgetWithText(
            ElevatedButton, i == 2 ? 'Get started' : 'Next');
        expect(button.hitTestable(), findsOneWidget);
        expect(find.text('Skip').hitTestable(), findsOneWidget);
        if (i < 2) await tester.tap(button);
      }
    });
  }
}
