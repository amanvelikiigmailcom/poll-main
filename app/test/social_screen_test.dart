import 'package:flyprox_app/theme/app_theme.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/screens/social/social_screen.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/social_service.dart';
import 'package:flyprox_app/widgets/common/app_shell.dart';
import 'fakes/social_storage.dart';

class FakeSocial extends SocialService {
  FakeSocial(super.api, super.storage);
  final results = <String, Completer<Map<String, dynamic>>>{};
  final searches = <String>[];
  Map<String, dynamic> suggestionData = {};
  int suggestionCalls = 0;
  @override
  Future<Map<String, dynamic>> suggestions() async {
    suggestionCalls++;
    return suggestionData;
  }

  @override
  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? data,
  }) async => path == '/me'
      ? {'username': 'test_user'}
      : super.request(path, method: method, data: data);
  @override
  Future<Map<String, dynamic>> search(String username, {String? cursor}) {
    searches.add(username);
    return results.putIfAbsent(username, Completer.new).future;
  }

  @override
  Future<Map<String, dynamic>> list(String kind, {String? cursor}) async => {
    'users': [
      {'id': 'one', 'username': 'alex_123', 'relationship': 'friends'},
    ],
  };
}

void main() {
  test('game belongs to Home; each other destination has its own tab', () {
    for (final route in ['/home', '/vote', '/timer', '/star-received']) {
      expect(AppShell.indexFor(route), 0);
    }
    expect(AppShell.indexFor('/home/search'), 1);
    expect(AppShell.indexFor('/likes-empty'), 2);
    expect(AppShell.indexFor('/home/profile'), 3);
    expect(AppShell.indexFor('/friends'), 4);
    expect(AppShell.indexFor('/blocked-users'), 4);
  });
  Future<void> mount(
    WidgetTester tester,
    SessionStorage storage,
    FakeSocial social, {
    SocialPage page = SocialPage.search,
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          socialServiceProvider.overrideWithValue(social),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(430, 932),
              textScaler: TextScaler.linear(scale),
            ),
            child: SocialScreen(page: page),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'search fits 320px at text scale $scale without fake recommendations',
      (tester) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final storage = SessionStorage();
        final social = FakeSocial(ApiService(storage), storage);
        await mount(tester, storage, social, scale: scale);
        await tester.scrollUntilVisible(
          find.text('Friends of friends'),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Friends of friends'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('From your campus'),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('From your campus'), findsOneWidget);
        expect(social.searches, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'suggestions expand in memory, show request states and hide rows',
    (tester) async {
      final storage = SessionStorage();
      final social = FakeSocial(ApiService(storage), storage)
        ..suggestionData = {
          'friendsOfFriends': [
            {
              'id': 'via',
              'username': 'via_friend',
              'mutualCount': 3,
              'relationship': 'incoming',
            },
          ],
          'campus': [
            for (var i = 0; i < 6; i++)
              {
                'id': 'campus$i',
                'username': 'campus_$i',
                'relationship': i == 0 ? 'outgoing' : 'none',
              },
          ],
        };
      await mount(tester, storage, social);
      expect(find.text('3 mutual friends'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('From your campus'),
        180,
        scrollable: scrollable,
      );
      expect(find.text('Request sent'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('See more (1)'),
        220,
        scrollable: scrollable,
      );
      expect(find.text('@campus_5'), findsNothing);
      final before = social.suggestionCalls;
      await tester.ensureVisible(find.text('See more (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('See more (1)'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('@campus_5'));
      expect(social.suggestionCalls, before);
      final row = find.byKey(const ValueKey('suggestion-campus5'));
      final hide = find.descendant(of: row, matching: find.text('Hide'));
      await tester.ensureVisible(hide);
      await tester.pumpAndSettle();
      await tester.tap(hide);
      await tester.pumpAndSettle();
      expect(find.text('@campus_5'), findsNothing);
      await storage.clearToken();
      await tester.pumpAndSettle();
      expect(find.text('From your campus'), findsNothing);
    },
  );
  testWidgets(
    'search starts at two characters after 300ms; malformed handles stay local',
    (tester) async {
      final storage = SessionStorage();
      final social = FakeSocial(ApiService(storage), storage);
      await mount(tester, storage, social);
      final field = find.byType(TextField);
      await tester.enterText(field, 'a');
      await tester.pump(const Duration(milliseconds: 350));
      expect(social.searches, isEmpty);
      await tester.enterText(field, 'ab');
      await tester.pump(const Duration(milliseconds: 299));
      expect(social.searches, isEmpty);
      await tester.pump(const Duration(milliseconds: 2));
      expect(social.searches, ['ab']);
      social.results['ab']!.complete({'users': []});
      await tester.pumpAndSettle();
      await tester.enterText(field, '@bad name');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Enter 2–32 username characters'),
        findsOneWidget,
      );
      expect(social.searches, ['ab']);
      await tester.enterText(field, '@good_name');
      await tester.pump(const Duration(milliseconds: 350));
      social.results['@good_name']!.complete({'users': []});
      await tester.pumpAndSettle();
      expect(social.searches, ['ab', '@good_name']);
      expect(
        find.textContaining('Enter 2–32 username characters'),
        findsNothing,
      );
    },
  );
  testWidgets(
    'new search ignores stale results and account change clears private data',
    (tester) async {
      final storage = SessionStorage();
      final social = FakeSocial(ApiService(storage), storage);
      await mount(tester, storage, social);
      await tester.enterText(find.byType(TextField), 'first_user');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.enterText(find.byType(TextField), 'second_user');
      await tester.pump(const Duration(milliseconds: 500));
      social.results['second_user']!.complete({
        'users': [
          {'id': 'two', 'username': 'second_user', 'relationship': 'none'},
        ],
      });
      await tester.pumpAndSettle();
      social.results['first_user']!.complete({
        'users': [
          {'id': 'one', 'username': 'first_user', 'relationship': 'none'},
        ],
      });
      await tester.pumpAndSettle();
      expect(find.text('@second_user'), findsOneWidget);
      expect(find.text('@first_user'), findsNothing);
      await storage.clearToken();
      await tester.pumpAndSettle();
      expect(find.text('@second_user'), findsNothing);
      expect(find.text('Friends start with a sign-in'), findsOneWidget);
    },
  );
  testWidgets('filtering and clearing preserves original server friends', (
    tester,
  ) async {
    final storage = SessionStorage();
    final social = FakeSocial(ApiService(storage), storage);
    await mount(tester, storage, social, page: SocialPage.friends);
    expect(find.text('@alex_123'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pumpAndSettle();
    expect(find.text('@alex_123'), findsNothing);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('@alex_123'), findsOneWidget);
  });
}
