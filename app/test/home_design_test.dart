import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/router/app_router.dart';
import 'fakes/test_app.dart';
import 'package:flyprox_app/screens/home/main_tab.dart';
import 'package:flyprox_app/screens/voting/vote_screen.dart';
import 'package:flyprox_app/screens/voting/timer_screen.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/invitation_service.dart';
import 'package:flyprox_app/services/local_game_service.dart';
import 'package:flyprox_app/services/onboarding_details_service.dart';
import 'package:flyprox_app/services/storage_service.dart';
import 'package:flyprox_app/services/subscription_service.dart';
import 'fakes/eligible_player.dart';
import 'fakes/fake_gateway.dart';
import 'fakes/social_storage.dart';

class FakeCampusMode extends OnboardingDetailsService {
  FakeCampusMode(this.mode)
    : super(ApiService(SessionStorage()), SessionStorage());
  final ({bool school, int joined, int threshold}) mode;
  @override
  Future<bool> votingAllowed() async => true;
  @override
  Future<({bool school, int joined, int threshold})?> votingMode() async =>
      mode;
}

void main() {
  setUp(setUpTestApp);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    markEligiblePlayer();
    await SubscriptionService.instance.resetForTest();
    SubscriptionService.instance.debugGateway(FakeGateway());
    await LocalGameService.instance.savePlayerAndFriends(
      playerName: 'Michael',
      friends: ['Alex', 'Sam', 'Jordan', 'Taylor'],
    );
  });
  Future<void> mountHome(WidgetTester tester, double scale) async {
    final storage = StorageService();
    await storage.init();
    testAppRouter.go(AppRoutes.home);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [storageServiceProvider.overrideWithValue(storage)],
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

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'ready home fits 320px at text scale $scale and starts a real round',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await mountHome(tester, scale);
        expect(find.text('Who’s most\nlikely to…?'), findsOneWidget);
        expect(find.text('Quiz is ready'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Go to quiz'));
        await tester.pumpAndSettle();
        expect(find.text('Go to quiz').hitTestable(), findsOneWidget);
        await tester.tap(find.text('Go to quiz'));
        await tester.pumpAndSettle();
        expect(find.byType(VoteScreen), findsOneWidget);
        expect(find.text('Question 1 of 12'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('school banner explains contacts-only play and opens invites', (
    tester,
  ) async {
    final storage = SessionStorage();
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const MainTab()),
        GoRoute(
          path: AppRoutes.invite,
          builder: (_, _) => const Scaffold(body: Text('Invite destination')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          onboardingDetailsProvider.overrideWith(
            (ref) => FakeCampusMode((school: false, joined: 1, threshold: 5)),
          ),
          starBalanceProvider.overrideWith((ref) async => 42),
          invitationServiceProvider.overrideWith(
            (ref) => InvitationService(ApiService(storage), storage),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unlock campus quizzes'), findsOneWidget);
    expect(find.text('1 of 5 joined'), findsOneWidget);
    expect(find.textContaining('you play with your contacts'), findsOneWidget);
    await tester.ensureVisible(find.text('Invite classmates'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Invite classmates'));
    await tester.pumpAndSettle();
    expect(find.text('Invite destination'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'home preserves active cooldown instead of showing a ready action',
    (tester) async {
      await LocalGameService.instance.completeRound();
      await mountHome(tester, 1);
      expect(find.text('A little break.'), findsOneWidget);
      expect(find.text('Go to quiz'), findsNothing);
      await tester.tap(find.text('Details'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(TimerScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
