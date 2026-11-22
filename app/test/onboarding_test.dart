import 'fakes/eligible_player.dart';
import 'dart:convert';
import 'package:flutter_native_contact_picker/model/contact.dart';
import 'package:flyprox_app/services/contact_picker_service.dart';
import 'fakes/fake_contact_picker_driver.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/router/app_router.dart';
import 'package:flyprox_app/screens/onboarding/onboarding_screen.dart';
import 'package:flyprox_app/services/content_service.dart';
import 'package:flyprox_app/services/local_game_service.dart';
import 'package:flyprox_app/services/storage_service.dart';
import 'package:flyprox_app/theme/app_theme.dart';

import 'fakes/fake_secure_storage.dart';

Future<StorageService> mountApp(WidgetTester tester) async {
  final storage = StorageService();
  await storage.init();
  appRouter.go(AppRoutes.splash);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [storageServiceProvider.overrideWithValue(storage)],
      child: MaterialApp.router(
        routerConfig: appRouter,
        theme: AppTheme.lightTheme,
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
  return storage;
}

void main() {
  setUp(markEligiblePlayer);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    useFakeSecureStorage();
    ContentService.instance.debugClear();
  });

  tearDown(() => ContentService.instance.debugClear());

  testWidgets(
    'first launch opens intro; Skip persists across a fresh app mount',
    (tester) async {
      final storage = await mountApp(tester);
      expect(find.text('Who’s most\nlikely to…?'), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(storage.isOnboardingDone(), isTrue);
      expect(
        appRouter.routeInformationProvider.value.uri.path,
        AppRoutes.namesEntry,
      );
      await tester.pumpWidget(const SizedBox());
      await mountApp(tester);
      expect(
        appRouter.routeInformationProvider.value.uri.path,
        AppRoutes.namesEntry,
      );
      expect(find.byType(OnboardingScreen), findsNothing);
    },
  );

  testWidgets('Next, Back and swipe reach three pages; finish opens setup', (
    tester,
  ) async {
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
    expect(
      appRouter.routeInformationProvider.value.uri.path,
      AppRoutes.namesEntry,
    );
  });

  testWidgets('existing players bypass intro; replay keeps their game data', (
    tester,
  ) async {
    await LocalGameService.instance.savePlayerAndFriends(
      username: 'alex_01',
      playerName: 'Alex',
      friends: ['Sam', 'Jamie', 'Taylor', 'Robin'],
    );
    await mountApp(tester);
    expect(appRouter.routeInformationProvider.value.uri.path, AppRoutes.home);
    appRouter.push(AppRoutes.onboarding);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(appRouter.routeInformationProvider.value.uri.path, AppRoutes.home);
    expect(await LocalGameService.instance.getNames(), [
      'Sam',
      'Jamie',
      'Taylor',
      'Robin',
    ]);
  });

  testWidgets(
    'examples start a normal quiz without login and survive restart',
    (tester) async {
      await mountApp(tester);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.text('What should we call you?'), findsOneWidget);
      expect(find.text('Create username'), findsNothing);
      await tester.ensureVisible(find.text('Try with example names'));
      await tester.tap(find.text('Try with example names'));
      await tester.pumpAndSettle();
      final game = LocalGameService.instance;
      expect(appRouter.routeInformationProvider.value.uri.path, AppRoutes.home);
      expect(await game.getUsername(), isNull);
      expect(await game.getPlayerName(), 'Player');
      expect(await game.getNames(), ['Alex', 'Sam', 'Jordan', 'Taylor']);
      expect((await game.generateRound(languageCode: 'en')).length, 12);
      await tester.pumpWidget(const SizedBox());
      await mountApp(tester);
      expect(appRouter.routeInformationProvider.value.uri.path, AppRoutes.home);
    },
  );

  testWidgets('manual nicknames start the game without a login', (
    tester,
  ) async {
    await mountApp(tester);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Captain');
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Log in with phone'), findsOneWidget);
    await tester.tap(find.text('Continue without login'));
    await tester.pumpAndSettle();
    expect(find.text('Choose your friends'), findsOneWidget);
    for (final name in ['Moon', 'Sun', 'Star', 'Sky']) {
      await tester.enterText(find.byType(TextField), name);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(appRouter.routeInformationProvider.value.uri.path, AppRoutes.home);
    expect(tester.testTextInput.isVisible, isFalse);
    expect(await LocalGameService.instance.getUsername(), isNull);
    expect(await LocalGameService.instance.getPlayerName(), 'Captain');
    expect(await LocalGameService.instance.getNames(), [
      'Moon',
      'Sun',
      'Star',
      'Sky',
    ]);
  });

  testWidgets(
    'Find one contact uses the single system picker and keeps the chosen label',
    (tester) async {
      final driver = FakeContactPickerDriver(
        oneResults: [Contact(fullName: 'Selected friend')],
      );
      ContactPickerService.instance.debugDriver(driver);
      addTearDown(ContactPickerService.instance.resetDriverForTest);
      await LocalGameService.instance.savePlayerName('Me');
      await mountApp(tester);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Find one contact'));
      await tester.tap(find.text('Find one contact'));
      await tester.pumpAndSettle();
      expect(driver.pickOneCalls, 1);
      expect(driver.pickManyCalls, 0);
      expect(find.text('Selected friend'), findsOneWidget);
      expect(tester.testTextInput.isVisible, isFalse);
    },
  );

  testWidgets('friends fit above keyboard and Done dismisses it', (
    tester,
  ) async {
    await LocalGameService.instance.savePlayerName('Captain');
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 340);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await mountApp(tester);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final input = find.byType(TextField);
    await tester.ensureVisible(input);
    await tester.enterText(input, 'Moon');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isFalse);
    expect(find.text('Moon'), findsOneWidget);
    await tester.showKeyboard(input);
    await tester.ensureVisible(find.text('Choose your friends'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose your friends'));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets(
    'nickname screen keeps input and spaced actions visible above keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await mountApp(tester);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isFalse);
      tester.view.viewInsets = const FakeViewPadding(bottom: 340);
      await tester.enterText(find.byType(TextField), 'Nickname');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final primary = find.widgetWithText(ElevatedButton, 'Continue');
      final secondary = find.widgetWithText(
        OutlinedButton,
        'Try with example names',
      );
      await tester.ensureVisible(secondary);
      await tester.pumpAndSettle();
      expect(primary.hitTestable(), findsOneWidget);
      expect(secondary.hitTestable(), findsOneWidget);
      expect(
        tester.getTopLeft(secondary).dy - tester.getBottomLeft(primary).dy,
        greaterThanOrEqualTo(12),
      );
      expect(tester.testTextInput.isVisible, isTrue);
    },
  );

  testWidgets('examples do not duplicate the chosen nickname', (tester) async {
    await mountApp(tester);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Alex');
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue without login'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Try with example names'));
    await tester.tap(find.text('Try with example names'));
    await tester.pumpAndSettle();
    expect(await LocalGameService.instance.getPlayerName(), 'Alex');
    expect(await LocalGameService.instance.getNames(), [
      'Sam',
      'Jordan',
      'Taylor',
      'Casey',
    ]);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('all pages fit a small screen at text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final storage = StorageService();
      await storage.init();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [storageServiceProvider.overrideWithValue(storage)],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const OnboardingScreen(),
          ),
        ),
      );
      for (var i = 0; i < 3; i++) {
        await tester.pumpAndSettle();
        final button = find.widgetWithText(
          ElevatedButton,
          i == 2 ? 'Get started' : 'Next',
        );
        expect(button.hitTestable(), findsOneWidget);
        expect(find.text('Skip').hitTestable(), findsOneWidget);
        if (i < 2) await tester.tap(button);
      }
    });
  }

  testWidgets('server pages replace the intro without code changes', (
    tester,
  ) async {
    final pages = List.generate(
      5,
      (i) => {
        'emoji': '⭐',
        'title': 'Server page ${i + 1}',
        'subtitle': 'Server subtitle ${i + 1}',
      },
    );
    ContentService.instance.debugSetOverrides({
      'onboarding_pages': jsonEncode(pages),
    });
    final storage = StorageService();
    await storage.init();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [storageServiceProvider.overrideWithValue(storage)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const OnboardingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Server page 1'), findsOneWidget);
    expect(find.text('Who’s most\nlikely to…?'), findsNothing);
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Server page 5'), findsOneWidget);
    expect(find.text('5 / 5'), findsOneWidget);
    expect(find.text('Next'), findsNothing);
    expect(find.text('Get started'), findsOneWidget);
  });
}
