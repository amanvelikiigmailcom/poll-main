import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/screens/profile/profile_social_section.dart';
import 'package:flyprox_app/screens/social/received_likes_screen.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/social_service.dart';
import 'fakes/social_storage.dart';

class ProfileSocialFake extends SocialService {
  ProfileSocialFake(super.api, super.storage);
  Completer<Map<String, dynamic>>? pendingLikes;
  bool failLikes = false;
  @override
  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? data,
  }) async {
    if (path == '/me') return {'username': 'alex_123', 'votesReceived': 12};
    if (path == '/summary') return {'friendsCount': 6, 'incomingCount': 3};
    if (path.startsWith('/likes')) {
      if (pendingLikes != null) return pendingLikes!.future;
      if (failLikes) throw StateError('Offline');
      return {
        'votesReceived': 12,
        'items': [
          {
            'id': 'v1',
            'question': 'Who makes everyone smile?',
            'occurredAt': '2026-11-24T12:00:00Z',
          },
        ],
        'nextCursor': null,
      };
    }
    throw StateError('Unexpected $path');
  }

  @override
  Future<Map<String, dynamic>> list(String kind, {String? cursor}) async => {
    'users': [
      for (var i = 0; i < 6; i++)
        {
          'id': 'friend$i',
          'username': 'friend_$i',
          'firstName': 'Alex',
          'lastName': 'Friend $i',
          'relationship': 'friends',
        },
    ],
  };
}

void main() {
  testWidgets(
    'profile uses server stats, five named friends and an actual username link',
    (tester) async {
      final storage = SessionStorage();
      final social = ProfileSocialFake(ApiService(storage), storage);
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(
              body: SingleChildScrollView(child: ProfileSocialSection()),
            ),
          ),
          GoRoute(
            path: '/friend-requests',
            builder: (_, _) =>
                const Scaffold(body: Text('Received destination')),
          ),
          GoRoute(
            path: '/people/:id',
            builder: (_, state) =>
                Scaffold(body: Text('Person ${state.pathParameters['id']}')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(storage),
            socialServiceProvider.overrideWithValue(social),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('6'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Collection'), findsNothing);
      expect(find.text('Alex Friend 4'), findsOneWidget);
      expect(find.text('Alex Friend 5'), findsNothing);
      await tester.tap(find.text('Share profile'));
      await tester.pumpAndSettle();
      expect(clipboard, 'https://api.flyprox.com/p/@alex_123');
      expect(find.text('Copied'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Share profile'), findsOneWidget);
      await tester.tap(find.text('Requests'));
      await tester.pumpAndSettle();
      expect(find.text('Received destination'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Alex Friend 0'));
      await tester.tap(find.text('Alex Friend 0'));
      await tester.pumpAndSettle();
      expect(find.text('Person friend0'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  Future<void> mountLikes(
    WidgetTester tester,
    SessionStorage storage,
    ProfileSocialFake social,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          socialServiceProvider.overrideWithValue(social),
        ],
        child: const MaterialApp(home: ReceivedLikesScreen()),
      ),
    );
  }

  testWidgets('Likes displays real received data, not a coming-soon screen', (
    tester,
  ) async {
    final storage = SessionStorage();
    final social = ProfileSocialFake(ApiService(storage), storage);
    await mountLikes(tester, storage, social);
    await tester.pumpAndSettle();
    expect(find.text('12 received likes'), findsOneWidget);
    expect(find.text('Who makes everyone smile?'), findsOneWidget);
    await storage.clearToken();
    await tester.pumpAndSettle();
    expect(find.text('Who makes everyone smile?'), findsNothing);
    expect(find.text('Sign in to see your Likes.'), findsOneWidget);
  });
  testWidgets('stale Likes cannot repopulate a signed-out account', (
    tester,
  ) async {
    final storage = SessionStorage();
    final social = ProfileSocialFake(ApiService(storage), storage)
      ..pendingLikes = Completer<Map<String, dynamic>>();
    await mountLikes(tester, storage, social);
    await tester.pump();
    await storage.clearToken();
    await tester.pump();
    social.pendingLikes!.complete({'votesReceived': 99, 'items': []});
    await tester.pumpAndSettle();
    expect(find.text('99 received likes'), findsNothing);
    expect(find.text('Sign in to see your Likes.'), findsOneWidget);
  });
  testWidgets('Likes network errors are not presented as an empty collection', (
    tester,
  ) async {
    final storage = SessionStorage();
    final social = ProfileSocialFake(ApiService(storage), storage)
      ..failLikes = true;
    await mountLikes(tester, storage, social);
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t load Likes. Try again.'), findsOneWidget);
    expect(find.text('Your received Likes will appear here.'), findsNothing);
  });
}
