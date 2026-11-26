import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/screens/social/likes_result_screen.dart';
import 'package:flyprox_app/screens/social/received_likes_screen.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/social_service.dart';
import 'fakes/social_storage.dart';

class LikesFake extends SocialService {
  LikesFake(super.api, super.storage);

  bool fail = false;
  List<Map<String, dynamic>> page1 = [];
  List<Map<String, dynamic>> page2 = [];
  int votes = 0;

  @override
  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? data,
  }) async {
    if (!path.startsWith('/likes')) throw StateError('Unexpected $path');
    if (fail) throw StateError('Offline');
    if (path.contains('cursor=')) {
      return {'votesReceived': votes, 'items': page2, 'nextCursor': null};
    }
    return {
      'votesReceived': votes,
      'items': page1,
      'nextCursor': page2.isEmpty ? null : 'c1',
    };
  }
}

Map<String, dynamic> vote(String id, String question, DateTime occurred) => {
  'id': id,
  'question': question,
  'occurredAt': occurred.toIso8601String(),
};

GoRouter likesRouter({String initialLocation = '/'}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/', builder: (_, _) => const ReceivedLikesScreen()),
      GoRoute(
        path: '/entry',
        builder: (_, _) => Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => context.push('/'),
                child: const Text('Open likes'),
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('Home polls')),
      ),
      GoRoute(
        path: '/likes-result',
        builder: (_, state) => LikesResultScreen(
          like: state.extra is Map
              ? Map<String, dynamic>.from(state.extra as Map)
              : null,
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  return router;
}

Future<GoRouter> mount(
  WidgetTester tester,
  SessionStorage storage,
  LikesFake social, {
  String initialLocation = '/',
}) async {
  final router = likesRouter(initialLocation: initialLocation);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
        socialServiceProvider.overrideWithValue(social),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  return router;
}

void main() {
  testWidgets(
    'opening different Likes never reuses another question participant snapshot',
    (tester) async {
      final storage = SessionStorage();
      final social = LikesFake(ApiService(storage), storage)
        ..votes = 2
        ..page1 = [
          {
            ...vote('v1', 'First server question', DateTime.now()),
            'participants': [
              {'name': 'First option'},
            ],
          },
          {
            ...vote('v2', 'Second server question', DateTime.now()),
            'participants': [
              {'name': 'Second option'},
            ],
          },
        ];
      final router = await mount(tester, storage, social);
      await tester.pumpAndSettle();
      await tester.tap(find.text('First server question'));
      await tester.pumpAndSettle();
      expect(find.text('First option'), findsOneWidget);
      expect(find.text('Second option'), findsNothing);
      router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Second server question'));
      await tester.pumpAndSettle();
      expect(find.text('Second option'), findsOneWidget);
      expect(find.text('First option'), findsNothing);
    },
  );

  testWidgets(
    'Likes list and details preserve the same backend gender and graduation year',
    (tester) async {
      final storage = SessionStorage();
      final social = LikesFake(ApiService(storage), storage)
        ..votes = 1
        ..page1 = [
          {
            ...vote('v1', 'Who makes everyone smile?', DateTime.now()),
            'voterGender': 'nonbinary',
            'graduationYear': 2027,
          },
        ];
      await mount(tester, storage, social);
      await tester.pumpAndSettle();
      expect(
        find.text('From a non-binary student · Class of 2027'),
        findsOneWidget,
      );
      await tester.tap(find.text('Who makes everyone smile?'));
      await tester.pumpAndSettle();
      expect(
        find.text('From a non-binary student · Class of 2027'),
        findsOneWidget,
      );
    },
  );
  test('like sections split Today, Yesterday and Earlier', () {
    final now = DateTime(2026, 11, 24, 15, 0);
    expect(likeSection(DateTime(2026, 11, 24, 9, 0), now), 'Today');
    expect(likeSection(DateTime(2026, 11, 23, 18, 0), now), 'Yesterday');
    expect(likeSection(DateTime(2026, 11, 20, 12, 0), now), 'Earlier');
  });

  test('like time labels use short relative text', () {
    final now = DateTime(2026, 11, 24, 15, 0);
    expect(likeTimeAgo(DateTime(2026, 11, 24, 14, 59, 30), now), 'Just now');
    expect(likeTimeAgo(DateTime(2026, 11, 24, 14, 40), now), '20m ago');
    expect(likeTimeAgo(DateTime(2026, 11, 24, 12, 0), now), '3h ago');
    expect(likeTimeAgo(DateTime(2026, 11, 23, 18, 0), now), 'Yesterday');
    expect(likeTimeAgo(DateTime(2026, 11, 21, 12, 0), now), '3d ago');
  });

  testWidgets('header, counter, sections and cards render real data', (
    tester,
  ) async {
    final now = DateTime.now();
    final noon = DateTime(now.year, now.month, now.day, 12);
    final storage = SessionStorage();
    final social = LikesFake(ApiService(storage), storage)
      ..votes = 3
      ..page1 = [
        vote('v1', 'Who makes everyone smile?', noon),
        vote(
          'v2',
          'Who is the smartest?',
          noon.subtract(const Duration(days: 1)),
        ),
        vote(
          'v3',
          'Who runs the fastest?',
          noon.subtract(const Duration(days: 10)),
        ),
      ];
    await mount(tester, storage, social);
    await tester.pumpAndSettle();
    expect(find.text('Likes'), findsOneWidget);
    expect(find.text('Total: 3'), findsOneWidget);
    expect(find.text('See who picked you in quizzes'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    // Section header plus the yesterday card's own time label.
    expect(find.text('Yesterday'), findsNWidgets(2));
    expect(find.text('Earlier'), findsOneWidget);
    expect(find.text('Who makes everyone smile?'), findsOneWidget);
    expect(find.text('Someone picked you'), findsNWidgets(3));
    expect(find.text('EMPTY FOR NOW'), findsNothing);
  });

  testWidgets('zero likes show the motivational card without a close button', (
    tester,
  ) async {
    final storage = SessionStorage();
    final social = LikesFake(ApiService(storage), storage)..votes = 0;
    await mount(tester, storage, social);
    await tester.pumpAndSettle();
    expect(find.text('Likes'), findsOneWidget);
    expect(find.text('Your future likes'), findsOneWidget);
    expect(find.text('EMPTY FOR NOW'), findsOneWidget);
    expect(
      find.text(
        'When someone picks you in a quiz, your likes will appear here. '
        'Want more likes? Play more rounds.',
      ),
      findsOneWidget,
    );
    expect(find.text('Play a quiz'), findsOneWidget);
    expect(find.text('Total: 0'), findsNothing);
    expect(find.byTooltip('Close'), findsNothing);
  });

  testWidgets('CTA button navigates to the home polls', (tester) async {
    final storage = SessionStorage();
    final social = LikesFake(ApiService(storage), storage)..votes = 0;
    final router = await mount(tester, storage, social);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Play a quiz'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play a quiz'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/home');
    expect(find.text('Home polls'), findsOneWidget);
  });

  testWidgets('pushed likes show a close button', (tester) async {
    final storage = SessionStorage();
    final social = LikesFake(ApiService(storage), storage)..votes = 0;
    await mount(tester, storage, social, initialLocation: '/entry');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open likes'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Close'), findsOneWidget);
    expect(find.text('EMPTY FOR NOW'), findsOneWidget);
  });

  testWidgets('non-zero count without items is not the empty card', (
    tester,
  ) async {
    final storage = SessionStorage();
    final social = LikesFake(ApiService(storage), storage)..votes = 5;
    await mount(tester, storage, social);
    await tester.pumpAndSettle();
    expect(find.text('No available Likes to show.'), findsOneWidget);
    expect(find.text('EMPTY FOR NOW'), findsNothing);
  });

  testWidgets('error shows retry and retry reloads', (tester) async {
    final storage = SessionStorage();
    final social = LikesFake(ApiService(storage), storage)
      ..fail = true
      ..votes = 1
      ..page1 = [vote('v1', 'Who makes everyone smile?', DateTime.now())];
    await mount(tester, storage, social);
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t load Likes. Try again.'), findsOneWidget);
    social.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Who makes everyone smile?'), findsOneWidget);
  });

  testWidgets('guest sees the sign-in state', (tester) async {
    final storage = SessionStorage()..token = null;
    final social = LikesFake(ApiService(storage), storage);
    await mount(tester, storage, social);
    await tester.pumpAndSettle();
    expect(find.text('Sign in to see your Likes.'), findsOneWidget);
    expect(find.text('EMPTY FOR NOW'), findsNothing);
  });

  testWidgets('load more appends the next page', (tester) async {
    final now = DateTime.now();
    final storage = SessionStorage();
    final social = LikesFake(ApiService(storage), storage)
      ..votes = 2
      ..page1 = [vote('v1', 'Who makes everyone smile?', now)]
      ..page2 = [vote('v2', 'Who is the smartest?', now)];
    await mount(tester, storage, social);
    await tester.pumpAndSettle();
    expect(find.text('Load more'), findsOneWidget);
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();
    expect(find.text('Who is the smartest?'), findsOneWidget);
  });

  testWidgets('tapping a card opens details without voter identity', (
    tester,
  ) async {
    final storage = SessionStorage();
    final social = LikesFake(ApiService(storage), storage)
      ..votes = 1
      ..page1 = [vote('v1', 'Who makes everyone smile?', DateTime.now())];
    await mount(tester, storage, social);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Who makes everyone smile?'));
    await tester.pumpAndSettle();
    expect(find.text('Quiz result'), findsOneWidget);
    expect(find.text('Who makes everyone smile?'), findsOneWidget);
    expect(find.text('Who picked you is hidden'), findsOneWidget);
    expect(find.text('Someone picked you!'), findsNothing);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('See who picked you'), findsOneWidget);
  });
}
