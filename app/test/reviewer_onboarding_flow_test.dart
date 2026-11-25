import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinput/pinput.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/router/app_router.dart';
import 'package:flyprox_app/screens/registration/profile_details_screen.dart';
import 'package:flyprox_app/screens/registration/school_setup_screen.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/age_gate_service.dart';
import 'package:flyprox_app/services/content_service.dart';
import 'package:flyprox_app/services/local_game_service.dart';
import 'package:flyprox_app/services/onboarding_details_service.dart';
import 'package:flyprox_app/services/phone_auth_service.dart';
import 'package:flyprox_app/services/phone_auth_driver.dart';
import 'package:flyprox_app/services/push_service.dart';
import 'package:flyprox_app/services/storage_service.dart';
import 'fakes/eligible_player.dart';
import 'fakes/fake_age_gate_store.dart';
import 'fakes/fake_phone_auth_driver.dart';
import 'fakes/fake_push_driver.dart';
import 'fakes/test_app.dart';

class ReviewFixture {
  late StorageService storage;
  late ApiService api;
  late OnboardingDetailsService onboarding;
  final phone = FakePhoneAuthDriver();
  final requests = <RequestOptions>[];
  String? username;
  bool reviewer = true, failIdentity = false, failOnboarding = false;
  Completer<void>? holdIdentity;
  Completer<void>? holdOnboarding;

  Future<void> mount(
    WidgetTester tester, {
    bool authenticated = false,
    String route = AppRoutes.otp,
    String? stage,
  }) async {
    storage = StorageService();
    await storage.init();
    if (authenticated) {
      await storage.saveToken('review-session');
      await storage.saveReviewerAccess(reviewer);
    }
    api = ApiService(storage);
    onboarding = OnboardingDetailsService(api, storage);
    api.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (r, h) async {
          requests.add(r);
          Map<String, dynamic> body = {};
          if (r.path == '/api/auth/firebase') {
            body = {
              'token': 'review-session',
              'reviewerSkipsAllowed': reviewer,
              'isNewUser': true,
            };
          } else if (r.path == '/api/onboarding') {
            if (holdOnboarding != null) await holdOnboarding!.future;
            if (failOnboarding) {
              h.reject(
                DioException(
                  requestOptions: r,
                  type: DioExceptionType.connectionError,
                ),
              );
              return;
            }
            body = {
              'status': 'pending',
              'country': 'US',
              'firstName': '',
              'lastName': '',
              'gender': null,
              'profileComplete': false,
              'school': null,
              'graduationYear': null,
              'reviewerSkipsAllowed': reviewer,
              'votingAllowed': reviewer,
            };
          } else if (r.path == '/api/social/me') {
            if (holdIdentity != null) await holdIdentity!.future;
            if (failIdentity) {
              h.reject(
                DioException(
                  requestOptions: r,
                  type: DioExceptionType.connectionError,
                ),
              );
              return;
            }
            body = {
              'username': username,
              'firstName': '',
              'lastName': '',
              'votesReceived': 0,
            };
          } else if (r.path == '/api/social/handle') {
            username = (r.data as Map)['username'] as String;
            body = {'username': username};
          } else if (r.path.contains('/list')) {
            body = {'users': [], 'nextCursor': null};
          } else if (r.path.contains('/summary')) {
            body = {'friendsCount': 0, 'incomingCount': 0};
          } else if (r.path == '/api/users/profile') {
            body = {'starsCount': 0};
          }
          h.resolve(Response(requestOptions: r, data: body));
        },
      ),
    );
    if (stage != null)
      await onboarding.draft({'stage': stage, 'status': 'pending'});
    final push = FakePushDriver(available: false);
    addTearDown(push.dispose);
    testAppRouter.go(
      route,
      extra: route == AppRoutes.otp
          ? {
              'phone': reviewer ? '+16505551234' : '+16505550137',
              'verificationId': 'vid-1',
              'country': 'US',
            }
          : null,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          apiServiceProvider.overrideWithValue(api),
          onboardingDetailsProvider.overrideWith((ref) => onboarding),
          phoneAuthServiceProvider.overrideWithValue(
            PhoneAuthService(api: api, storage: storage, driver: phone),
          ),
          pushServiceProvider.overrideWithValue(
            PushService(driver: push, api: api),
          ),
        ],
        child: MaterialApp.router(routerConfig: testAppRouter),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
}

void expectNoHiddenForms() {
  expect(find.byType(ProfileDetailsScreen), findsNothing);
  expect(find.byType(SchoolSetupScreen), findsNothing);
}

void main() {
  setUp(setUpTestApp);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    markEligiblePlayer();
    ContentService.instance.debugClear();
    ContentService.instance.debugSetOverrides({
      'example_names_enabled': 'true',
      'guest_enabled': 'true',
    });
  });
  tearDown(() => ContentService.instance.debugClear());

  testWidgets(
    'reviewer OTP goes directly to contacts; examples never revisit either hidden form',
    (tester) async {
      final f = ReviewFixture();
      await f.mount(tester);
      tester.widget<Pinput>(find.byType(Pinput)).controller!.text = '123456';
      await tester.pumpAndSettle();
      expect(f.phone.lastSmsCode, '123456');
      expect(
        testAppRouter.routeInformationProvider.value.uri.path,
        AppRoutes.namesEntry,
      );
      expectNoHiddenForms();
      final examples = find.text(
        ContentService.instance.text('example_names_button'),
      );
      await tester.ensureVisible(examples);
      await tester.tap(examples);
      await tester.pumpAndSettle();
      expect(
        testAppRouter.routeInformationProvider.value.uri.path,
        AppRoutes.username,
      );
      expectNoHiddenForms();
      await tester.enterText(
        find.byKey(const Key('onboarding-username')),
        'reviewer_handle',
      );
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(
        testAppRouter.routeInformationProvider.value.uri.path,
        AppRoutes.home,
      );
      expect(await f.onboarding.votingAllowed(), isTrue);
      expect(
        f.requests.where(
          (r) => r.path == '/api/onboarding' && r.method != 'GET',
        ),
        isEmpty,
      );
      testAppRouter.go(AppRoutes.profile);
      await tester.pumpAndSettle();
      expect(find.text('@reviewer_handle'), findsWidgets);
      expect(find.text('Edit profile'), findsOneWidget);
      expect(find.textContaining('Couldn’t load your campus'), findsNothing);
      expect(find.textContaining('Class of'), findsNothing);
      expectNoHiddenForms();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ordinary test phone retains required personal details and campus onboarding',
    (tester) async {
      final f = ReviewFixture()..reviewer = false;
      await f.mount(tester);
      tester.widget<Pinput>(find.byType(Pinput)).controller!.text = '123456';
      await tester.pumpAndSettle();
      expect(
        testAppRouter.routeInformationProvider.value.uri.path,
        AppRoutes.profileDetails,
      );
      expect(find.byType(ProfileDetailsScreen), findsOneWidget);
      expect(await f.onboarding.votingAllowed(), isFalse);
    },
  );

  testWidgets(
    'all hidden-form deep links and stale stages redirect reviewer to contacts',
    (tester) async {
      final f = ReviewFixture();
      await f.mount(
        tester,
        authenticated: true,
        route: AppRoutes.profileDetails,
        stage: 'school',
      );
      for (final stage in [
        'profile',
        'school',
        'waiting',
        'username',
        'done',
      ]) {
        await f.onboarding.draft({'stage': stage});
        for (final route in [
          AppRoutes.profileDetails,
          AppRoutes.schoolSetup,
          AppRoutes.schoolWaiting,
        ]) {
          testAppRouter.go(route);
          await tester.pumpAndSettle();
          expect(
            testAppRouter.routeInformationProvider.value.uri.path,
            AppRoutes.namesEntry,
          );
          expectNoHiddenForms();
        }
      }
      await tester.tap(find.byTooltip('Back to login'));
      await tester.pumpAndSettle();
      expect(
        testAppRouter.routeInformationProvider.value.uri.path,
        AppRoutes.phone,
      );
      expectNoHiddenForms();
    },
  );

  testWidgets(
    'returning reviewer restores canonical username without showing or saving username form',
    (tester) async {
      await LocalGameService.instance.savePlayerAndFriends(
        playerName: 'local_round_owner',
        friends: ['Alex', 'Sam', 'Jordan', 'Taylor'],
      );
      await LocalGameService.instance.saveUsername('wrong_local_name');
      await LocalGameService.instance.setUsernameSetupPending(true);
      final f = ReviewFixture()..username = 'server_handle';
      await f.mount(
        tester,
        authenticated: true,
        route: AppRoutes.username,
        stage: 'contacts',
      );
      expect(find.text('Choose your username'), findsNothing);
      expect(
        testAppRouter.routeInformationProvider.value.uri.path,
        AppRoutes.home,
      );
      expect(await LocalGameService.instance.getUsername(), 'server_handle');
      expect(await LocalGameService.instance.isUsernameSetupPending(), isFalse);
      expect(f.requests.where((r) => r.path == '/api/social/handle'), isEmpty);
      expectNoHiddenForms();
    },
  );

  testWidgets(
    'identity failure gives Retry instead of a generated username and recovers',
    (tester) async {
      await LocalGameService.instance.savePlayerAndFriends(
        playerName: 'local_round_owner',
        friends: ['Alex', 'Sam', 'Jordan', 'Taylor'],
      );
      final f = ReviewFixture()
        ..username = 'server_handle'
        ..failIdentity = true;
      await f.mount(tester, authenticated: true, route: AppRoutes.username);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byKey(const Key('onboarding-username')), findsNothing);
      expect(f.requests.where((r) => r.path == '/api/social/handle'), isEmpty);
      f.failIdentity = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(
        testAppRouter.routeInformationProvider.value.uri.path,
        AppRoutes.home,
      );
      expect(await LocalGameService.instance.getUsername(), 'server_handle');
    },
  );
  testWidgets(
    'reviewer still passes age gate before contacts, never the two hidden forms',
    (tester) async {
      AgeGateService.instance.debugStore(InMemoryAgeGateStore());
      AgeGateService.instance.statusListenable.value = AgeGateStatus.unknown;
      final f = ReviewFixture();
      await f.mount(tester);
      tester.widget<Pinput>(find.byType(Pinput)).controller!.text = '123456';
      await tester.pumpAndSettle();
      expect(
        testAppRouter.routeInformationProvider.value.uri.path,
        AppRoutes.age,
      );
      expectNoHiddenForms();
      await tester.tap(find.text('18+'));
      await tester.pump();
      await tester.ensureVisible(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(
        testAppRouter.routeInformationProvider.value.uri.path,
        AppRoutes.namesEntry,
      );
      expectNoHiddenForms();
    },
  );

  testWidgets(
    'late username response cannot restore reviewer name into another session',
    (tester) async {
      await LocalGameService.instance.savePlayerAndFriends(
        playerName: 'local_round_owner',
        friends: ['Alex', 'Sam', 'Jordan', 'Taylor'],
      );
      await LocalGameService.instance.saveUsername('original_local');
      final pending = Completer<void>();
      final f = ReviewFixture()
        ..username = 'old_reviewer_handle'
        ..holdIdentity = pending;
      await f.mount(
        tester,
        authenticated: true,
        route: AppRoutes.username,
        stage: 'contacts',
      );
      await f.storage.saveToken('ordinary-session');
      expect(f.storage.reviewerSkipsAllowed, isFalse);
      pending.complete();
      await tester.pumpAndSettle();
      expect(await LocalGameService.instance.getUsername(), 'original_local');
      expect(f.requests.where((r) => r.path == '/api/social/handle'), isEmpty);
      expect(find.text('Retry'), findsOneWidget);
    },
  );
  testWidgets(
    'typed reviewer phone and Firebase test code hide both forms from start to contacts',
    (tester) async {
      final f = ReviewFixture();
      await f.mount(tester, route: AppRoutes.phone);
      expect(find.text('Continue without login'), findsNothing);
      await tester.enterText(find.byType(TextField), '6505551234');
      await tester.ensureVisible(find.text('Send code'));
      await tester.pump();
      await tester.tap(find.text('Send code'));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        expectNoHiddenForms();
      }
      expect(f.phone.lastPhone, '+16505551234');
      expect(find.byType(Pinput), findsOneWidget);
      tester.widget<Pinput>(find.byType(Pinput)).controller!.text = '123456';
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        expectNoHiddenForms();
      }
      expect(
        testAppRouter.routeInformationProvider.value.uri.path,
        AppRoutes.namesEntry,
      );
      expect(f.phone.lastSmsCode, '123456');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reviewer automatic Firebase verification also hides both forms',
    (tester) async {
      final f = ReviewFixture();
      f.phone.codeResult = const CodeSent(autoIdToken: 'verified-auto-token');
      await f.mount(tester, route: AppRoutes.phone);
      await tester.enterText(find.byType(TextField), '6505551234');
      await tester.ensureVisible(find.text('Send code'));
      await tester.pump();
      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();
      expect(
        testAppRouter.routeInformationProvider.value.uri.path,
        AppRoutes.namesEntry,
      );
      expectNoHiddenForms();
      expect(tester.takeException(), isNull);
    },
  );

  for (final route in [AppRoutes.phone, AppRoutes.otp]) {
    testWidgets(
      'reviewer Continue without login on $route goes to contacts then examples without hidden forms',
      (tester) async {
        final f = ReviewFixture()..username = 'existing_review_handle';
        await f.mount(
          tester,
          authenticated: true,
          route: route,
          stage: 'profile',
        );
        final skip = find.text('Continue without login');
        await tester.ensureVisible(skip);
        await tester.pump();
        await tester.tap(skip);
        await tester.pumpAndSettle();
        expect(
          testAppRouter.routeInformationProvider.value.uri.path,
          AppRoutes.namesEntry,
        );
        expectNoHiddenForms();
        final examples = find.text(
          ContentService.instance.text('example_names_button'),
        );
        await tester.ensureVisible(examples);
        await tester.pump();
        await tester.tap(examples);
        await tester.pumpAndSettle();
        expect(
          testAppRouter.routeInformationProvider.value.uri.path,
          AppRoutes.home,
        );
        expect(find.text('Choose your username'), findsNothing);
        expectNoHiddenForms();
        expect(tester.takeException(), isNull);
        expect(
          f.requests.where((r) => r.path == '/api/social/handle'),
          isEmpty,
        );
      },
    );

    testWidgets(
      'Continue without login on $route handles server failure without uncaught errors or hidden forms',
      (tester) async {
        final f = ReviewFixture()..failOnboarding = true;
        await f.mount(tester, authenticated: true, route: route);
        final skip = find.text('Continue without login');
        await tester.ensureVisible(skip);
        await tester.pump();
        await tester.tap(skip);
        await tester.pumpAndSettle();
        expectNoHiddenForms();
        expect(tester.takeException(), isNull);
        expect(testAppRouter.routeInformationProvider.value.uri.path, route);
        expect(
          find.text('Couldn’t continue. Check your connection and try again.'),
          findsOneWidget,
        );
        f.failOnboarding = false;
        await tester.tap(skip);
        await tester.pumpAndSettle();
        expect(
          testAppRouter.routeInformationProvider.value.uri.path,
          AppRoutes.namesEntry,
        );
        expectNoHiddenForms();
      },
    );
  }

  testWidgets(
    'remembered reviewer phone without verified session grants no guest exit or example access',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'reviewer_seen_v1': true,
        'registered_phone': '+16505551234',
      });
      final f = ReviewFixture();
      await f.mount(tester, route: AppRoutes.phone);
      expect(f.storage.reviewerSkipsAllowed, isFalse);
      expect(find.text('Continue without login'), findsNothing);
      await tester.enterText(find.byType(TextField), '6505551234');
      await tester.pump();
      expect(find.text('Continue without login'), findsNothing);
    },
  );

  testWidgets(
    'restart with completed reviewer onboarding and stale local name opens Home and correct profile',
    (tester) async {
      await LocalGameService.instance.savePlayerAndFriends(
        playerName: 'local_round_owner',
        friends: ['Alex', 'Sam', 'Jordan', 'Taylor'],
      );
      await LocalGameService.instance.saveUsername('wrong_local_name');
      final f = ReviewFixture()..username = 'server_handle';
      await f.mount(
        tester,
        authenticated: true,
        route: AppRoutes.splash,
        stage: 'done',
      );
      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();
      expect(
        testAppRouter.routeInformationProvider.value.uri.path,
        AppRoutes.home,
      );
      testAppRouter.go(AppRoutes.profile);
      await tester.pumpAndSettle();
      expect(find.text('@server_handle'), findsWidgets);
      expect(find.text('@wrong_local_name'), findsNothing);
      expectNoHiddenForms();
      expect(tester.takeException(), isNull);
    },
  );
  for (final route in [AppRoutes.phone, AppRoutes.otp]) {
    testWidgets(
      'reviewer guest button on $route prevents duplicate pending transitions',
      (tester) async {
        final pending = Completer<void>();
        final f = ReviewFixture()..holdOnboarding = pending;
        await f.mount(tester, authenticated: true, route: route);
        final skip = find.text('Continue without login');
        await tester.ensureVisible(skip);
        await tester.pump();
        await tester.tap(skip);
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        final button = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Continue without login'),
        );
        expect(button.onPressed, isNull);
        await tester.tap(skip);
        await tester.pump();
        expect(f.requests.where((r) => r.path == '/api/onboarding').length, 1);
        expectNoHiddenForms();
        pending.complete();
        await tester.pumpAndSettle();
        expect(
          testAppRouter.routeInformationProvider.value.uri.path,
          AppRoutes.namesEntry,
        );
        expectNoHiddenForms();
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'reviewer below minimum age stays blocked even via hidden-form or Home links',
    (tester) async {
      AgeGateService.instance.statusListenable.value = AgeGateStatus.blocked;
      final f = ReviewFixture();
      await f.mount(tester, authenticated: true, route: AppRoutes.phone);
      for (final route in [
        AppRoutes.home,
        AppRoutes.profileDetails,
        AppRoutes.schoolSetup,
      ]) {
        testAppRouter.go(route);
        await tester.pumpAndSettle();
        expect(
          testAppRouter.routeInformationProvider.value.uri.path,
          AppRoutes.ageBlocked,
        );
        expectNoHiddenForms();
        expect(tester.takeException(), isNull);
      }
    },
  );
}
