import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/screens/profile/edit_profile_screen.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/profile_edit_service.dart';
import 'package:flyprox_app/services/onboarding_details_service.dart';
import 'package:flyprox_app/widgets/common/app_shell.dart';
import 'fakes/social_storage.dart';

class EditorOnboardingFake extends OnboardingDetailsService {
  EditorOnboardingFake(super.api, super.storage);
  @override
  Future<void> restore() async {}
  @override
  Future<Map<String, dynamic>> search(
    String q, {
    String cursor = '',
    String? countryOverride,
  }) async => {
    'schools': [
      {'id': 'new-campus', 'name': 'West Campus', 'city': 'Austin'},
    ],
    'available': true,
  };
}

class EditorFake extends ProfileEditService {
  EditorFake(super.api, super.storage);
  final writes = <Map<String, dynamic>>[];
  bool fail = false, loadFailure = false;
  final pending = <String, Completer<Map<String, dynamic>>>{};
  final limits = <String, dynamic>{
    for (final field in [
      'firstName',
      'lastName',
      'username',
      'schoolId',
      'graduationYear',
    ])
      field: {'editable': true, 'nextAllowedAt': null},
  };
  @override
  Future<Map<String, dynamic>> request(
    String token, {
    String suffix = '',
    String method = 'GET',
    Map<String, dynamic>? data,
    Map<String, dynamic>? query,
  }) async {
    if (suffix == '/username') {
      final name = query!['username'] as String;
      if (pending[name] != null) return pending[name]!.future;
      return {'username': name, 'available': name != 'taken'};
    }
    if (method == 'PUT') {
      writes.add(data!);
      if (fail) {
        throw const ApiException('Couldn’t save your profile. Try again.');
      }
    } else if (loadFailure) {
      throw const ApiException('Couldn’t load your profile.');
    }
    return {
      'revision': 'revision-one',
      'serverNow': '2026-11-24T12:00:00Z',
      'firstName': 'Alex',
      'lastName': 'Smith',
      'username': 'alex_smith',
      'gender': 'male',
      'country': 'US',
      'school': {'id': 'campus', 'name': 'Central High'},
      'graduationYear': 2028,
      'limits': limits,
      if (method == 'PUT')
        ...Map<String, dynamic>.from(data!['changes'] as Map),
    };
  }
}

Future<({GoRouter router, SessionStorage storage, EditorFake service})> mount(
  WidgetTester tester, {
  void Function(EditorFake)? configure,
  bool shell = false,
}) async {
  final storage = SessionStorage();
  final service = EditorFake(ApiService(storage), storage);
  configure?.call(service);
  final routes = [
    GoRoute(
      path: '/base',
      builder: (_, __) => const Scaffold(body: Text('Base profile')),
    ),
    GoRoute(
      path: '/edit-profile',
      builder: (_, __) => const EditProfileScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (_, __) => const Scaffold(body: Text('Settings page')),
    ),
  ];
  final router = GoRouter(
    initialLocation: '/base',
    routes: shell
        ? [
            ShellRoute(
              builder: (_, __, child) => AppShell(child: child),
              routes: routes,
            ),
          ]
        : routes,
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
        profileEditServiceProvider.overrideWithValue(service),
        onboardingDetailsProvider.overrideWith(
          (ref) => EditorOnboardingFake(ApiService(storage), storage),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  router.push('/edit-profile');
  await tester.pumpAndSettle();
  return (router: router, storage: storage, service: service);
}

Finder field(String key) => find.byKey(ValueKey('edit-$key'));
Future<void> tap(WidgetTester tester, String text) async {
  await tester.pump();
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'server fields, fixed avatar, immutable gender and pristine Save',
    (tester) async {
      await mount(tester);
      expect(find.text('🙂'), findsOneWidget);
      expect(find.textContaining('Gender can’t be changed'), findsOneWidget);
      expect(find.text('Change photo'), findsNothing);
      expect(field('graduationYear'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
            .onPressed,
        isNull,
      );
      await tester.enterText(field('lastName'), 'Jones');
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
            .onPressed,
        isNotNull,
      );
      await tester.enterText(field('lastName'), 'Smith');
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'only changed surname is confirmed and sent; no gender or unrelated fields',
    (tester) async {
      final f = await mount(tester);
      await tester.enterText(field('lastName'), 'Jones');
      await tap(tester, 'Save');
      expect(find.textContaining('• Last name'), findsOneWidget);
      expect(f.service.writes, isEmpty);
      await tap(tester, 'Confirm and save');
      expect(f.service.writes.single['changes'], {'lastName': 'Jones'});
      expect(f.service.writes.single['confirmed'], true);
      expect(find.text('Base profile'), findsOneWidget);
    },
  );

  testWidgets(
    'confirmation cancel and unsaved Keep editing or Discard do not write',
    (tester) async {
      final f = await mount(tester);
      await tester.enterText(field('firstName'), 'Alice');
      await tap(tester, 'Save');
      await tap(tester, 'Cancel');
      expect(f.service.writes, isEmpty);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      await tap(tester, 'Keep editing');
      expect(find.text('Alice'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      await tap(tester, 'Discard');
      expect(f.service.writes, isEmpty);
      expect(find.text('Base profile'), findsOneWidget);
    },
  );

  testWidgets(
    'save failure preserves draft and retries with the same idempotency key',
    (tester) async {
      final f = await mount(tester, configure: (s) => s.fail = true);
      await tester.enterText(field('lastName'), 'Jones');
      await tap(tester, 'Save');
      await tap(tester, 'Confirm and save');
      expect(find.text('Jones'), findsOneWidget);
      expect(
        find.text('Couldn’t save your profile. Try again.'),
        findsOneWidget,
      );
      await tap(tester, 'Save');
      await tap(tester, 'Confirm and save');
      expect(f.service.writes.length, 2);
      expect(
        f.service.writes[0]['requestId'],
        f.service.writes[1]['requestId'],
      );
    },
  );

  testWidgets('per-field lock disables only that field and shows next date', (
    tester,
  ) async {
    await mount(
      tester,
      configure: (s) {
        s.limits['firstName'] = {
          'editable': false,
          'nextAllowedAt': '2027-02-22T12:00:00Z',
        };
      },
    );
    expect(tester.widget<TextFormField>(field('firstName')).enabled, false);
    expect(tester.widget<TextFormField>(field('lastName')).enabled, true);
    expect(find.textContaining('Available again on'), findsOneWidget);
  });

  testWidgets(
    'username availability is debounced and stale replies are ignored',
    (tester) async {
      final first = Completer<Map<String, dynamic>>();
      final f = await mount(
        tester,
        configure: (s) => s.pending['old_name'] = first,
      );
      await tester.ensureVisible(field('username'));
      await tester.enterText(field('username'), 'old_name');
      await tester.pump(const Duration(milliseconds: 501));
      await tester.enterText(field('username'), 'taken');
      await tester.pump(const Duration(milliseconds: 501));
      await tester.pumpAndSettle();
      expect(
        find.text('This username is taken. Choose another.'),
        findsOneWidget,
      );
      first.complete({'available': true});
      await tester.pumpAndSettle();
      expect(find.text('Username available'), findsNothing);
      expect(f.service.writes, isEmpty);
    },
  );

  testWidgets('account change clears old form and prevents writes', (
    tester,
  ) async {
    final f = await mount(tester);
    await tester.enterText(field('firstName'), 'Alice');
    await f.storage.clearToken();
    await tester.pumpAndSettle();
    expect(find.text('Alice'), findsNothing);
    expect(
      find.text('Account changed. Close and reopen Edit profile.'),
      findsOneWidget,
    );
    expect(f.service.writes, isEmpty);
  });

  testWidgets('load failure is not an empty editable form and can retry', (
    tester,
  ) async {
    final f = await mount(tester, configure: (s) => s.loadFailure = true);
    expect(field('firstName'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    f.service.loadFailure = false;
    await tap(tester, 'Retry');
    expect(field('firstName'), findsOneWidget);
  });

  testWidgets(
    'graduation year has an independent field and saves only the year',
    (tester) async {
      final f = await mount(tester);
      await tester.ensureVisible(field('graduationYear'));
      await tester.enterText(field('graduationYear'), '2029');
      await tap(tester, 'Save');
      expect(find.textContaining('• Graduation year'), findsOneWidget);
      await tap(tester, 'Confirm and save');
      expect(f.service.writes.single['changes'], {'graduationYear': 2029});
    },
  );

  testWidgets('campus selection stays a draft until common Save', (
    tester,
  ) async {
    final f = await mount(tester);
    await tester.ensureVisible(find.byKey(const Key('edit-campus')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('edit-campus')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Search campuses'),
      'West',
    );
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pumpAndSettle();
    await tap(tester, 'West Campus');
    expect(f.service.writes, isEmpty);
    await tap(tester, 'Save');
    await tap(tester, 'Confirm and save');
    expect(f.service.writes.single['changes'], {'schoolId': 'new-campus'});
  });

  testWidgets(
    'bottom tab switch consults unsaved changes without changing tab visuals',
    (tester) async {
      final f = await mount(tester, shell: true);
      await tester.enterText(field('lastName'), 'Jones');
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Save changes?'), findsOneWidget);
      await tap(tester, 'Keep editing');
      expect(find.text('Edit profile'), findsOneWidget);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tap(tester, 'Discard');
      expect(find.text('Settings page'), findsOneWidget);
      expect(f.service.writes, isEmpty);
    },
  );

  testWidgets('invalid edited names and years do not send writes', (
    tester,
  ) async {
    final f = await mount(tester);
    await tester.enterText(field('firstName'), 'X');
    await tap(tester, 'Save');
    expect(
      find.text('Use 2–50 letters, spaces, hyphens or apostrophes.'),
      findsOneWidget,
    );
    expect(f.service.writes, isEmpty);
    await tester.enterText(field('firstName'), 'Alex');
    await tester.ensureVisible(field('graduationYear'));
    await tester.enterText(field('graduationYear'), '9999');
    await tap(tester, 'Save');
    expect(find.text('Choose a valid graduation year.'), findsOneWidget);
    expect(f.service.writes, isEmpty);
  });
}
