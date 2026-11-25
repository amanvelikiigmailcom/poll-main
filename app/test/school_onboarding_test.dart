import 'fakes/reviewer_storage.dart';
import 'package:flyprox_app/screens/registration/school_setup_screen.dart';
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
import 'package:flyprox_app/services/local_game_service.dart';
import 'package:flyprox_app/theme/app_theme.dart';
import 'fakes/eligible_player.dart';
import 'fakes/test_app.dart';

const school = {
  'id': 'US-CCD-1',
  'name': 'Central High',
  'city': 'Austin',
  'region': 'Texas',
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
    double scale = 1,
    bool schoolMode = false,
    bool reviewer = false,
    void Function(RequestOptions, RequestInterceptorHandler)? search,
  }) async {
    final storage = reviewer ? ReviewerStorageService() : StorageService();
    await storage.init();

    if (schoolMode) await storage.saveToken('fixture-session');
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
              data: req.path == '/api/quizzes/mode' && schoolMode
                  ? {
                      'mode': 'school',
                      'enrolled': true,
                      'joined': 5,
                      'threshold': 5,
                    }
                  : req.path == '/api/schools'
                  ? {
                      'schools': [school],
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
    testAppRouter.go(route);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          apiServiceProvider.overrideWithValue(api),
          onboardingDetailsProvider.overrideWith((ref) => service),
        ],
        child: MaterialApp.router(
          routerConfig: testAppRouter,
          theme: AppTheme.lightTheme,
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

  testWidgets(
    'five enrolled students bypass contact permission and open username setup',
    (tester) async {
      final service = await mount(tester, schoolMode: true);
      await profile(tester);
      await tester.enterText(find.byKey(const Key('school-search')), 'Central');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Central High'));
      await tester.tap(find.text('Central High'));
      await tester.pumpAndSettle();
      final picker = find.byKey(const Key('graduation-year'));
      await tester.ensureVisible(picker);
      await tester.tap(picker);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('2041'),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('2041').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('onboarding-username')), findsOneWidget);
      expect(find.text('Choose from contacts'), findsNothing);
      expect((await service.read())['stage'], 'username');
      expect(await LocalGameService.instance.getNames(), isEmpty);
    },
  );

  testWidgets(
    'selecting a campus collapses a long result list and exposes graduation year',
    (tester) async {
      await mount(
        tester,
        search: (request, handler) => handler.resolve(
          Response(
            requestOptions: request,
            data: {
              'schools': [
                for (var i = 0; i < 30; i++)
                  {...school, 'id': 'campus-$i', 'name': 'Campus $i'},
              ],
              'available': true,
            },
          ),
        ),
      );
      await profile(tester);
      await tester.enterText(find.byKey(const Key('school-search')), 'Campus');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Campus 0'));
      await tester.pumpAndSettle();
      expect(find.text('Campus 1'), findsNothing);
      expect(
        find.byKey(const Key('graduation-year')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('graduation-year')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2026').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Add your contacts'), findsOneWidget);
    },
  );

  test('missing campus field labels follow the selected country', () {
    expect(campusRegionLabel('US'), 'State / territory');
    expect(campusRegionLabel('CA'), 'Province / territory');
    expect(campusRegionLabel('GB'), 'County / region');
    expect(campusRegionLabel('NZ'), 'Region');
    expect(campusRegionLabel('SG'), 'District');
    expect(campusRegionLabel('HK'), 'District');
  });

  test(
    'graduation menu offers exactly 2026 through 2041 in ascending order',
    () {
      final values = GraduationYearPicker.choices(2026);
      expect(values, List.generate(16, (index) => 2026 + index));
    },
  );

  test(
    'names accept common scripts and punctuation but reject invalid lengths',
    () {
      for (final name in ['O’Connor', 'Jean-Luc', 'José', 'Әлия']) {
        expect(
          LocalGameService.validateProfileName(name, 'first name'),
          isNull,
        );
      }
      expect(
        LocalGameService.validateProfileName('   ', 'first name'),
        'Enter your first name',
      );
      expect(
        LocalGameService.validateProfileName('A\nB', 'last name'),
        contains('without line breaks'),
      );
      expect(
        LocalGameService.validateProfileName(
          List.filled(65, 'a').join(),
          'last name',
        ),
        contains('64'),
      );
    },
  );

  testWidgets('missing campus request identifies every required field', (
    tester,
  ) async {
    await mount(tester);
    await profile(tester);
    await tester.ensureVisible(find.text('I can’t find my campus'));
    await tester.tap(find.text('I can’t find my campus'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Prepare email'));
    await tester.tap(find.text('Prepare email'));
    await tester.pumpAndSettle();
    expect(find.text('Enter the campus name.'), findsOneWidget);
    expect(find.text('Enter the city.'), findsOneWidget);
    expect(find.text('Enter the state / territory.'), findsOneWidget);
    expect(find.text('Choose your graduation year.'), findsOneWidget);
  });
  testWidgets(
    'missing campus restores year and region before building pickers',
    (tester) async {
      final service = await mount(tester);
      await service.draft({
        'graduationYear': 2030,
        'missingRegion': 'TEXAS',
        'missingCity': 'Austin',
      });
      await profile(tester);
      await tester.ensureVisible(find.text('I can’t find my campus'));
      await tester.tap(find.text('I can’t find my campus'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DropdownButtonFormField<int>>(
              find.byKey(const Key('graduation-year')),
            )
            .initialValue,
        2030,
      );
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(
              find.byKey(const Key('missing-region')),
            )
            .initialValue,
        'TEXAS',
      );
    },
  );

  testWidgets('campus back preserves unsaved selection and graduation year', (
    tester,
  ) async {
    await mount(tester);
    await profile(tester);
    await tester.enterText(find.byKey(const Key('school-search')), 'Central');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Central High'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('graduation-year')));
    await tester.tap(find.byKey(const Key('graduation-year')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2026').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Back'));
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('About you'), findsOneWidget);
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Central High'), findsOneWidget);
    expect(
      tester
          .widget<DropdownButtonFormField<int>>(
            find.byKey(const Key('graduation-year')),
          )
          .initialValue,
      2026,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('school-search')))
          .controller!
          .text,
      'Central',
    );
  });

  testWidgets(
    'long selected campus never overlaps its location or Change at 320px x2',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const name = 'Central International Academy of Science and Technology';
      await mount(
        tester,
        scale: 2,
        search: (request, handler) {
          handler.resolve(
            Response(
              requestOptions: request,
              data: {
                'schools': [
                  {...school, 'name': name},
                ],
                'available': true,
              },
            ),
          );
        },
      );
      await profile(tester);
      await tester.enterText(find.byKey(const Key('school-search')), 'Central');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(name));
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
      final title = tester.getRect(find.text(name));
      final location = tester.getRect(find.text('Austin · Texas'));
      final change = tester.getRect(find.text('Change'));
      expect(title.bottom, lessThanOrEqualTo(location.top));
      expect(location.bottom, lessThanOrEqualTo(change.top));
      expect(title.width, lessThanOrEqualTo(272));
      await tester.ensureVisible(find.text('Change'));
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      expect(find.text('Austin · Texas'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'two forms precede contacts; school city/region and graduation year persist before continuing',
    (tester) async {
      final service = await mount(tester);
      expect(find.text('About you'), findsOneWidget);
      expect(find.text('Add your contacts'), findsNothing);
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('About you'), findsOneWidget);
      expect(find.text('Enter your first name'), findsOneWidget);
      expect(find.text('Enter your last name'), findsOneWidget);
      expect(find.text('Choose a gender to continue.'), findsOneWidget);
      await profile(tester);
      expect(find.text('Choose your campus'), findsOneWidget);
      expect((await service.read())['gender'], 'nonbinary');
      await tester.enterText(find.byKey(const Key('school-search')), 'Central');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('Austin · Texas · US'), findsOneWidget);
      await tester.ensureVisible(find.text('Central High'));
      await tester.tap(find.text('Central High'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Choose your graduation year.'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('graduation-year')));
      await tester.tap(find.byKey(const Key('graduation-year')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('2030'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('2030').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Add your contacts'), findsOneWidget);
      expect((await service.read())['school'], school);
      expect((await service.read())['graduationYear'], 2030);
      expect(await service.votingAllowed(), isTrue);
    },
  );
  testWidgets(
    'reviewer skip visibility updates live; skipping resumes contacts and direct voting remains blocked after setup',
    (tester) async {
      final service = await mount(tester, reviewer: true);
      await profile(tester);
      expect(find.byKey(const Key('skip-school')), findsOneWidget);
      ContentService.instance.debugSetOverrides({
        'school_skip_enabled': 'false',
      });
      await tester.pump();
      expect(find.byKey(const Key('skip-school')), findsNothing);
      ContentService.instance.debugSetOverrides({
        'school_skip_enabled': 'true',
      });
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('skip-school')));
      await tester.tap(find.byKey(const Key('skip-school')));
      await tester.pumpAndSettle();
      expect(find.text('Add your contacts'), findsOneWidget);
      await LocalGameService.instance.savePlayerAndFriends(
        playerName: 'Aman',
        friends: ['A', 'B', 'C', 'D'],
      );
      await LocalGameService.instance.setUsernameSetupPending(false);
      await service.finish();
      testAppRouter.go(AppRoutes.home);
      await tester.pumpAndSettle();
      expect(find.text('Choose your campus to play'), findsOneWidget);
      expect(find.text('YOUR NEXT ROUND'), findsNothing);
      testAppRouter.go(AppRoutes.vote);
      await tester.pumpAndSettle();
      expect(
        testAppRouter.routeInformationProvider.value.uri.path,
        AppRoutes.schoolWaiting,
      );
    },
  );
  testWidgets('regular users see no school skip and a campus-only hint', (
    tester,
  ) async {
    await mount(tester);
    await profile(tester);
    expect(find.byKey(const Key('skip-school')), findsNothing);
    expect(
      find.text('Voting opens after you choose a campus.'),
      findsOneWidget,
    );
    expect(find.textContaining('Skipping lets you finish'), findsNothing);
  });
  testWidgets(
    'search ignores stale responses and empty/error states stay usable',
    (tester) async {
      final handlers = <String, RequestInterceptorHandler>{};
      final requests = <String, RequestOptions>{};
      await mount(
        tester,
        search: (req, h) {
          handlers[req.queryParameters['q'] as String] = h;
          requests[req.queryParameters['q'] as String] = req;
        },
      );
      await profile(tester);
      await tester.enterText(find.byKey(const Key('school-search')), 'Old');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('school-search')), 'New');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      handlers['New']!.resolve(
        Response(
          requestOptions: requests['New']!,
          data: {
            'schools': [
              {...school, 'name': 'New School'},
            ],
            'available': true,
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('New School'), findsOneWidget);
      handlers['Old']!.resolve(
        Response(
          requestOptions: requests['Old']!,
          data: {
            'schools': [
              {...school, 'name': 'Old School'},
            ],
            'available': true,
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Old School'), findsNothing);
      expect(find.text('New School'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('school-search')), 'None');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      handlers['None']!.resolve(
        Response(
          requestOptions: requests['None']!,
          data: {'schools': [], 'available': false},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('not available yet'), findsOneWidget);
      await tester.ensureVisible(find.text('I can’t find my campus'));
      await tester.tap(find.text('I can’t find my campus'));
      await tester.pumpAndSettle();
      expect(find.text('Add your campus'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Campus name'), findsOneWidget);
      // US has a canonical region list: a dropdown replaces free text.
      expect(find.byKey(const Key('missing-region')), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'State / territory'),
        findsNothing,
      );
    },
  );
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'profile and school forms fit 320px with keyboard and text scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        await mount(tester, scale: scale, reviewer: true);
        await profile(tester);
        await tester.ensureVisible(find.byKey(const Key('skip-school')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('skip-school')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
