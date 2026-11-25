import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/screens/social/activity_screen.dart';
import 'package:flyprox_app/services/activity_service.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'fakes/social_storage.dart';

class FakeActivity extends ActivityService {
  FakeActivity(super.api, super.storage);
  final calls = <String?>[];
  bool fail = false;
  Map<String, dynamic>? response;
  Completer<Map<String, dynamic>>? pending;
  @override
  Future<Map<String, dynamic>> page({String? cursor}) async {
    calls.add(cursor);
    if (pending != null) return pending!.future;
    if (fail) throw const ApiException('Offline');
    if (response != null) return response!;
    final offset = cursor == null ? 0 : int.parse(cursor);
    return {
      'items': List.generate(
        20,
        (i) => {
          'id': '${offset + i}',
          'chosenName': 'Student ${offset + i}',
          'premiumBadge': true,
          'premiumBadgeUntil': '2099-01-01T00:00:00Z',
          'question': 'Most likely to become famous',
          'graduationYear': 2028,
          'occurredAt': '2026-11-24T00:00:00Z',
        },
      ),
      'nextCursor': '${offset + 20}',
      'campusRequired': false,
    };
  }
}

class ActivityStorage extends SessionStorage {
  @override
  Future<void> saveToken(String value) async {
    token = value;
    notifyListeners();
  }
}

void main() {
  Future<(SessionStorage, FakeActivity)> mount(
    WidgetTester tester, {
    bool fail = false,
    double scale = 1,
    Map<String, dynamic>? response,
  }) async {
    final storage = ActivityStorage();
    final service = FakeActivity(ApiService(storage), storage)
      ..fail = fail
      ..response = response;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          activityServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const ActivityScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (storage, service);
  }

  Future<void> bottom(WidgetTester tester) async {
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
    scroll.position.jumpTo(scroll.position.maxScrollExtent - 80);
    await tester.pump();
    await tester.drag(
      find.byKey(const Key('activity-list')),
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();
  }

  for (final entry in [
    ('female', 'From a girl · Graduating in 2029'),
    ('male', 'From a boy · Graduating in 2029'),
    ('nonbinary', 'From a non-binary student · Graduating in 2029'),
  ]) {
    testWidgets('Activity ignores membership badges from an older server', (
      tester,
    ) async {
      await mount(tester);
      expect(find.text('Student 0'), findsOneWidget);
      expect(find.byIcon(Icons.verified), findsNothing);
    });

    testWidgets(
      'Activity renders server ${entry.$1} voter hint, not chosen person gender',
      (tester) async {
        await mount(
          tester,
          response: {
            'items': [
              {
                'id': 'v',
                'chosenName': 'Aman',
                'question': 'Who makes everyone smile?',
                'voterGender': entry.$1,
                'graduationYear': 2029,
                'occurredAt': '2026-11-24T00:00:00Z',
              },
            ],
            'nextCursor': null,
          },
        );
        expect(find.text(entry.$2), findsOneWidget);
      },
    );
  }

  testWidgets(
    'first 20 only; more loads on downward scroll and stops at 200 even if a server returns another cursor',
    (tester) async {
      final (_, service) = await mount(tester);
      expect(service.calls, [null]);
      expect(find.text('Activity'), findsOneWidget);
      expect(find.text('Student 0'), findsOneWidget);
      expect(find.text('Was chosen in a poll'), findsWidgets);
      expect(find.text('From a student · Graduating in 2028'), findsWidgets);
      await tester.pump(const Duration(seconds: 2));
      expect(service.calls.length, 1);
      for (var i = 1; i < 10; i++) {
        await bottom(tester);
        expect(service.calls.length, i + 1);
      }
      await bottom(tester);
      expect(service.calls.length, 10);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'failure offers retry without fake cards; a stale account response cannot restore another account activity',
    (tester) async {
      final (storage, service) = await mount(tester, fail: true);
      expect(find.text('Offline'), findsOneWidget);
      expect(find.textContaining('was chosen'), findsNothing);
      service.fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Student 0'), findsOneWidget);
      service.pending = Completer();
      await storage.saveToken('other');
      await tester.pump();
      await storage.clearToken();
      await tester.pump();
      service.pending!.complete({'items': [], 'nextCursor': null});
      await tester.pumpAndSettle();
      expect(find.text('Student 0'), findsNothing);
    },
  );
  testWidgets('cards wrap at 320px and double text size without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(tester, scale: 2);
    expect(tester.takeException(), isNull);
  });
  testWidgets('changing campus clears old activity and starts at page one', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final (_, service) = await mount(tester);
    expect(find.text('Student 0'), findsOneWidget);
    final context = tester.element(find.byType(ActivityScreen));
    final setup = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(onboardingDetailsProvider);
    service.pending = Completer();
    await setup.draft({
      'stage': 'done',
      'status': 'selected',
      'school': {'id': 'new-campus'},
    });
    await tester.pump();
    expect(find.text('Student 0'), findsNothing);
    expect(service.calls, [null, null]);
    service.pending!.complete({'items': [], 'nextCursor': null});
    await tester.pumpAndSettle();
    expect(find.text('Your campus activity starts here'), findsOneWidget);
  });
  testWidgets('empty campus feed explains the screen without fake events', (
    tester,
  ) async {
    await mount(tester, response: {'items': [], 'nextCursor': null});
    expect(find.text('Your campus activity starts here'), findsOneWidget);
    expect(
      find.text(
        'See who gets chosen in polls around your campus. '
        'New activity will appear here.',
      ),
      findsOneWidget,
    );
    expect(find.text('Was chosen in a poll'), findsNothing);
    expect(find.text('Retry'), findsNothing);
  });
  testWidgets('missing campus is distinct from an empty feed', (tester) async {
    await mount(
      tester,
      response: {'items': [], 'nextCursor': null, 'campusRequired': true},
    );
    expect(find.text('Choose your campus first'), findsOneWidget);
    expect(find.text('Your campus activity starts here'), findsNothing);
  });
  testWidgets('failed loading is not presented as an empty campus feed', (
    tester,
  ) async {
    await mount(tester, fail: true);
    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Your campus activity starts here'), findsNothing);
  });
  testWidgets('cards use server fields and omit an unconfirmed year', (
    tester,
  ) async {
    await mount(
      tester,
      response: {
        'items': [
          {
            'id': 'real-event',
            'chosenName': 'Alex Taylor',
            'question': 'Most likely to become famous',
            'graduationYear': null,
            'occurredAt': DateTime.now()
                .subtract(const Duration(hours: 8))
                .toUtc()
                .toIso8601String(),
          },
        ],
        'nextCursor': null,
      },
    );
    expect(find.text('Alex Taylor'), findsOneWidget);
    expect(find.text('Most likely to become famous'), findsOneWidget);
    expect(find.text('8h'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('activity-time-real-event')),
      findsOneWidget,
    );
    expect(find.textContaining('graduating'), findsNothing);
    final bar = tester.widget<AppBar>(find.byType(AppBar));
    expect(bar.centerTitle, isTrue);
  });
  testWidgets('pull to refresh restarts the feed at the first page', (
    tester,
  ) async {
    final (_, service) = await mount(tester);
    await tester.drag(
      find.byKey(const Key('activity-list')),
      const Offset(0, 400),
    );
    await tester.pumpAndSettle();
    expect(service.calls, [null, null]);
  });
}
