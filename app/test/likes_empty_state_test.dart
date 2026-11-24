import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/router/app_router.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/local_game_service.dart';
import 'package:flyprox_app/services/social_service.dart';
import 'package:flyprox_app/services/subscription_service.dart';
import 'fakes/eligible_player.dart';
import 'fakes/fake_gateway.dart';
import 'fakes/social_storage.dart';
import 'fakes/test_app.dart';

class _LikesSocial extends SocialService {
  _LikesSocial(super.api, super.storage);
  Map<String, dynamic> likesData = {'votesReceived': 0, 'items': []};
  @override
  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? data,
  }) async => path == '/likes' || path.startsWith('/likes?')
      ? likesData
      : super.request(path, method: method, data: data);
}

Future<void> _pumpRoute(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _mount(
  WidgetTester tester,
  SessionStorage storage,
  _LikesSocial social,
) async {
  testAppRouter.go(AppRoutes.likesEmpty);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
        socialServiceProvider.overrideWithValue(social),
      ],
      child: MaterialApp.router(routerConfig: testAppRouter),
    ),
  );
  await _pumpRoute(tester);
}

void main() {
  setUp(setUpTestApp);
  setUp(markEligiblePlayer);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SubscriptionService.instance.resetForTest();
    SubscriptionService.instance.debugGateway(FakeGateway());
    await LocalGameService.instance.savePlayerAndFriends(
      playerName: 'Player',
      friends: ['Alex', 'Sam', 'Jordan', 'Taylor'],
    );
  });

  testWidgets('zero likes show the motivational card without a close button', (
    tester,
  ) async {
    final storage = SessionStorage();
    final social = _LikesSocial(ApiService(storage), storage);
    await _mount(tester, storage, social);

    expect(find.text('Likes'), findsOneWidget);
    expect(find.text('Your future likes'), findsOneWidget);
    expect(find.text('EMPTY FOR NOW'), findsOneWidget);
    expect(
      find.text(
        'When someone picks you in a vote, all your likes will appear here. '
        'Want more votes? Play more polls.',
      ),
      findsOneWidget,
    );
    expect(find.text('Go to polls'), findsOneWidget);
    expect(find.text('0 received likes'), findsNothing);
    expect(find.byTooltip('Close'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('CTA button navigates to the home polls', (tester) async {
    final storage = SessionStorage();
    final social = _LikesSocial(ApiService(storage), storage);
    await _mount(tester, storage, social);

    await tester.ensureVisible(find.text('Go to polls'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Go to polls'));
    await _pumpRoute(tester);
    expect(
      testAppRouter.routeInformationProvider.value.uri.path,
      AppRoutes.home,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('guest state stays unchanged', (tester) async {
    final storage = SessionStorage()..token = null;
    final social = _LikesSocial(ApiService(storage), storage);
    await _mount(tester, storage, social);

    expect(find.text('Sign in to see your Likes.'), findsOneWidget);
    expect(find.text('EMPTY FOR NOW'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('received likes still render the list', (tester) async {
    final storage = SessionStorage();
    final social = _LikesSocial(ApiService(storage), storage)
      ..likesData = {
        'votesReceived': 2,
        'items': [
          {'question': 'Who is funniest?', 'occurredAt': null},
        ],
      };
    await _mount(tester, storage, social);

    expect(find.text('2 received likes'), findsOneWidget);
    expect(find.text('Who is funniest?'), findsOneWidget);
    expect(find.text('EMPTY FOR NOW'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
