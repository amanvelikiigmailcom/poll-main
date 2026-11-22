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
        AppRoutes.phone,
      );
      await tester.pumpWidget(const SizedBox());
      await mountApp(tester);
      expect(
        appRouter.routeInformationProvider.value.uri.path,
        AppRoutes.phone,
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
    expect(appRouter.routeInformationProvider.value.uri.path, AppRoutes.phone);
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
      expect(find.text('Log in with phone'), findsOneWidget);
      await tester.tap(find.text('Continue without login'));
      await tester.pumpAndSettle();
      expect(find.text('Add your contacts'), findsOneWidget);
      expect(find.text('Create username'), findsNothing);
      await tester.ensureVisible(find.text('Try with example names'));
      await tester.tap(find.text('Try with example names'));
      await tester.pumpAndSettle();
      final game = LocalGameService.instance;
      expect(appRouter.routeInformationProvider.value.uri.path, AppRoutes.home);
      expect(await game.getUsername(), isNull);
      expect(await game.getPlayerName(), 'Michael');
      expect(await game.getNames(), ['Alex', 'Sam', 'Jordan', 'Taylor']);
      expect((await game.generateRound(languageCode: 'en')).length, 12);
      await tester.pumpWidget(const SizedBox());
      await mountApp(tester);
      expect(appRouter.routeInformationProvider.value.uri.path, AppRoutes.home);
    },
  );

  Future<void> openContacts(WidgetTester tester) async {
    await mountApp(tester);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue without login'));
    await tester.tap(find.text('Continue without login'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'four contacts enable Continue; three do not; manual fields are removed',
    (tester) async {
      final driver = FakeContactPickerDriver(
        manyResult: [
          Contact(fullName: 'Moon'),
          Contact(fullName: 'Sun'),
          Contact(fullName: 'Star'),
        ],
        oneResults: [Contact(fullName: 'Sky')],
      );
      ContactPickerService.instance.debugDriver(driver);
      addTearDown(ContactPickerService.instance.resetDriverForTest);
      await openContacts(tester);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('What should we call you?'), findsNothing);
      expect(find.text('Choose your friends'), findsNothing);
      expect(
        find.text('Choose at least 4 contacts to start your quiz.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Choose from contacts'));
      await tester.pumpAndSettle();
      expect(find.text('3 / 4 contacts · Add 1 more'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Continue'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Find one contact'));
      await tester.pumpAndSettle();
      expect(find.text('4 contacts selected · Ready to play'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(appRouter.routeInformationProvider.value.uri.path, AppRoutes.home);
      expect(await LocalGameService.instance.getNames(), [
        'Moon',
        'Sun',
        'Star',
        'Sky',
      ]);
      expect(tester.testTextInput.isVisible, isFalse);
    },
  );

  testWidgets(
    'more than ten selected contacts reach the game without truncation',
    (tester) async {
      final contacts = List.generate(17, (i) => Contact(fullName: 'Friend $i'));
      ContactPickerService.instance.debugDriver(
        FakeContactPickerDriver(manyResult: contacts),
      );
      addTearDown(ContactPickerService.instance.resetDriverForTest);
      await openContacts(tester);
      await tester.tap(find.text('Choose from contacts'));
      await tester.pumpAndSettle();
      expect(find.text('17 contacts selected · Ready to play'), findsOneWidget);
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(await LocalGameService.instance.getNames(), hasLength(17));
    },
  );

  testWidgets('cancelled contacts leave the count unchanged', (tester) async {
    final driver = FakeContactPickerDriver();
    ContactPickerService.instance.debugDriver(driver);
    addTearDown(ContactPickerService.instance.resetDriverForTest);
    await openContacts(tester);
    await tester.tap(find.text('Choose from contacts'));
    await tester.pumpAndSettle();
    expect(find.text('0 / 4 contacts · Add 4 more'), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Continue'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'Find one contact uses single picker and keeps the selected label',
    (tester) async {
      final driver = FakeContactPickerDriver(
        oneResults: [Contact(fullName: 'Selected friend')],
      );
      ContactPickerService.instance.debugDriver(driver);
      addTearDown(ContactPickerService.instance.resetDriverForTest);
      await openContacts(tester);
      await tester.tap(find.text('Find one contact'));
      await tester.pumpAndSettle();
      expect(driver.pickOneCalls, 1);
      expect(driver.pickManyCalls, 0);
      expect(find.text('Selected friend'), findsOneWidget);
    },
  );

  testWidgets(
    'server changes example label and description; disabling removes both immediately',
    (tester) async {
      await openContacts(tester);
      ContentService.instance.debugSetOverrides({
        'example_names_button': 'Try a demo',
        'example_names_description': 'Demo copy from server',
      });
      await tester.pumpAndSettle();
      expect(find.text('Try a demo'), findsOneWidget);
      expect(find.text('Demo copy from server'), findsOneWidget);
      ContentService.instance.debugSetOverrides({
        'example_names_enabled': 'false',
      });
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.play_circle_outline), findsNothing);
      expect(find.text('Demo copy from server'), findsNothing);
      expect(
        find.text(
          'Want to try first? Use example names without sharing contacts.',
        ),
        findsNothing,
      );
      expect(find.text('Choose from contacts'), findsOneWidget);
    },
  );

  testWidgets(
    'examples replace an old wish nickname with Michael and preserve sample friends',
    (tester) async {
      await LocalGameService.instance.savePlayerName('wish');
      await openContacts(tester);
      await tester.ensureVisible(find.text('Try with example names'));
      await tester.tap(find.text('Try with example names'));
      await tester.pumpAndSettle();
      expect(await LocalGameService.instance.getPlayerName(), 'Michael');
      expect(await LocalGameService.instance.getNames(), [
        'Alex',
        'Sam',
        'Jordan',
        'Taylor',
      ]);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'contacts fit a small viewport at text scale $scale without keyboard',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final storage = StorageService();
        await storage.init();
        appRouter.go(AppRoutes.namesEntry);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [storageServiceProvider.overrideWithValue(storage)],
            child: MaterialApp.router(
              routerConfig: appRouter,
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
        expect(tester.takeException(), isNull);
        expect(find.byType(TextField), findsNothing);
        await tester.ensureVisible(find.text('Try with example names'));
        await tester.pumpAndSettle();
        expect(
          find.text('Try with example names').hitTestable(),
          findsOneWidget,
        );
        expect(tester.testTextInput.isVisible, isFalse);
      },
    );
  }

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
