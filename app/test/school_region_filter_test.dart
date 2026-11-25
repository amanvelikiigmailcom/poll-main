import 'package:flyprox_app/config/school_regions.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/providers/service_providers.dart';
import 'package:flyprox_app/router/app_router.dart';
import 'package:flyprox_app/services/api_service.dart';
import 'package:flyprox_app/services/content_service.dart';
import 'package:flyprox_app/services/onboarding_details_service.dart';
import 'package:flyprox_app/services/storage_service.dart';
import 'fakes/eligible_player.dart';
import 'fakes/test_app.dart';

const _school = {
  'id': 'US-CCD-1',
  'name': 'Central High',
  'city': 'Austin',
  'region': 'TEXAS',
  'country': 'US',
};

void main() {
  setUp(setUpTestApp);
  setUp(markEligiblePlayer);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ContentService.instance.debugClear();
  });
  tearDown(() => ContentService.instance.debugClear());

  Future<OnboardingDetailsService> mount(
    WidgetTester tester, {
    String route = AppRoutes.profileDetails,
    String? country,
    void Function(RequestOptions, RequestInterceptorHandler)? search,
  }) async {
    final storage = StorageService();
    await storage.init();
    final api = ApiService(storage);
    api.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (req, handler) {
          if (req.path == '/api/schools' && search != null) {
            search(req, handler);
            return;
          }
          handler.resolve(
            Response(
              requestOptions: req,
              data: req.path == '/api/schools'
                  ? {
                      'schools': [_school],
                      'available': true,
                      'nextCursor': '',
                    }
                  : <String, dynamic>{},
            ),
          );
        },
      ),
    );
    final service = OnboardingDetailsService(api, storage);
    if (country != null) await service.setCountry(country);
    testAppRouter.go(route);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          apiServiceProvider.overrideWithValue(api),
          onboardingDetailsProvider.overrideWith((ref) => service),
        ],
        child: MaterialApp.router(routerConfig: testAppRouter),
      ),
    );
    await tester.pumpAndSettle();
    return service;
  }

  Future<void> profile(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const Key('onboarding-first-name')),
      'Aman',
    );
    await tester.enterText(
      find.byKey(const Key('onboarding-last-name')),
      'Smith',
    );
    await tester.ensureVisible(find.text('Non-binary'));
    await tester.tap(find.text('Non-binary'));
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  }

  Future<void> pickFromDropdown(
    WidgetTester tester, {
    required Key key,
    required String label,
    bool up = false,
  }) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
    if (up) {
      // The menu opens on the selected item; earlier entries need an
      // upward scroll, which scrollUntilVisible cannot do.
      for (var i = 0; i < 30 && find.text(label).evaluate().isEmpty; i++) {
        await tester.drag(find.byType(Scrollable).last, const Offset(0, 500));
        await tester.pumpAndSettle();
      }
    } else {
      await tester.scrollUntilVisible(
        find.text(label),
        300,
        scrollable: find.byType(Scrollable).last,
      );
    }
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  group('SchoolRegions catalog', () {
    test('US has 56 states/territories with exact CCD server values', () {
      expect(SchoolRegions.usStates.length, 56);
      final texas = SchoolRegions.usStates.singleWhere((s) => s.code == 'TX');
      expect(texas.label, 'Texas');
      expect(texas.server, 'TEXAS');
      final servers = SchoolRegions.usStates.map((s) => s.server);
      expect(servers.toSet().length, servers.length);
      expect(SchoolRegions.usStates.map((s) => s.code).toSet().length, 56);
      for (final s in SchoolRegions.usStates) {
        expect(s.server.length, lessThanOrEqualTo(128));
      }
    });

    test('CA provinces and GB regions match their directory conventions', () {
      expect(SchoolRegions.caProvinces.length, 13);
      expect(
        SchoolRegions.caProvinces.singleWhere((p) => p.code == 'ON').server,
        'ONTARIO',
      );
      expect(SchoolRegions.gbRegions.length, 223);
      expect(SchoolRegions.gbRegions, contains('City of London'));
      expect(
        SchoolRegions.gbRegions.toSet().length,
        SchoolRegions.gbRegions.length,
      );
      for (final r in SchoolRegions.gbRegions) {
        expect(r.length, lessThanOrEqualTo(128));
      }
    });

    test('dropdown entries exist only for catalogued countries', () {
      expect(SchoolRegions.hasRegions('US'), isTrue);
      expect(SchoolRegions.hasRegions('CA'), isTrue);
      expect(SchoolRegions.hasRegions('GB'), isTrue);
      expect(SchoolRegions.hasRegions('HK'), isFalse);
      expect(SchoolRegions.hasRegions('NZ'), isFalse);
      expect(SchoolRegions.hasRegions('SG'), isFalse);
      expect(
        SchoolRegions.forCountry('US').singleWhere((e) => e.label == 'Texas'),
        (value: 'TEXAS', label: 'Texas'),
      );
      expect(SchoolRegions.forCountry('GB').length, 223);
      expect(SchoolRegions.forCountry('HK'), isEmpty);
    });
  });

  test('school search sends region only when a filter is selected', () async {
    final storage = StorageService();
    await storage.init();
    final api = ApiService(storage);
    final seen = <RequestOptions>[];
    api.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (req, handler) {
          seen.add(req);
          handler.resolve(
            Response(requestOptions: req, data: <String, dynamic>{}),
          );
        },
      ),
    );
    final service = OnboardingDetailsService(api, storage);
    await service.search('Central');
    expect(seen.single.queryParameters.containsKey('region'), isFalse);
    await service.search('Central', region: 'TEXAS');
    expect(seen.last.queryParameters['region'], 'TEXAS');
    expect(seen.last.queryParameters['country'], 'US');
  });

  testWidgets('region filter narrows campus search and resets stale lists', (
    tester,
  ) async {
    final requests = <RequestOptions>[];
    await mount(
      tester,
      search: (req, handler) {
        requests.add(req);
        handler.resolve(
          Response(
            requestOptions: req,
            data: {
              'schools': [_school],
              'available': true,
              'nextCursor': '',
            },
          ),
        );
      },
    );
    await profile(tester);
    expect(find.byKey(const Key('school-region')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('school-search')), 'Central');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('Central High'), findsOneWidget);
    expect(requests.single.queryParameters.containsKey('region'), isFalse);
    await pickFromDropdown(
      tester,
      key: const Key('school-region'),
      label: 'Texas',
    );
    expect(requests.length, 2);
    expect(requests.last.queryParameters['region'], 'TEXAS');
    expect(find.text('Central High'), findsOneWidget);
    await pickFromDropdown(
      tester,
      key: const Key('school-region'),
      label: 'All regions',
      up: true,
    );
    expect(requests.length, 3);
    expect(requests.last.queryParameters.containsKey('region'), isFalse);
  });

  testWidgets('in-flight search is dropped when the region changes', (
    tester,
  ) async {
    final requests = <RequestOptions>[];
    final handlers = <RequestInterceptorHandler>[];
    await mount(
      tester,
      search: (req, handler) {
        requests.add(req);
        handlers.add(handler);
      },
    );
    await profile(tester);
    await tester.enterText(find.byKey(const Key('school-search')), 'Central');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(requests.length, 1);
    await tester.ensureVisible(find.byKey(const Key('school-region')));
    await tester.tap(find.byKey(const Key('school-region')));
    // Bounded pumps only: the held request keeps the spinner animating.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.scrollUntilVisible(
      find.text('Texas'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Texas').last);
    for (var i = 0; i < 20 && requests.length < 2; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    // Region change re-runs the query; the first response arrives late.
    expect(requests.length, 2);
    expect(requests.last.queryParameters['region'], 'TEXAS');
    handlers[0].resolve(
      Response(
        requestOptions: requests[0],
        data: {
          'schools': [
            {..._school, 'name': 'Stale School'},
          ],
          'available': true,
        },
      ),
    );
    await tester.pump();
    expect(find.text('Stale School'), findsNothing);
    handlers[1].resolve(
      Response(
        requestOptions: requests[1],
        data: {
          'schools': [
            {..._school, 'name': 'Texas School'},
          ],
          'available': true,
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Texas School'), findsOneWidget);
  });

  testWidgets('missing campus request stores the exact US region value', (
    tester,
  ) async {
    final service = await mount(tester);
    await profile(tester);
    await tester.ensureVisible(find.text('I can’t find my campus'));
    await tester.tap(find.text('I can’t find my campus'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('missing-region')), findsOneWidget);
    await tester.ensureVisible(find.text('Prepare email'));
    await tester.tap(find.text('Prepare email'));
    await tester.pumpAndSettle();
    // Same required-field message as the former free-text field.
    expect(find.text('Enter the state / territory.'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Campus name'),
      'Westfield High',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'City'),
      'Houston',
    );
    await pickFromDropdown(
      tester,
      key: const Key('missing-region'),
      label: 'Texas',
    );
    await pickFromDropdown(
      tester,
      key: const Key('graduation-year'),
      label: '2030',
    );
    await tester.ensureVisible(find.text('Prepare email'));
    await tester.tap(find.text('Prepare email'));
    await tester.pumpAndSettle();
    final draft = await service.read();
    expect(draft['missingRegion'], 'TEXAS');
    expect(draft['status'], 'requested');
  });

  testWidgets('countries without a catalog keep a free-text region', (
    tester,
  ) async {
    await mount(tester, country: 'HK');
    await profile(tester);
    expect(find.byKey(const Key('school-region')), findsNothing);
    await tester.ensureVisible(find.text('I can’t find my campus'));
    await tester.tap(find.text('I can’t find my campus'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('missing-region')), findsNothing);
    expect(find.widgetWithText(TextFormField, 'District'), findsOneWidget);
  });
}
