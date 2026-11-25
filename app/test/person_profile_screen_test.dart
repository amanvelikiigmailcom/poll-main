import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flyprox_app/models/person_profile.dart';
import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/screens/profile/person_profile_screen.dart';
import 'package:flyprox_app/screens/social/social_screen.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/social_service.dart';
import 'package:flyprox_app/theme/app_theme.dart';
import 'fakes/social_storage.dart';

class PersonFake extends SocialService {
  PersonFake(super.api, super.storage);
  String relationship = 'none';
  bool unavailable = false, statsFail = false, actionFail = false, self = false;
  int statsCalls = 0;
  int statsFailureStatus = 503;
  final actions = <String>[];
  Completer<Map<String, dynamic>>? pendingProfile;
  Completer<PersonNominations>? pendingStats;
  Completer<Map<String, dynamic>>? pendingAction;
  final cursors = <String?>[];
  Map<String, dynamic> get person => {
    'id': 'alex', 'username': 'alex_123', 'relationship': relationship,
    // Explicit same-campus public projection, independent of relationship.
    'firstName': 'Alex', 'lastName': 'Smith',
    'campus': {
      'name': 'A very long campus name that must wrap safely on phones',
    },
    'graduationYear': 2027,
  };
  @override
  Future<Map<String, dynamic>> profile(String id) async {
    if (pendingProfile != null) return pendingProfile!.future;
    if (unavailable) {
      throw const ApiException('Account not found.', statusCode: 404);
    }
    return self ? {'self': true} : person;
  }

  @override
  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? data,
  }) async {
    if (path.startsWith('/handles/')) return profile('alex');
    if (path == '/summary') return {'friendsCount': 1, 'incomingCount': 0};
    return {};
  }

  @override
  Future<Map<String, dynamic>> report(String id, String reason) {
    expect(reason, 'safety_concern');
    return act(id, 'report');
  }

  @override
  Future<Map<String, dynamic>> act(String id, String action) async {
    actions.add(action);
    if (pendingAction != null) return pendingAction!.future;
    if (actionFail) throw const ApiException('Unavailable', statusCode: 503);
    relationship = switch (action) {
      'request' => 'outgoing',
      'accept' => 'friends',
      'remove' || 'cancel' || 'decline' => 'none',
      _ => relationship,
    };
    return {'relationship': relationship};
  }

  @override
  Future<PersonNominations> nominations(String id, {String? cursor}) async {
    statsCalls++;
    cursors.add(cursor);
    if (pendingStats != null) return pendingStats!.future;
    if (statsFail) {
      throw ApiException('Unavailable', statusCode: statsFailureStatus);
    }
    return PersonNominations.fromJson({
      'friendsCount': 54,
      'votesReceived': 12,
      'items': cursor == null
          ? [
              {
                'questionId': 'a',
                'question': 'Who makes everyone smile?',
                'count': 5,
              },
              {
                'questionId': 'b',
                'question': 'Who is the most thoughtful?',
                'count': 3,
              },
            ]
          : [
              {
                'questionId': 'c',
                'question': 'Who dreams the biggest?',
                'count': 4,
              },
            ],
      'nextCursor': cursor == null ? 'next-page' : null,
    });
  }
}

void main() {
  Future<GoRouter> mount(
    WidgetTester tester,
    SessionStorage storage,
    PersonFake social, {
    String path = '/people/alex',
    double scale = 1,
  }) async {
    final router = GoRouter(
      initialLocation: path,
      routes: [
        GoRoute(
          path: '/people/:id',
          builder: (_, state) =>
              PersonProfileScreen(userId: state.pathParameters['id']),
        ),
        GoRoute(
          path: '/p/:handle',
          builder: (_, state) =>
              PersonProfileScreen(username: state.pathParameters['handle']),
        ),
        GoRoute(
          path: '/home/profile',
          builder: (_, _) =>
              const Scaffold(body: Text('Own profile destination')),
        ),
        GoRoute(
          path: '/phone',
          builder: (_, _) => const Scaffold(body: Text('Sign in destination')),
        ),
        GoRoute(
          path: '/blocked-users',
          builder: (_, _) =>
              const Scaffold(body: Text('Blocked list destination')),
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
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pump();
    return router;
  }

  testWidgets(
    'real profile uses English, guarded identity and grouped votes; both entry routes work',
    (tester) async {
      final storage = SessionStorage();
      final social = PersonFake(ApiService(storage), storage);
      final router = await mount(tester, storage, social);
      await tester.pumpAndSettle();
      expect(find.text('@alex_123'), findsOneWidget);
      expect(find.text('Alex Smith'), findsOneWidget);
      expect(find.text('Class of 2027'), findsOneWidget);
      expect(find.text('54'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Selected 5 times'), 180);
      expect(find.text('Who makes everyone smile?'), findsOneWidget);
      expect(find.text('Stars'), findsNothing);
      router.go('/p/@alex_123');
      await tester.pumpAndSettle();
      expect(find.text('@alex_123'), findsOneWidget);
      expect(find.text('Add friend'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'request is server-confirmed, disabled when sent, and cancellable from menu',
    (tester) async {
      final storage = SessionStorage();
      final social = PersonFake(ApiService(storage), storage);
      await mount(tester, storage, social);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add friend'));
      await tester.pumpAndSettle();
      expect(social.actions, ['request']);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Request sent'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('Account actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel request'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Withdraw request'));
      await tester.pumpAndSettle();
      expect(social.actions, ['request', 'cancel']);
      expect(find.text('Add friend'), findsOneWidget);
    },
  );

  testWidgets(
    'incoming request accepts and removal needs confirmation; cancelled removal does nothing',
    (tester) async {
      final storage = SessionStorage();
      final social = PersonFake(ApiService(storage), storage)
        ..relationship = 'incoming';
      await mount(tester, storage, social);
      await tester.pumpAndSettle();
      expect(find.text('Decline'), findsOneWidget);
      await tester.tap(find.text('Accept request'));
      await tester.pumpAndSettle();
      expect(find.text('Alex Smith'), findsOneWidget);
      await tester.tap(find.text('Remove friend'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(social.actions, ['accept']);
      await tester.tap(find.text('Remove friend'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(social.actions, ['accept', 'remove']);
      expect(find.text('Alex Smith'), findsOneWidget);
      expect(find.text('Add friend'), findsOneWidget);
    },
  );

  testWidgets('block requires confirmation and clears the blocked profile', (
    tester,
  ) async {
    final storage = SessionStorage();
    final social = PersonFake(ApiService(storage), storage);
    await mount(tester, storage, social);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Account actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Block account'));
    await tester.pumpAndSettle();
    expect(social.actions, isEmpty);
    await tester.tap(find.text('Block'));
    await tester.pumpAndSettle();
    expect(social.actions, ['block']);
    expect(find.text('Profile unavailable.'), findsOneWidget);
    expect(find.text('@alex_123'), findsNothing);
    expect(find.text('Times picked · 12'), findsNothing);
  });

  testWidgets(
    'account report prepares an email and never submits a server action',
    (tester) async {
      final storage = SessionStorage();
      final social = PersonFake(ApiService(storage), storage);
      await mount(tester, storage, social);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Account actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Report account'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Account reference: alex'), findsOneWidget);
      expect(find.textContaining('Account: @alex_123'), findsOneWidget);
      expect(find.text('Reason'), findsOneWidget);
      expect(social.actions, isEmpty);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(social.actions, isEmpty);
      expect(
        find.text('Report received. You can also block this account.'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'failed action preserves relationship; unavailable profile has no private UI',
    (tester) async {
      final storage = SessionStorage();
      final social = PersonFake(ApiService(storage), storage)
        ..actionFail = true;
      await mount(tester, storage, social);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add friend'));
      await tester.pumpAndSettle();
      expect(
        find.text('Couldn’t send friend request. Try again.'),
        findsOneWidget,
      );
      expect(find.text('Add friend'), findsOneWidget);
      social.unavailable = true;
      final context = tester.element(find.byType(PersonProfileScreen));
      ProviderScope.containerOf(
        context,
      ).read(socialVisibilityRevisionProvider.notifier).changed();
      await tester.pumpAndSettle();
      expect(find.text('Profile unavailable.'), findsOneWidget);
      expect(find.text('@alex_123'), findsNothing);
      expect(find.text('Add friend'), findsNothing);
    },
  );

  testWidgets(
    'stats failure is separate from the profile and never pretends to be zero',
    (tester) async {
      final storage = SessionStorage();
      final social = PersonFake(ApiService(storage), storage)..statsFail = true;
      await mount(tester, storage, social);
      await tester.pumpAndSettle();
      expect(find.text('@alex_123'), findsOneWidget);
      expect(find.text('0'), findsNothing);
      await tester.scrollUntilVisible(find.text('Retry'), 200);
      expect(
        find.text('Couldn’t load profile statistics. Try again.'),
        findsOneWidget,
      );
      social.statsFail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Times picked · 12'), findsOneWidget);
    },
  );

  for (final action in ['remove', 'block', 'decline']) {
    testWidgets(
      'failed $action retains confirmed data and reports an English error',
      (tester) async {
        final storage = SessionStorage();
        final social = PersonFake(ApiService(storage), storage)
          ..relationship = action == 'decline' ? 'incoming' : 'friends'
          ..actionFail = true;
        await mount(tester, storage, social);
        await tester.pumpAndSettle();
        if (action == 'block') {
          await tester.tap(find.byTooltip('Account actions'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Block account'));
        } else {
          await tester.tap(
            find.text(action == 'remove' ? 'Remove friend' : 'Decline'),
          );
        }
        await tester.pumpAndSettle();
        if (action != 'decline') {
          await tester.tap(
            find.text(switch (action) {
              'remove' => 'Remove',
              'block' => 'Block',
              _ => 'Block',
            }),
          );
          await tester.pumpAndSettle();
        }
        expect(social.actions, [action]);
        expect(
          find.text(switch (action) {
            'remove' => 'Couldn’t remove friend. Try again.',
            'block' => 'Couldn’t block account. Try again.',
            _ => 'Couldn’t update friend request. Try again.',
          }),
          findsOneWidget,
        );
        expect(find.text('Profile unavailable.'), findsNothing);
        expect(
          find.text(action == 'decline' ? 'Accept request' : 'Alex Smith'),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets(
    'double taps do not send duplicate requests and stale action success stays silent',
    (tester) async {
      final storage = SessionStorage();
      final pending = Completer<Map<String, dynamic>>();
      final social = PersonFake(ApiService(storage), storage)
        ..pendingAction = pending;
      await mount(tester, storage, social);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add friend'));
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(social.actions, ['request']);
      await storage.clearToken();
      await tester.pump();
      pending.complete({'relationship': 'outgoing'});
      await tester.pumpAndSettle();
      expect(find.text('Sign in to view profiles.'), findsOneWidget);
      expect(find.text('Friend request sent'), findsNothing);
      expect(find.text('Request sent'), findsNothing);
    },
  );

  testWidgets(
    'older backend without nominations keeps profile and friend actions available',
    (tester) async {
      final storage = SessionStorage();
      final social = PersonFake(ApiService(storage), storage)
        ..statsFail = true
        ..statsFailureStatus = 404;
      await mount(tester, storage, social);
      await tester.pumpAndSettle();
      expect(find.text('@alex_123'), findsOneWidget);
      expect(find.text('Add friend'), findsOneWidget);
      expect(find.text('Profile unavailable.'), findsNothing);
      await tester.scrollUntilVisible(find.text('Retry'), 180);
      expect(
        find.text('Couldn’t load profile statistics. Try again.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'invalid aggregate cursor discards mixed pages and restarts on retry',
    (tester) async {
      final storage = SessionStorage();
      final social = PersonFake(ApiService(storage), storage);
      await mount(tester, storage, social);
      await tester.pumpAndSettle();
      social.statsFail = true;
      social.statsFailureStatus = 409;
      await tester.drag(find.byType(ListView), const Offset(0, -700));
      await tester.pumpAndSettle();
      expect(find.text('Selected 5 times'), findsNothing);
      expect(find.text('12'), findsNothing);
      social.statsFail = false;
      await tester.ensureVisible(find.text('Retry'));
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(social.cursors.last, isNull);
      expect(find.text('Times picked · 12'), findsOneWidget);
    },
  );

  testWidgets(
    'scroll loads subsequent groups exactly once without duplicating earlier cards',
    (tester) async {
      final storage = SessionStorage();
      final social = PersonFake(ApiService(storage), storage);
      await mount(tester, storage, social);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -700));
      await tester.pumpAndSettle();
      expect(social.cursors, [null, 'next-page']);
      expect(find.text('Selected 4 times'), findsOneWidget);
      expect(social.statsCalls, 2);
    },
  );

  testWidgets('late profile data cannot repopulate a signed-out account', (
    tester,
  ) async {
    final storage = SessionStorage();
    final social = PersonFake(ApiService(storage), storage)
      ..pendingProfile = Completer<Map<String, dynamic>>();
    await mount(tester, storage, social);
    expect(find.bySemanticsLabel('Loading profile'), findsOneWidget);
    await storage.clearToken();
    await tester.pump();
    social.pendingProfile!.complete(social.person);
    await tester.pumpAndSettle();
    expect(find.text('@alex_123'), findsNothing);
    expect(find.text('Sign in to view profiles.'), findsOneWidget);
    expect(social.statsCalls, 0);
  });

  testWidgets('late statistics cannot repopulate after a visibility revision', (
    tester,
  ) async {
    final storage = SessionStorage();
    final pending = Completer<PersonNominations>();
    final social = PersonFake(ApiService(storage), storage)
      ..pendingStats = pending;
    await mount(tester, storage, social);
    await tester.pump();
    final context = tester.element(find.byType(PersonProfileScreen));
    social.unavailable = true;
    ProviderScope.containerOf(
      context,
    ).read(socialVisibilityRevisionProvider.notifier).changed();
    await tester.pump();
    pending.complete(
      PersonNominations.fromJson({
        'friendsCount': 99,
        'votesReceived': 99,
        'items': [],
        'nextCursor': null,
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('Profile unavailable.'), findsOneWidget);
    expect(find.text('99'), findsNothing);
    expect(find.text('@alex_123'), findsNothing);
  });

  testWidgets('own profile redirects without friend actions', (tester) async {
    final storage = SessionStorage();
    final social = PersonFake(ApiService(storage), storage)..self = true;
    await mount(tester, storage, social);
    await tester.pumpAndSettle();
    expect(find.text('Own profile destination'), findsOneWidget);
    expect(find.text('Add friend'), findsNothing);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('320px profile supports long campus and text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final storage = SessionStorage();
      final social = PersonFake(ApiService(storage), storage)
        ..relationship = 'friends';
      await mount(tester, storage, social, scale: scale);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Selected 5 times'), 180);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('blocking shows a hint with a shortcut to the blocked list', (
    tester,
  ) async {
    final storage = SessionStorage();
    final social = PersonFake(ApiService(storage), storage);
    await mount(tester, storage, social);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Account actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Block account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Block'));
    await tester.pumpAndSettle();
    expect(social.actions, ['block']);
    expect(find.text('Profile unavailable.'), findsOneWidget);
    expect(
      find.text(
        'Account blocked. Manage the list in Settings → Blocked users.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('View list'));
    await tester.pumpAndSettle();
    expect(find.text('Blocked list destination'), findsOneWidget);
  });
}
