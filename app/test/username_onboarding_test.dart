import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/router/app_router.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/local_game_service.dart';
import 'package:flyprox_app/services/push_service.dart';
import 'package:flyprox_app/services/storage_service.dart';
import 'package:flyprox_app/services/onboarding_details_service.dart';
import 'package:flyprox_app/theme/app_theme.dart';
import 'fakes/eligible_player.dart';
import 'fakes/fake_push_driver.dart';
import 'fakes/test_app.dart';

class _StalledPushDriver extends FakePushDriver {
  @override
  Future<bool> isAuthorized() => Completer<bool>().future;
}

void main() {
  setUp(setUpTestApp);
  setUp(markEligiblePlayer);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalGameService.instance.savePlayerAndFriends(
      playerName: 'user234432',
      friends: ['Alex', 'Sam', 'Jordan', 'Taylor'],
    );
    await LocalGameService.instance.setUsernameSetupPending(true);
    await LocalGameService.instance.saveFullName('Aman', 'Smith');
    await LocalGameService.instance.saveUsername('user234432');
  });

  Future<void> mount(
    WidgetTester tester, {
    bool loggedIn = false,
    String route = AppRoutes.username,
    double scale = 1,
    String? stage,
    void Function(RequestOptions, RequestInterceptorHandler)? handle,
    FakePushDriver? pushDriver,
    bool stallInvitation = false,
  }) async {
    final storage = StorageService();
    await storage.init();
    if (loggedIn) await storage.saveToken('test-session');
    final api = ApiService(storage);
    api.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          if (request.path == '/api/social/me') {
            handler.resolve(
              Response(requestOptions: request, data: {'username': null}),
            );
            return;
          }
          if (stallInvitation && request.path == '/api/invites/claim') return;
          if (request.path == '/api/social/handle') {
            if (handle != null) {
              handle(request, handler);
              return;
            }
            handler.resolve(
              Response(
                requestOptions: request,
                data: {'username': (request.data as Map)['username']},
              ),
            );
          } else {
            handler.resolve(
              Response(requestOptions: request, data: <String, dynamic>{}),
            );
          }
        },
      ),
    );
    final driver = pushDriver ?? FakePushDriver();
    final details = OnboardingDetailsService(api, storage);
    if (stage != null) {
      await details.draft({'stage': stage, 'status': 'selected'});
    }
    addTearDown(driver.dispose);
    testAppRouter.go(route);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          apiServiceProvider.overrideWithValue(api),
          onboardingDetailsProvider.overrideWith((ref) => details),
          pushServiceProvider.overrideWithValue(
            PushService(driver: driver, api: ApiService(storage)),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: testAppRouter,
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'stalled optional invitation and push checks do not trap username',
    (tester) async {
      await mount(
        tester,
        loggedIn: true,
        stage: 'username',
        pushDriver: _StalledPushDriver(),
        stallInvitation: true,
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Never miss a vote'), findsOneWidget);
      expect(await LocalGameService.instance.isUsernameSetupPending(), isFalse);
    },
  );

  testWidgets(
    'school-mode username can go back to campus and keep typed draft',
    (tester) async {
      await mount(tester, stage: 'username');
      await tester.enterText(
        find.byKey(const Key('onboarding-username')),
        'my_draft',
      );
      await tester.tap(find.byTooltip('Back to campus'));
      await tester.pumpAndSettle();
      expect(
        testAppRouter.routeInformationProvider.value.uri.path,
        AppRoutes.schoolSetup,
      );
      testAppRouter.go(AppRoutes.username);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('onboarding-username')))
            .controller!
            .text,
        'my_draft',
      );
    },
  );

  testWidgets(
    'contacts branch supports back from username then back to campus',
    (tester) async {
      await mount(tester, stage: 'contacts');
      await tester.tap(find.byTooltip('Back to contacts'));
      await tester.pumpAndSettle();
      expect(find.text('Add your contacts'), findsOneWidget);
      await tester.tap(find.byTooltip('Back to campus'));
      await tester.pumpAndSettle();
      expect(
        testAppRouter.routeInformationProvider.value.uri.path,
        AppRoutes.schoolSetup,
      );
    },
  );

  testWidgets('stalled username request times out and permits retry', (
    tester,
  ) async {
    var attempts = 0;
    await mount(
      tester,
      loggedIn: true,
      handle: (request, handler) {
        attempts++;
        if (attempts == 1) return;
        handler.resolve(
          Response(requestOptions: request, data: {'username': 'retry_user'}),
        );
      },
    );
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();
    expect(
      find.text('Connection timed out. Please try again.'),
      findsOneWidget,
    );
    expect(await LocalGameService.instance.isUsernameSetupPending(), isTrue);
    await tester.enterText(
      find.byKey(const Key('onboarding-username')),
      'retry_user',
    );
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Never miss a vote'), findsOneWidget);
    expect(attempts, 2);
  });

  testWidgets(
    'back cancels saving and late response cannot finish onboarding',
    (tester) async {
      RequestOptions? pending;
      RequestInterceptorHandler? response;
      await mount(
        tester,
        loggedIn: true,
        stage: 'username',
        handle: (request, handler) {
          pending = request;
          response = handler;
        },
      );
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(find.text('Saving…'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      expect(response, isNotNull);
      await tester.ensureVisible(find.byTooltip('Back to campus'));
      await tester.tap(find.byTooltip('Back to campus'));
      await tester.pumpAndSettle();
      response!.resolve(
        Response(requestOptions: pending!, data: {'username': 'late_user'}),
      );
      await tester.pump(const Duration(seconds: 12));
      await tester.pumpAndSettle();
      expect(
        testAppRouter.routeInformationProvider.value.uri.path,
        AppRoutes.schoolSetup,
      );
      expect(await LocalGameService.instance.isUsernameSetupPending(), isTrue);
      expect(await LocalGameService.instance.getUsername(), 'user234432');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('taken username shows server error and allows correction', (
    tester,
  ) async {
    var attempts = 0;
    await mount(
      tester,
      loggedIn: true,
      handle: (request, handler) {
        if (++attempts == 1) {
          handler.reject(
            DioException(
              requestOptions: request,
              type: DioExceptionType.badResponse,
              response: Response(
                requestOptions: request,
                statusCode: 409,
                data: {'message': 'Username is already taken.'},
              ),
            ),
          );
        } else {
          handler.resolve(
            Response(requestOptions: request, data: {'username': 'free_user'}),
          );
        }
      },
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Username is already taken.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('onboarding-username')),
      'free_user',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Never miss a vote'), findsOneWidget);
  });

  testWidgets('valid nickname persists in profile, never in voting cards', (
    tester,
  ) async {
    await mount(tester);
    final field = find.byKey(const Key('onboarding-username'));
    expect(tester.widget<TextFormField>(field).controller!.text, 'user234432');
    for (final invalid in [
      '',
      'ab',
      'bad name',
      'имя',
      List.filled(33, 'a').join(),
    ]) {
      await tester.enterText(field, invalid);
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Choose your username'), findsOneWidget);
      expect(await LocalGameService.instance.isUsernameSetupPending(), isTrue);
    }
    await tester.enterText(field, 'aman_23');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    final game = LocalGameService.instance;
    expect(await game.getUsername(), 'aman_23');
    expect(await game.getPlayerName(), 'Aman Smith');
    expect(await game.isUsernameSetupPending(), isFalse);
    expect(
      testAppRouter.routeInformationProvider.value.uri.path,
      AppRoutes.home,
    );
    for (final question in await game.generateRound(languageCode: 'en')) {
      expect(
        question.optionNames,
        unorderedEquals(['Alex', 'Sam', 'Jordan', 'Taylor']),
      );
    }
    testAppRouter.go(AppRoutes.profile);
    await tester.pumpAndSettle();
    expect(find.text('@aman_23'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    testAppRouter = createAppRouter();
    addTearDown(testAppRouter.dispose);
    await mount(tester, route: AppRoutes.splash);
    expect(
      testAppRouter.routeInformationProvider.value.uri.path,
      AppRoutes.home,
    );
  });

  testWidgets(
    'unfinished nickname setup resumes after a new router is created',
    (tester) async {
      await mount(tester);
      await tester.pumpWidget(const SizedBox());
      testAppRouter = createAppRouter();
      addTearDown(testAppRouter.dispose);
      await mount(tester, route: AppRoutes.splash);
      expect(find.text('Choose your username'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('onboarding-username')))
            .controller!
            .text,
        'user234432',
      );
    },
  );

  testWidgets(
    'signed-in player gets notification prompt after nickname, not before',
    (tester) async {
      await mount(tester, loggedIn: true);
      expect(find.text('Never miss a vote'), findsNothing);
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Never miss a vote'), findsOneWidget);
      expect(await LocalGameService.instance.getUsername(), 'user234432');
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets('nickname form works at 320px, scale $scale with keyboard', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await mount(tester, scale: scale);
      await tester.enterText(
        find.byKey(const Key('onboarding-username')),
        'test_user',
      );
      await tester.ensureVisible(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Continue').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
